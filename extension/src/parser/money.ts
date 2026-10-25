import type { Cycle } from './types';

export interface MoneyMatch {
  index: number;
  end: number;
  amount: string; // canonical decimal string
  currency: string;
  cycle: Cycle;
  cycleEnd: number; // index after the cycle words (or end when no cycle)
  raw: string;
}

const NUM = '(\\d{1,3}(?:[.,\\s]\\d{3})+(?:[.,]\\d{1,2})?|\\d+(?:[.,]\\d{1,2})?)';
// Prefix currency: symbol or code before the amount, optional code after ("$39.99 CAD").
const RE_PRE = new RegExp(
  `(?<![a-z])(ca\\$|c\\$|us\\$|a\\$|cad|usd|eur|gbp|€|£|¥|\\$)\\s?${NUM}(?:\\s?(cad|usd|eur)(?![a-z]))?`,
  'g',
);
// Suffix currency: "11,99 $", "22 $ CA", "14,99 €".
const RE_POST = new RegExp(`(?<![\\d.,$])${NUM}\\s?(\\$\\s?ca(?![a-z])|\\$|€|cad(?![a-z])|usd(?![a-z])|eur(?![a-z]))`, 'g');

const RE_CYCLE =
  /^[ ,]{0,2}(?:\/|per|a|an|every|each|par|billed)?\s*(?:billed\s+)?(monthly|month|mth|mo|annually|annual|annum|yearly|year|yr|quarterly|quarter|weekly|week|wk|mois|année|an|semaine)(?![a-zà-ÿ])/;

const CYCLE_OF: Record<string, Cycle> = {
  monthly: 'monthly', month: 'monthly', mth: 'monthly', mo: 'monthly', mois: 'monthly',
  annually: 'yearly', annual: 'yearly', annum: 'yearly', yearly: 'yearly', year: 'yearly',
  yr: 'yearly', année: 'yearly', an: 'yearly',
  quarterly: 'quarterly', quarter: 'quarterly',
  weekly: 'weekly', week: 'weekly', wk: 'weekly', semaine: 'weekly',
};

export function canonicalAmount(raw: string): string {
  const s = raw.replace(/\s/g, ' ').trim();
  const dec = /[.,](\d{1,2})$/.exec(s);
  if (dec) {
    const intPart = s.slice(0, dec.index).replace(/[.,\s]/g, '');
    return `${intPart}.${dec[1]}`;
  }
  return s.replace(/[.,\s]/g, '');
}

export function currencyOf(token: string, defaultCurrency: string): string {
  const t = token.replace(/\s/g, '').toLowerCase();
  if (t === 'ca$' || t === 'c$' || t === 'cad' || t === '$ca') return 'CAD';
  if (t === 'us$' || t === 'usd') return 'USD';
  if (t === 'a$') return 'AUD';
  if (t === '€' || t === 'eur') return 'EUR';
  if (t === '£' || t === 'gbp') return 'GBP';
  if (t === '¥') return 'JPY';
  return defaultCurrency;
}

function cycleAt(lower: string, end: number): { cycle: Cycle; cycleEnd: number } {
  const m = RE_CYCLE.exec(lower.slice(end, end + 24));
  if (!m) return { cycle: 'unknown', cycleEnd: end };
  return { cycle: CYCLE_OF[m[1]!] ?? 'unknown', cycleEnd: end + m[0].length };
}

/** All money amounts in a lowercased normalized text, with their cycle if one follows. */
export function findMoney(lower: string, defaultCurrency: string): MoneyMatch[] {
  const out: MoneyMatch[] = [];
  for (const m of lower.matchAll(RE_PRE)) {
    const index = m.index!;
    const end = index + m[0].length;
    const currency = m[3] ? currencyOf(m[3], defaultCurrency) : currencyOf(m[1]!, defaultCurrency);
    out.push({ index, end, amount: canonicalAmount(m[2]!), currency, raw: m[0], ...cycleAt(lower, end) });
  }
  for (const m of lower.matchAll(RE_POST)) {
    const index = m.index!;
    const end = index + m[0].length;
    if (out.some((o) => index < o.end && end > o.index)) continue;
    out.push({
      index,
      end,
      amount: canonicalAmount(m[1]!),
      currency: currencyOf(m[2]!, defaultCurrency),
      raw: m[0],
      ...cycleAt(lower, end),
    });
  }
  return out.sort((a, b) => a.index - b.index);
}

// Checked on the 15 characters before an amount. "today" only counts this close
// ("Total today: $0"); a "today." two sentences back must not reject the real price.
const RE_REJECT_BEFORE = /(?<![a-z])(save|was|off|discount|économisez|today)(?![a-z])[^.\n]*$/;
const RE_CUE_BEFORE = /(?<![a-z])(then|after|renews? at|renew|billed|fee of|puis|facturée?|pay)(?![a-z])/;

export interface PriceChoice {
  money: MoneyMatch;
  confidence: number;
}

export function choosePrice(lower: string, money: MoneyMatch[], anchorPos: number): PriceChoice | undefined {
  const usable = money.filter((m) => {
    if (Number(m.amount) === 0) return false;
    const before = lower.slice(Math.max(0, m.index - 20), m.index);
    if (RE_REJECT_BEFORE.test(before.slice(-15)) || /due today/.test(before)) return false;
    if (/^\s{0,2}off(?![a-z])/.test(lower.slice(m.end, m.end + 6))) return false;
    return true;
  });
  const cycled = usable.filter((m) => m.cycle !== 'unknown');
  const cued = cycled.filter((m) => RE_CUE_BEFORE.test(lower.slice(Math.max(0, m.index - 30), m.index)));
  const nearest = (list: MoneyMatch[]) =>
    list.reduce((best, m) => (Math.abs(m.index - anchorPos) < Math.abs(best.index - anchorPos) ? m : best));
  if (cued.length) return { money: nearest(cued), confidence: 0.95 };
  if (cycled.length) return { money: nearest(cycled), confidence: 0.7 };
  const close = usable.filter((m) => Math.abs(m.index - anchorPos) <= 120);
  if (close.length) return { money: nearest(close), confidence: 0.4 };
  return undefined;
}
