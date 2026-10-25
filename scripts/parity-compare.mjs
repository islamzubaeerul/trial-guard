// Compares two {fixture: ParseResult} JSON files. Writes a markdown report; exits 1 on any difference.
import { readFileSync, writeFileSync } from 'node:fs';

const [tsPath, swiftPath, reportPath = 'parity-report.md'] = process.argv.slice(2);
const ts = JSON.parse(readFileSync(tsPath, 'utf8'));
const sw = JSON.parse(readFileSync(swiftPath, 'utf8'));
const FIELDS = ['isTrial', 'serviceName', 'serviceKey', 'trialDays', 'trialEnd', 'nextChargeDate', 'price', 'currency', 'cycle', 'cancelURL'];
const CONF = ['service', 'trialEnd', 'price', 'cancelURL', 'overall'];

const diffs = [];
const names = [...new Set([...Object.keys(ts), ...Object.keys(sw)])].sort();
for (const n of names) {
  const a = ts[n];
  const b = sw[n];
  if (!a || !b) { diffs.push([n, 'missing', a ? 'present' : 'absent', b ? 'present' : 'absent']); continue; }
  for (const f of FIELDS) if ((a[f] ?? null) !== (b[f] ?? null)) diffs.push([n, f, a[f] ?? null, b[f] ?? null]);
  for (const c of CONF) {
    const x = a.confidence?.[c] ?? 0;
    const y = b.confidence?.[c] ?? 0;
    if (Math.abs(x - y) > 0.005) diffs.push([n, `confidence.${c}`, x, y]);
  }
}

let md = `# Parser parity report\n\n${names.length} fixtures · ${diffs.length} differences\n\n`;
if (diffs.length) {
  md += '| Fixture | Field | TypeScript | Swift |\n| --- | --- | --- | --- |\n';
  for (const [n, f, a, b] of diffs) md += `| ${n} | ${f} | ${JSON.stringify(a)} | ${JSON.stringify(b)} |\n`;
} else md += 'Both parsers agree on every field of every fixture.\n';
writeFileSync(reportPath, md);
console.log(md);
process.exit(diffs.length ? 1 : 0);
