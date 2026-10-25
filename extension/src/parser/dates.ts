// Calendar-date helpers. A trial ends on a *day*, so everything here works on plain
// year/month/day values computed in UTC to avoid the host's local time zone leaking in.

export interface LocalDate {
  y: number;
  m: number; // 1-12
  d: number; // 1-31
}

export function toISO(x: LocalDate): string {
  return `${x.y}-${String(x.m).padStart(2, '0')}-${String(x.d).padStart(2, '0')}`;
}

export function todayIn(now: Date, timeZone: string): LocalDate {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value);
  return { y: get('year'), m: get('month'), d: get('day') };
}

function daysInMonth(y: number, m: number): number {
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

export function isValid(x: LocalDate): boolean {
  return x.m >= 1 && x.m <= 12 && x.d >= 1 && x.d <= daysInMonth(x.y, x.m);
}

function toEpochDays(x: LocalDate): number {
  return Date.UTC(x.y, x.m - 1, x.d) / 86_400_000;
}

export function addDays(x: LocalDate, n: number): LocalDate {
  const t = new Date((toEpochDays(x) + n) * 86_400_000);
  return { y: t.getUTCFullYear(), m: t.getUTCMonth() + 1, d: t.getUTCDate() };
}

/** Calendar month addition; the day is clamped (Oct 31 + 1 month = Nov 30). */
export function addMonths(x: LocalDate, n: number): LocalDate {
  const total = x.y * 12 + (x.m - 1) + n;
  const y = Math.floor(total / 12);
  const m = (total % 12) + 1;
  return { y, m, d: Math.min(x.d, daysInMonth(y, m)) };
}

export function daysBetween(a: LocalDate, b: LocalDate): number {
  return Math.round(toEpochDays(b) - toEpochDays(a));
}

export function compare(a: LocalDate, b: LocalDate): number {
  return toEpochDays(a) - toEpochDays(b);
}

const MONTHS: Record<string, number> = {
  january: 1, jan: 1, janvier: 1, janv: 1,
  february: 2, feb: 2, février: 2, fevrier: 2, févr: 2, fevr: 2,
  march: 3, mar: 3, mars: 3,
  april: 4, apr: 4, avril: 4, avr: 4,
  may: 5, mai: 5,
  june: 6, jun: 6, juin: 6,
  july: 7, jul: 7, juillet: 7, juil: 7,
  august: 8, aug: 8, août: 8, aout: 8,
  september: 9, sept: 9, sep: 9, septembre: 9,
  october: 10, oct: 10, octobre: 10,
  november: 11, nov: 11, novembre: 11,
  december: 12, dec: 12, décembre: 12, decembre: 12, déc: 12,
};

export const MONTH_ALT = Object.keys(MONTHS)
  .sort((a, b) => b.length - a.length)
  .join('|');

export interface DateMatch {
  index: number;
  end: number;
  date: LocalDate;
  raw: string;
}

const L = '(?<![a-zà-ÿ])';
const R = '(?![a-zà-ÿ])';
const RE_MDY = new RegExp(`${L}(${MONTH_ALT})\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?(?!\\d)`, 'g');
const RE_DMY = new RegExp(`(?<!\\d)(\\d{1,2})(?:er|st|nd|rd|th)?\\s+(${MONTH_ALT})${R}\\.?(?:,?\\s+(\\d{4}))?(?!\\d)`, 'g');
const RE_ISO = /(?<!\d)(\d{4})-(\d{2})-(\d{2})(?!\d)/g;
const RE_SLASH = /(?<!\d)(\d{1,2})\/(\d{1,2})\/(\d{4})(?!\d)/g;

/** Resolve a day/month without a year to its next occurrence on or after today. */
function withYear(m: number, d: number, y: string | undefined, today: LocalDate): LocalDate {
  if (y) return { y: Number(y), m, d };
  const candidate = { y: today.y, m, d };
  return compare(candidate, today) >= 0 ? candidate : { y: today.y + 1, m, d };
}

/** Find every date in a lowercased, normalized text. Overlaps keep the longer match. */
export function findDates(lower: string, locale: string, today: LocalDate): DateMatch[] {
  const found: DateMatch[] = [];
  const push = (index: number, raw: string, date: LocalDate) => {
    if (isValid(date)) found.push({ index, end: index + raw.length, date, raw });
  };
  for (const m of lower.matchAll(RE_MDY)) {
    push(m.index!, m[0], withYear(MONTHS[m[1]!]!, Number(m[2]), m[3], today));
  }
  for (const m of lower.matchAll(RE_DMY)) {
    push(m.index!, m[0], withYear(MONTHS[m[2]!]!, Number(m[1]), m[3], today));
  }
  for (const m of lower.matchAll(RE_ISO)) {
    push(m.index!, m[0], { y: Number(m[1]), m: Number(m[2]), d: Number(m[3]) });
  }
  for (const m of lower.matchAll(RE_SLASH)) {
    const a = Number(m[1]);
    const b = Number(m[2]);
    let month: number;
    let day: number;
    if (a > 12) [day, month] = [a, b];
    else if (b > 12) [month, day] = [a, b];
    else if (locale.toLowerCase() === 'en-us') [month, day] = [a, b];
    else [day, month] = [a, b];
    push(m.index!, m[0], { y: Number(m[3]), m: month, d: day });
  }
  found.sort((x, y) => x.index - y.index || y.end - x.end);
  const out: DateMatch[] = [];
  for (const f of found) {
    const last = out[out.length - 1];
    if (last && f.index < last.end) continue;
    out.push(f);
  }
  return out;
}
