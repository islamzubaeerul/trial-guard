// Privacy guard (TG-9): the extension and parser must never make network calls or run dynamic code.
// Fails CI if a forbidden API appears in extension/src.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const FORBIDDEN = [
  /\bfetch\s*\(/, /\bXMLHttpRequest\b/, /\bWebSocket\b/, /\bEventSource\b/, /navigator\.sendBeacon/,
  /\beval\s*\(/, /\bnew\s+Function\s*\(/, /importScripts\s*\(/, /\bimport\s*\(\s*['"`]https?:/,
];
const walk = (d) => readdirSync(d).flatMap((f) => (statSync(join(d, f)).isDirectory() ? walk(join(d, f)) : [join(d, f)]));
const hits = [];
for (const file of walk(new URL('../src', import.meta.url).pathname)) {
  if (!/\.(ts|js|mjs|tsx)$/.test(file)) continue;
  readFileSync(file, 'utf8').split('\n').forEach((line, i) => {
    if (FORBIDDEN.some((re) => re.test(line))) hits.push(`${file}:${i + 1}: ${line.trim()}`);
  });
}
if (hits.length) {
  console.error('Forbidden network or dynamic-code API in extension/src (needs a Privacy review):');
  for (const h of hits) console.error(`  ${h}`);
  process.exit(1);
}
console.log('no-network check: clean');
