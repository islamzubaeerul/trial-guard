import { describe, expect, it } from 'vitest';
import { parse } from '../src/parser';
import { check, loadFixtures } from './fixtures';

describe('parser fixtures (contract v1)', () => {
  for (const fx of loadFixtures()) {
    it(fx.name, () => {
      const failures = check(parse(fx.input), fx.expected).filter((c) => !c.ok);
      expect(failures).toEqual([]);
    });
  }
});
