import servicesFile from '../../../services-db/services.json';
import { addDays, addMonths, compare, daysBetween, findDates, todayIn, toISO, type LocalDate } from './dates';
import { choosePrice, findMoney } from './money';
import { normalize } from './normalize';
import {
  AFTER_CUE, CANCEL_ANCHOR, CHARGE_CUE, END_CUE, LENGTH_PATTERNS, TRIAL_PHRASE, numberOf, unitOf, type Unit,
} from './patterns';
import { identifyService } from './service';
import type { ParseInput, ParseResult, ServiceDefinition } from './types';

export type { ParseInput, ParseResult, ServiceDefinition } from './types';

export const SERVICES: ServiceDefinition[] = (servicesFile as { services: ServiceDefinition[] }).services;

const round2 = (n: number) => Math.round(n * 100) / 100;

interface Length {
  n: number;
  unit: Unit;
  index: number;
  raw: string;
}

function findLength(lower: string): Length | undefined {
  let best: Length | undefined;
  for (const p of LENGTH_PATTERNS) {
    const m = p.re.exec(lower);
    if (!m) continue;
    const n = p.fixedNumber ?? numberOf(m[1]!);
    const unit = unitOf(p.fixedNumber ? m[1]! : m[2]!);
    if (!Number.isFinite(n) || n <= 0 || n > 366) continue;
    if (!best || m.index < best.index) best = { n, unit, index: m.index, raw: m[0] };
  }
  return best;
}

function addLength(today: LocalDate, len: Length): LocalDate {
  switch (len.unit) {
    case 'day': return addDays(today, len.n);
    case 'week': return addDays(today, 7 * len.n);
    case 'month': return addMonths(today, len.n);
    case 'year': return addMonths(today, 12 * len.n);
  }
}

export function parse(input: ParseInput, services: ServiceDefinition[] = SERVICES): ParseResult {
  const text = normalize(input.text);
  const lower = text.toLowerCase();
  const title = input.title ? normalize(input.title) : undefined;
  const today = todayIn(input.now, input.timeZone);
  const evidence: Record<string, string> = {};

  // Service
  const service = identifyService(services, text, title, input.url, input.senderDomain);
  if (service) evidence.service = service.evidence;

  // Trial signal and length
  const length = findLength(lower);
  const phrase = TRIAL_PHRASE.exec(lower);
  const isTrial = !!length || !!phrase;
  const trialPos = length?.index ?? phrase?.index ?? 0;
  if (length) evidence.trialLength = text.slice(length.index, length.index + length.raw.length);

  // Dates
  let trialEnd: LocalDate | undefined;
  let trialEndConf = 0;
  let nextCharge: LocalDate | undefined;
  for (const d of findDates(lower, input.locale, today)) {
    const before = lower.slice(Math.max(0, d.index - 50), d.index);
    const after = lower.slice(d.end, d.end + 40);
    const charge = CHARGE_CUE.test(before) || AFTER_CUE.test(after);
    const end = END_CUE.test(before);
    if (isTrial && !trialEnd && (charge || end)) {
      trialEnd = d.date;
      trialEndConf = 0.95;
      evidence.trialEnd = text.slice(d.index, d.end);
    }
    if (!isTrial && !nextCharge && charge) {
      nextCharge = d.date;
      evidence.nextChargeDate = text.slice(d.index, d.end);
    }
  }
  if (isTrial && !trialEnd && length) {
    trialEnd = addLength(today, length);
    trialEndConf = 0.7;
  }
  let trialDays: number | undefined;
  if (isTrial && length) trialDays = daysBetween(today, addLength(today, length));
  else if (isTrial && trialEnd && compare(trialEnd, today) > 0) trialDays = daysBetween(today, trialEnd);

  // Price
  const price = choosePrice(lower, findMoney(lower, input.defaultCurrency), trialPos);
  if (price) evidence.price = text.slice(price.money.index, price.money.cycleEnd);

  // Cancel URL
  let cancelURL: string | undefined;
  let cancelConf = 0;
  const anchor = (input.anchors ?? []).find((a) => /^https:\/\//i.test(a.href) && CANCEL_ANCHOR.test(a.text));
  if (anchor) {
    cancelURL = anchor.href;
    cancelConf = 0.95;
    evidence.cancelURL = anchor.text;
  } else if (service?.def?.cancelURL) {
    cancelURL = service.def.cancelURL;
    cancelConf = 0.7;
  }

  // Score
  const serviceConf = service?.confidence ?? 0;
  const priceConf = price?.confidence ?? 0;
  let overall = 0.3 * serviceConf + 0.35 * trialEndConf + 0.2 * priceConf + 0.15 * cancelConf;
  if (!isTrial) overall /= 2;

  const result: ParseResult = {
    isTrial,
    currency: price?.money.currency ?? input.defaultCurrency,
    cycle: price?.money.cycle ?? 'unknown',
    confidence: {
      service: round2(serviceConf),
      trialEnd: round2(trialEndConf),
      price: round2(priceConf),
      cancelURL: round2(cancelConf),
      overall: round2(overall),
    },
    evidence,
  };
  if (service) result.serviceName = service.name;
  if (service?.key) result.serviceKey = service.key;
  if (trialDays !== undefined) result.trialDays = trialDays;
  if (isTrial && trialEnd) result.trialEnd = toISO(trialEnd);
  if (nextCharge) result.nextChargeDate = toISO(nextCharge);
  if (price) result.price = price.money.amount;
  if (cancelURL) result.cancelURL = cancelURL;
  return result;
}
