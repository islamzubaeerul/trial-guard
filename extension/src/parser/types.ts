// Parser contract v1 — see docs/contracts/parser.md. Keep in step with the Swift Parser/Types.swift.

export type Cycle = 'weekly' | 'monthly' | 'quarterly' | 'yearly' | 'unknown';

export interface Anchor {
  text: string;
  href: string;
}

export interface ParseInput {
  text: string;
  url?: string;
  title?: string;
  senderDomain?: string;
  anchors?: Anchor[];
  /** The moment of capture. The parser never reads the clock. */
  now: Date;
  /** IANA time zone, e.g. "America/Toronto". */
  timeZone: string;
  /** BCP-47 locale, e.g. "en-CA". */
  locale: string;
  /** ISO 4217, e.g. "CAD". */
  defaultCurrency: string;
}

export interface Confidence {
  service: number;
  trialEnd: number;
  price: number;
  cancelURL: number;
  overall: number;
}

export interface ParseResult {
  isTrial: boolean;
  serviceName?: string;
  serviceKey?: string;
  trialDays?: number;
  /** "YYYY-MM-DD" in the input time zone. */
  trialEnd?: string;
  nextChargeDate?: string;
  /** Canonical decimal string, e.g. "16.99", "22", "139.00". */
  price?: string;
  currency: string;
  cycle: Cycle;
  cancelURL?: string;
  confidence: Confidence;
  evidence: Record<string, string>;
}

export interface ServiceDefinition {
  key: string;
  displayName: string;
  names: string[];
  domains: string[];
  emailDomains: string[];
  cancelURL: string | null;
  supportURL: string | null;
  logo: string | null;
  defaultTrialDays: number | null;
  billedVia: string[];
  lastVerified: string | null;
}
