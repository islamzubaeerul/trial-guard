const NAMED: Record<string, string> = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', euro: '€', pound: '£',
  yen: '¥', rsquo: "'", lsquo: "'", rdquo: '"', ldquo: '"', ndash: '–', mdash: '—',
  hellip: '…', eacute: 'é', egrave: 'è', agrave: 'à', ccedil: 'ç', ocirc: 'ô',
};

/**
 * Contract step 1. Keeps single newlines (they separate headings and lines of a
 * receipt) but collapses every other whitespace run to one space.
 */
export function normalize(input: string): string {
  return input
    .replace(/&#x([0-9a-f]+);/gi, (_, h: string) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d: string) => String.fromCodePoint(Number(d)))
    .replace(/&([a-z]+);/gi, (m, n: string) => NAMED[n.toLowerCase()] ?? m)
    .replace(/[​-‍﻿]/g, '')
    .replace(/[   ]/g, ' ')
    .replace(/[‘’ʼ]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\r\n?/g, '\n')
    .replace(/[ \t\f\v]+/g, ' ')
    .replace(/ ?\n[\n ]*/g, '\n')
    .trim();
}
