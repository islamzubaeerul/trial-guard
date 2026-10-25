import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { ParseInput, ParseResult } from '../src/parser';

export const FIXTURE_DIR = join(dirname(fileURLToPath(import.meta.url)), '../../parser-fixtures');

export interface Fixture {
  name: string;
  input: ParseInput;
  expected: Record<string, unknown>;
}

/** Reads `#! key=value` header lines (several per line, space-separated; anchor/url/title/sender take the rest of the line). */
export function loadFixtures(dir = FIXTURE_DIR): Fixture[] {
  return readdirSync(dir)
    .filter((f) => f.endsWith('.txt'))
    .sort()
    .map((file) => {
      const name = file.replace(/\.txt$/, '');
      const lines = readFileSync(join(dir, file), 'utf8').split('\n');
      const meta: Record<string, string> = {};
      const anchors: { text: string; href: string }[] = [];
      let i = 0;
      for (; i < lines.length && lines[i]!.startsWith('#! '); i++) {
        const body = lines[i]!.slice(3);
        const whole = /^(url|title|sender|anchor)=(.*)$/.exec(body);
        if (whole) {
          if (whole[1] === 'anchor') {
            const [text, href] = whole[2]!.split('|');
            anchors.push({ text: text!, href: href! });
          } else meta[whole[1]!] = whole[2]!;
          continue;
        }
        for (const kv of body.split(' ')) {
          const eq = kv.indexOf('=');
          if (eq > 0) meta[kv.slice(0, eq)] = kv.slice(eq + 1);
        }
      }
      const input: ParseInput = {
        text: lines.slice(i).join('\n'),
        now: new Date(meta.now!),
        timeZone: meta.tz ?? 'America/Toronto',
        locale: meta.locale ?? 'en-CA',
        defaultCurrency: meta.currency ?? 'CAD',
        ...(meta.url ? { url: meta.url } : {}),
        ...(meta.title ? { title: meta.title } : {}),
        ...(meta.sender ? { senderDomain: meta.sender } : {}),
        ...(anchors.length ? { anchors } : {}),
      };
      const expected = JSON.parse(readFileSync(join(dir, `${name}.expected.json`), 'utf8'));
      return { name, input, expected };
    });
}

export const FIELDS = [
  'isTrial', 'serviceName', 'serviceKey', 'trialDays', 'trialEnd', 'nextChargeDate',
  'price', 'currency', 'cycle', 'cancelURL',
] as const;

export interface FieldCheck {
  field: string;
  expected: unknown;
  actual: unknown;
  ok: boolean;
}

export function check(result: ParseResult, expected: Record<string, unknown>): FieldCheck[] {
  const out: FieldCheck[] = [];
  const r = result as unknown as Record<string, unknown>;
  for (const f of FIELDS) {
    if (!(f in expected)) continue;
    const exp = expected[f];
    const act = r[f];
    out.push({ field: f, expected: exp, actual: act ?? null, ok: exp === null ? act === undefined : act === exp });
  }
  if (typeof expected.overallBelow === 'number') {
    const v = result.confidence.overall;
    out.push({ field: 'overallBelow', expected: `< ${expected.overallBelow}`, actual: v, ok: v < expected.overallBelow });
  }
  if (typeof expected.overallAtLeast === 'number') {
    const v = result.confidence.overall;
    out.push({ field: 'overallAtLeast', expected: `>= ${expected.overallAtLeast}`, actual: v, ok: v >= expected.overallAtLeast });
  }
  return out;
}
