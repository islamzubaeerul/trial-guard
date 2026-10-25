import { describe, expect, it } from 'vitest';
import { addMonths, findDates, todayIn, toISO } from '../src/parser/dates';
import { canonicalAmount, findMoney } from '../src/parser/money';
import { normalize } from '../src/parser/normalize';
import { parse } from '../src/parser';

const today = { y: 2026, m: 10, d: 24 };

describe('dates', () => {
  it('clamps month addition to the last day', () => {
    expect(toISO(addMonths({ y: 2026, m: 1, d: 31 }, 1))).toBe('2026-02-28');
    expect(toISO(addMonths({ y: 2026, m: 10, d: 31 }, 1))).toBe('2026-11-30');
    expect(toISO(addMonths({ y: 2026, m: 12, d: 15 }, 1))).toBe('2027-01-15');
  });
  it('computes today in the given time zone, not the host zone', () => {
    // 2026-10-25 02:30 UTC is still Oct 24 in Toronto and already Oct 25 in Dhaka.
    const now = new Date('2026-10-25T02:30:00Z');
    expect(toISO(todayIn(now, 'America/Toronto'))).toBe('2026-10-24');
    expect(toISO(todayIn(now, 'Asia/Dhaka'))).toBe('2026-10-25');
  });
  it('rolls a year-less date into next year when it has passed', () => {
    expect(toISO(findDates('ends jan 5', 'en-CA', today)[0]!.date)).toBe('2027-01-05');
    expect(toISO(findDates('ends nov 5', 'en-CA', today)[0]!.date)).toBe('2026-11-05');
    expect(toISO(findDates('ends oct 24', 'en-CA', today)[0]!.date)).toBe('2026-10-24');
  });
  it('reads ambiguous slash dates by locale', () => {
    expect(toISO(findDates('03/11/2026', 'en-US', today)[0]!.date)).toBe('2026-03-11');
    expect(toISO(findDates('03/11/2026', 'en-CA', today)[0]!.date)).toBe('2026-11-03');
    expect(toISO(findDates('11/23/2026', 'en-CA', today)[0]!.date)).toBe('2026-11-23');
  });
  it('rejects impossible dates', () => {
    expect(findDates('feb 30, 2026', 'en-CA', today)).toEqual([]);
  });
  it('reads French dates including 1er', () => {
    expect(toISO(findDates('le 1er novembre 2026', 'fr-CA', today)[0]!.date)).toBe('2026-11-01');
  });
});

describe('money', () => {
  it('canonicalizes number formats', () => {
    expect(canonicalAmount('1,234.56')).toBe('1234.56');
    expect(canonicalAmount('1.234,56')).toBe('1234.56');
    expect(canonicalAmount('14,99')).toBe('14.99');
    expect(canonicalAmount('22')).toBe('22');
    expect(canonicalAmount('139.00')).toBe('139.00');
    expect(canonicalAmount('1 234,56')).toBe('1234.56');
  });
  it('maps currencies, with bare $ going to the default', () => {
    const m = findMoney('ca$5/mo us$6/mo $7/mo €8/mo 9,50 $/mois', 'CAD');
    expect(m.map((x) => x.currency)).toEqual(['CAD', 'USD', 'CAD', 'EUR', 'CAD']);
    expect(findMoney('$7/mo', 'USD')[0]!.currency).toBe('USD');
  });
});

describe('normalize', () => {
  it('decodes entities and removes zero-width characters', () => {
    expect(normalize('Then&nbsp;CA&#36;16.99​/month')).toBe('Then CA$16.99/month');
    expect(normalize('You’ll be charged')).toBe("You'll be charged");
  });
});

describe('safety rules', () => {
  const base = { now: new Date('2026-10-24T14:00:00-04:00'), timeZone: 'America/Toronto', locale: 'en-CA', defaultCurrency: 'CAD' };
  it('ignores non-https cancel anchors', () => {
    const r = parse({ ...base, text: '7-day free trial, then $5/month', anchors: [{ text: 'Cancel', href: 'javascript:alert(1)' }] });
    expect(r.cancelURL).toBeUndefined();
  });
  it('treats a bare "trial" as no trial signal', () => {
    expect(parse({ ...base, text: 'The trial ends on Dec 5, 2026.' }).isTrial).toBe(false);
  });
  it('handles an empty input', () => {
    const r = parse({ ...base, text: '' });
    expect(r.isTrial).toBe(false);
    expect(r.confidence.overall).toBe(0);
  });
  it('parses a 20 KB page quickly', () => {
    const text = 'Lorem ipsum dolor sit amet. '.repeat(700) + 'Start your 14-day free trial. Then $8/month.';
    const t0 = performance.now();
    const r = parse({ ...base, text });
    expect(performance.now() - t0).toBeLessThan(50);
    expect(r.trialDays).toBe(14);
  });
});
