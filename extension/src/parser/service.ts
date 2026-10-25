import type { ServiceDefinition } from './types';

export interface ServiceMatch {
  name: string;
  key?: string;
  def?: ServiceDefinition;
  confidence: number;
  evidence: string;
}

const isWordChar = (c: string | undefined) => !!c && /[A-Za-z0-9À-ÿ]/.test(c);

/** Case-sensitive, word-bounded search that also works for aliases ending in "+". */
export function findAlias(hay: string, alias: string): number {
  let from = 0;
  for (;;) {
    const i = hay.indexOf(alias, from);
    if (i < 0) return -1;
    const before = hay[i - 1];
    const after = hay[i + alias.length];
    const lastIsWord = isWordChar(alias[alias.length - 1]);
    if (!isWordChar(before) && (!lastIsWord || !isWordChar(after))) return i;
    from = i + 1;
  }
}

function hostOf(url: string | undefined): string | undefined {
  if (!url) return undefined;
  try {
    return new URL(url).hostname.toLowerCase().replace(/^www\./, '');
  } catch {
    return undefined;
  }
}

const domainMatches = (host: string, domain: string) => host === domain || host.endsWith(`.${domain}`);

/** Longest alias of `def` found in `hay`, or 0. */
function aliasScore(def: ServiceDefinition, hay: string): number {
  let best = 0;
  for (const n of def.names) if (n.length > best && findAlias(hay, n) >= 0) best = n.length;
  return best;
}

/** Among several candidates, prefer an alias in the title, then the longest alias in the text. */
function pick(cands: ServiceDefinition[], title: string, text: string): ServiceDefinition {
  if (cands.length === 1) return cands[0]!;
  let best = cands[0]!;
  let bestScore = -1;
  for (const c of cands) {
    const t = aliasScore(c, title);
    const score = t > 0 ? 1000 + t : aliasScore(c, text);
    if (score > bestScore) {
      best = c;
      bestScore = score;
    }
  }
  return best;
}

const BOILERPLATE =
  /(welcome to|your receipt from|confirm your|order confirmation|checkout|sign up|subscribe to|subscribe|start your free trial)/gi;

export function identifyService(
  services: ServiceDefinition[],
  text: string,
  title: string | undefined,
  url: string | undefined,
  senderDomain: string | undefined,
): ServiceMatch | undefined {
  const t = title ?? '';
  const host = hostOf(url);
  if (host) {
    const c = services.filter((s) => s.domains.some((d) => domainMatches(host, d)));
    if (c.length) {
      const def = pick(c, t, text);
      return { name: def.displayName, key: def.key, def, confidence: 0.95, evidence: host };
    }
  }
  const sender = senderDomain?.toLowerCase();
  if (sender) {
    const c = services.filter((s) => [...s.emailDomains, ...s.domains].some((d) => domainMatches(sender, d)));
    if (c.length) {
      const def = pick(c, t, text);
      return { name: def.displayName, key: def.key, def, confidence: 0.95, evidence: sender };
    }
  }
  const head = text.slice(0, 300);
  const named = services.filter((s) => aliasScore(s, t) > 0 || aliasScore(s, head) > 0);
  if (named.length) {
    const def = pick(named, t, head);
    return { name: def.displayName, key: def.key, def, confidence: 0.7, evidence: def.displayName };
  }
  if (t) {
    const parts = t
      .replace(BOILERPLATE, '')
      .split(/\s+[|\-—·]\s+|^\s*[|\-—·:]\s*|\s*[|\-—·:]\s*$/)
      .map((p) => p.trim())
      .filter((p) => p.length >= 2 && p.length <= 40);
    const best = parts.sort((a, b) => b.length - a.length)[0];
    if (best) return { name: best, confidence: 0.4, evidence: t };
  }
  return undefined;
}
