// Trial-length and cue patterns. The Swift parser keeps the SAME list in the SAME order
// (TrialGuardCore/Parser/Patterns.swift). Change both together, with a fixture.

const NUM_WORDS =
  'one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|fourteen|fifteen|thirty|sixty|ninety|une|un|deux|trois|quatre|cinq|six|sept|huit|neuf|dix|onze|douze|quatorze|quinze|trente|soixante';
const NUM = `(\\d{1,3}|${NUM_WORDS})`;
const UNIT_EN = '(day|week|month|year)s?';
const UNIT_FR = '(jours?|semaines?|mois|ans?)';

/** Each pattern captures (number, unit) or, when `fixed` is set, only (unit). */
export interface LengthPattern {
  re: RegExp;
  fixedNumber?: number;
}

export const LENGTH_PATTERNS: LengthPattern[] = [
  { re: new RegExp(`(?<![a-z\\d])${NUM}[\\s-]+${UNIT_EN}[\\s-]+(?:free[\\s-]+)?trial`) },
  { re: new RegExp(`(?<![a-z])free\\s+(?:trial\\s+)?for\\s+(?:the\\s+)?(?:first\\s+)?${NUM}\\s+${UNIT_EN}(?![a-z])`) },
  { re: new RegExp(`(?<![a-z])(?:free\\s+)?trial\\s+(?:of|for)\\s+${NUM}\\s+${UNIT_EN}(?![a-z])`) },
  { re: new RegExp(`(?<![a-z\\d])${NUM}\\s+${UNIT_EN}\\s+free(?![a-z])`) },
  { re: /(?<![a-z])(?:first|1st)\s+(week|month|year)\s+(?:is\s+)?free(?![a-z])/, fixedNumber: 1 },
  { re: new RegExp(`essai\\s+gratuit\\s+(?:de|d'une\\s+durée\\s+de)\\s+${NUM}\\s+${UNIT_FR}(?![a-zà-ÿ])`) },
  { re: new RegExp(`(?<![a-z\\d])${NUM}\\s+${UNIT_FR}\\s+(?:d'essai\\s+gratuit|d'essai|gratuits?)(?![a-zà-ÿ])`) },
  { re: new RegExp(`période\\s+d'essai\\s+(?:gratuite\\s+)?de\\s+${NUM}\\s+${UNIT_FR}(?![a-zà-ÿ])`) },
];

export const TRIAL_PHRASE =
  /free trial(?![-a-z])|trial period|try (?:it )?free|first (?:month|week|year) (?:is )?free|essai gratuit|période d'essai|\d+ (?:days?|weeks?|months?) free/;

const NUMBER_OF: Record<string, number> = {
  one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
  eleven: 11, twelve: 12, fourteen: 14, fifteen: 15, thirty: 30, sixty: 60, ninety: 90,
  quatorze: 14, quinze: 15, trente: 30, soixante: 60, un: 1, une: 1, deux: 2, trois: 3, quatre: 4, cinq: 5, sept: 7,
  huit: 8, neuf: 9, dix: 10, onze: 11, douze: 12,
};

export function numberOf(token: string): number {
  return /^\d+$/.test(token) ? Number(token) : (NUMBER_OF[token] ?? NaN);
}

export type Unit = 'day' | 'week' | 'month' | 'year';

export function unitOf(token: string): Unit {
  if (token.startsWith('day') || token.startsWith('jour')) return 'day';
  if (token.startsWith('week') || token.startsWith('semaine')) return 'week';
  if (token.startsWith('month') || token === 'mois') return 'month';
  return 'year';
}

/** Cues ending just before a date that mark when a trial ends. */
export const END_CUE =
  /(trial(?: period)? (?:ends|expires|will end|is over|runs until)|free until|no charge until|runs until|jusqu'au|cancel (?:any ?time )?before|se termine(?: le)?|prendra fin(?: le)?)(?:(?!\.\s)[^!?\n]){0,45}$/;
/** Cues ending just before a date that mark a charge (trial end on a trial, next charge otherwise). */
export const CHARGE_CUE =
  /(be charged|be billed|charge you(?: on)?|charged|billed|first (?:payment|charge|bill)|billing date|renews|renew|renewal date|billing starts|facturée?|prélevée?)(?:(?!\.\s)[^!?\n]){0,45}$/;
/** Text right after a date: "Nov 24, 2026, you'll be charged". */
export const AFTER_CUE = /^[\s,.:;]*(?:you'll|you will) be (?:charged|billed)/;

export const CANCEL_ANCHOR =
  /cancel|manage (?:your )?(?:subscription|plan|membership)|billing|account settings|gérer (?:mon|votre) abonnement/i;
