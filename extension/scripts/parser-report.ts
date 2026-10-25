// Per-field accuracy over parser-fixtures/. `--json` prints machine-readable results for the parity script.
import { parse } from '../src/parser';
import { check, loadFixtures } from '../tests/fixtures';

const TARGETS: Record<string, number> = { serviceKey: 0.95, trialEnd: 0.9, price: 0.85, negatives: 1 };
const fixtures = loadFixtures();
const rows = fixtures.map((fx) => ({ name: fx.name, result: parse(fx.input), checks: check(parse(fx.input), fx.expected) }));

if (process.argv.includes('--json')) {
  const out: Record<string, unknown> = {};
  for (const r of rows) {
    const { evidence, ...rest } = r.result;
    out[r.name] = rest;
  }
  console.log(JSON.stringify(out, null, 2));
  process.exit(0);
}

const tally: Record<string, { ok: number; n: number }> = {};
for (const r of rows) for (const c of r.checks) {
  const t = (tally[c.field] ??= { ok: 0, n: 0 });
  t.n++;
  if (c.ok) t.ok++;
}
const neg = rows.filter((r) => r.name.includes('negative'));
tally.negatives = { ok: neg.filter((r) => r.checks.every((c) => c.ok)).length, n: neg.length };

console.log(`Parser report: ${fixtures.length} fixtures\n`);
console.log('| Field | Correct | Accuracy | Target |');
console.log('| --- | --- | --- | --- |');
let failed = false;
for (const [f, t] of Object.entries(tally)) {
  const acc = t.ok / t.n;
  const target = TARGETS[f];
  if (target !== undefined && acc < target) failed = true;
  console.log(`| ${f} | ${t.ok}/${t.n} | ${(acc * 100).toFixed(1)}% | ${target !== undefined ? `${target * 100}%` : '—'} |`);
}
const bad = rows.filter((r) => r.checks.some((c) => !c.ok));
if (bad.length) {
  console.log('\nFailing fixtures:');
  for (const r of bad) for (const c of r.checks.filter((x) => !x.ok))
    console.log(`- ${r.name}: ${c.field} expected ${JSON.stringify(c.expected)} got ${JSON.stringify(c.actual)}`);
}
process.exit(failed ? 1 : 0);
