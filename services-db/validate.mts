// TG-8: validates services-db/services.json.
//   npm run validate:services                 schema, uniqueness, https, Swift copy in sync
//   npm run validate:services -- --check-urls also requests every cancel/support URL (CI weekly job)
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const srcPath = join(here, 'services.json');
const swiftCopy = join(here, '../ios/Packages/TrialGuardCore/Sources/TrialGuardCore/Resources/services.json');
const raw = readFileSync(srcPath, 'utf8');
const file = JSON.parse(raw) as { version: number; services: Record<string, unknown>[] };

const errors: string[] = [];
const warnings: string[] = [];
const err = (m: string) => errors.push(m);

const REQUIRED: [string, string][] = [
  ['key', 'string'], ['displayName', 'string'], ['names', 'array'], ['domains', 'array'],
  ['emailDomains', 'array'], ['billedVia', 'array'],
];
const OPTIONAL: [string, string][] = [
  ['cancelURL', 'string'], ['supportURL', 'string'], ['logo', 'string'], ['defaultTrialDays', 'number'], ['lastVerified', 'string'],
];
const typeOf = (v: unknown) => (Array.isArray(v) ? 'array' : typeof v);
const keys = new Set<string>();

if (file.version !== 1) err(`version must be 1, got ${file.version}`);
for (const [i, s] of file.services.entries()) {
  const id = (s.key as string) ?? `#${i}`;
  for (const [k, t] of REQUIRED) if (typeOf(s[k]) !== t) err(`${id}: ${k} must be ${t}`);
  for (const [k, t] of OPTIONAL) if (s[k] !== null && s[k] !== undefined && typeOf(s[k]) !== t) err(`${id}: ${k} must be ${t} or null`);
  const allowed = new Set([...REQUIRED, ...OPTIONAL].map(([k]) => k));
  for (const k of Object.keys(s)) if (!allowed.has(k)) err(`${id}: unknown field ${k}`);
  if (!/^[a-z0-9-]+$/.test(id)) err(`${id}: key must be lowercase-kebab`);
  if (keys.has(id)) err(`${id}: duplicate key`);
  keys.add(id);
  if (!(s.names as string[])?.length) err(`${id}: needs at least one name`);
  for (const d of [...((s.domains as string[]) ?? []), ...((s.emailDomains as string[]) ?? [])])
    if (!/^[a-z0-9.-]+\.[a-z]{2,}$/.test(d)) err(`${id}: bad domain ${d}`);
  for (const u of ['cancelURL', 'supportURL'] as const) {
    const v = s[u] as string | null;
    if (v && !v.startsWith('https://')) err(`${id}: ${u} must be https`);
  }
  if (s.logo && !existsSync(join(here, 'logos', s.logo as string))) err(`${id}: logo file missing`);
  if (s.lastVerified === null) warnings.push(id);
  else if (!/^\d{4}-\d{2}-\d{2}$/.test(s.lastVerified as string)) err(`${id}: lastVerified must be YYYY-MM-DD`);
}

if (!existsSync(swiftCopy) || readFileSync(swiftCopy, 'utf8') !== raw)
  err('Swift copy out of sync: run `cp services-db/services.json ios/Packages/TrialGuardCore/Sources/TrialGuardCore/Resources/`');

console.log(`services.json: ${file.services.length} services, ${errors.length} errors, ${warnings.length} never verified`);
for (const e of errors) console.log(`  ✗ ${e}`);
if (warnings.length) console.log(`  ⚠ cancel/support links not yet verified: ${warnings.join(', ')}`);

if (process.argv.includes('--check-urls')) {
  const urls = file.services.flatMap((s) =>
    (['cancelURL', 'supportURL'] as const).filter((k) => s[k]).map((k) => ({ id: s.key as string, k, url: s[k] as string })));
  const results = await Promise.all(urls.map(async (u) => {
    try {
      const r = await fetch(u.url, { method: 'GET', redirect: 'follow', signal: AbortSignal.timeout(15000),
        headers: { 'user-agent': 'Mozilla/5.0 (TrialGuard link check)' } });
      return { ...u, status: r.status };
    } catch (e) {
      return { ...u, status: 0, error: (e as Error).message };
    }
  }));
  console.log('\n| Service | Field | Status | URL |\n| --- | --- | --- | --- |');
  for (const r of results) console.log(`| ${r.id} | ${r.k} | ${r.status || 'error'} | ${r.url} |`);
  // Many sites answer bots with 401/403 on account pages; only 404/410/5xx and DNS failures are hard errors.
  const broken = results.filter((r) => r.status === 404 || r.status === 410 || r.status >= 500 || r.status === 0);
  if (broken.length) {
    console.log(`\n${broken.length} links look broken.`);
    process.exit(1);
  }
}
process.exit(errors.length ? 1 : 0);
