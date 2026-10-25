# Contract: Trial parser

Version 1.2 · Owner: Parser Engineer · Consumers: iOS Engineer (app, share extension, intents), Extension Engineer (banner) · Ticket: TG-3

Both implementations (`extension/src/parser/` in TypeScript and `TrialGuardCore/Parser/` in Swift) must produce the **same output for the same input**. `parser-fixtures/` is the executable form of this contract. When this document and a fixture disagree, fix one of them in the same PR.

## Input

```
ParseInput {
  text: String              // visible page text or email body (already HTML-stripped by the caller)
  url?: String              // page URL (extension) or shared URL
  title?: String            // page <title> or email subject
  senderDomain?: String     // email sender domain, e.g. "email.canva.com"
  anchors?: [{ text: String, href: String }]   // links on the page, at most 20
  now: Instant              // the moment of capture; never read the clock inside the parser
  timeZone: String          // IANA, e.g. "America/Toronto"
  locale: String            // BCP-47, e.g. "en-CA", "fr-CA", "en-US"
  defaultCurrency: String   // ISO 4217, e.g. "CAD"
}
```

Callers strip `<del>`, `<s>`, hidden elements, scripts and styles before passing `text`, so struck-through prices never reach the parser.

## Output

```
ParseResult {
  isTrial: Bool               // a trial signal was found (see "Trial signal")
  serviceName?: String
  serviceKey?: String         // key into services.json when matched
  trialDays?: Int             // only when a length is stated, or derived from an explicit end date
  trialEnd?: LocalDate        // "YYYY-MM-DD", calendar date in input.timeZone; only when isTrial
  nextChargeDate?: LocalDate  // a cued charge/renewal date on a NON-trial text (active subscriptions, later use)
  price?: String              // canonical decimal string, see "Money"
  currency: String            // ISO 4217; defaultCurrency when no price or a bare "$"
  cycle: "weekly" | "monthly" | "quarterly" | "yearly" | "unknown"
  cancelURL?: String          // https only
  confidence: { service, trialEnd, price, cancelURL, overall }   // each 0…1, rounded to 2 decimals
  evidence: { [field]: String }   // the matched snippet, for display and debugging
}
```

## Pipeline

1. **Normalize.** Decode `&amp; &nbsp; &#NN; &#xNN;` and common named entities; replace NBSP and narrow NBSP with a space; remove zero-width characters (U+200B–U+200D, U+FEFF); keep single newlines (they separate lines of a receipt) and collapse every other whitespace run to one space; curly apostrophes become `'`. Matching runs on a lowercased copy; evidence comes from the original.
2. **Service** (first rule that yields a candidate wins):
   1. URL host matches a service `domains` entry (host equals it or ends with `.` + it) → confidence 0.95.
   2. Sender domain matches `emailDomains` or `domains` → 0.95.
   3. A service `names` alias appears (case-sensitive, word-bounded) in the title or the first 300 characters of text → 0.70.
   4. Fallback: the title with boilerplate removed (`Welcome to`, `Your receipt from`, `Confirm your`, `Checkout`, `Sign up`, `Subscribe`, `Order confirmation`), split on ` | `, ` - `, ` — `, ` · `, keeping the longest remaining part of 2–40 characters → 0.40.

   When a rule matches several services (e.g. `apple.com`, `amazon.ca`), prefer a service with an alias in the **title**; otherwise the **longest** alias found in the text; otherwise the first in file order.
3. **Trial length.** Patterns in `patterns` (both implementations keep the same list in the same order). Number words one–twelve, fourteen, fifteen, thirty, sixty, ninety and French un/une–douze, quatorze, quinze, trente, soixante are accepted. `free for (the) (first) <n> <unit>` is a length. Units: day, week, month, year (French jour, semaine, mois, an). Month and year lengths are added on the calendar (Oct 31 + 1 month = Nov 30), never as 30 or 365 days.
4. **Trial signal.** `isTrial` is true when a trial length matched, or one of these phrases appears: `free trial` (not followed by `-` or a letter, so "free trial-size" is not a signal), `trial period`, `-day trial`, `-week trial`, `-month trial`, `try it free`, `try free`, `first month/week/year (is) free`, `<n> days/weeks/months free`, `essai gratuit`, `période d'essai`. A bare "trial" (court trial, clinical trial) is **not** a signal, and neither is `free for` unless followed by a duration ("Free for members" is not a trial).
5. **Dates.** Recognized forms: `Nov 23, 2026` · `November 23 2026` · `23 November 2026` · `Nov 23` (no year) · `2026-11-23` · numeric `23/11/2026` or `11/23/2026` · French `23 novembre 2026`, `1er novembre`. Numeric slash dates: if one side is > 12 that decides it; otherwise `en-US` reads M/D and every other locale reads D/M. A date with no year resolves to its next occurrence on or after today in `timeZone`.
6. **Cued dates.** A date is *cued* when the 50 characters before it end with a cue, allowing up to 45 characters between cue and date that contain no sentence end (`. `, `!`, `?`, newline). Two cue groups:
   - **End cues:** `trial ends`, `trial expires`, `trial will end`, `trial is over`, `trial runs until`, `runs until`, `free until`, `no charge until`, `jusqu'au`, `cancel before`, `cancel anytime before`, `se termine (le)`, `prendra fin (le)`.
   - **Charge cues:** `be charged`, `be billed`, `charge you (on)`, `charged`, `billed`, `first payment|charge|bill`, `billing date`, `renews`, `renew`, `renewal date`, `billing starts`, `facturé(e)`, `prélevé(e)`.

   A date is also charge-cued **or** when the 40 characters after it begin (after any spaces or `, . : ;`) with `you'll be charged`, `you will be charged`, `you'll be billed`, `you will be billed`. The **first cued date in text order** wins.
   - `isTrial` and cued date → `trialEnd` = that date, confidence 0.95 (even if it is in the past; the UI warns).
   - `isTrial`, no cued date, trial length found → `trialEnd` = today + length, confidence 0.70.
   - not `isTrial` and a **charge**-cued date → `nextChargeDate` = that date; `trialEnd` absent. End cues never set `nextChargeDate`.
   - `trialDays` = the stated length in days (calendar-computed for months/years); if no length but `trialEnd` came from a cued date, `trialEnd − today` when positive.
7. **Money.** Recognized: symbol or code before (`CA$`, `C$`, `US$`, `A$`, `CAD`, `USD`, `EUR`, `GBP`, `€`, `£`, `¥`, `$`) or after (`$`, `€`, `$ CA`, `CAD`, `USD`, `EUR`). Number formats `1,234.56` · `1.234,56` · `14,99` · `14.99` · `22` · `1 234,56`. A separator followed by exactly 1–2 digits at the end is the decimal mark.
   - **Canonical price string:** digits, optional `.` and the decimals **as written** (`$22` → `"22"`, `$139.00` → `"139.00"`, `11,99 $` → `"11.99"`, `€1.234,56` → `"1234.56"`).
   - Currency: `CA$ C$ CAD "$ CA"` → CAD; `US$ USD` → USD; `A$` → AUD; `€ EUR` → EUR; `£ GBP` → GBP; `¥` → JPY; bare `$` → `defaultCurrency`.
   - **Cycle** must follow the amount within 20 characters: `/`, `per`, `a`, `an`, `every`, `each`, `par`, optionally `billed`, then `month mo mth monthly`, `year yr annum annual annually yearly`, `week wk weekly`, `quarter quarterly`, `mois`, `an année`, `semaine`. `billed annually` / `billed monthly` also count.
   - Rejected candidates: amount 0; preceded within 15 characters (same sentence) by `save`, `was`, `off`, `discount`, `économisez`, `today`; followed within 6 characters by `off`; preceded within 20 characters by `due today`.
   - Choice: among candidates with a cycle, prefer one preceded within 30 characters by `then`, `after`, `renews at`, `renew`, `billed`, `fee of`, `pay`, `puis`, `facturé` (confidence 0.95); otherwise the cycled candidate nearest the trial phrase (0.70). With no cycled candidate, the money nearest the trial phrase within 120 characters (0.40, cycle `unknown`).
8. **Cancel URL.** First https anchor whose text matches `cancel`, `manage (your )?(subscription|plan|membership)`, `billing`, `account settings`, `gérer (mon|votre) abonnement` → 0.95. Else the matched service's `cancelURL` → 0.70. Else absent. Never invent a URL.
9. **Score.** `overall = 0.30·service + 0.35·trialEnd + 0.20·price + 0.15·cancelURL`. When `isTrial` is false, `overall` is halved. Round to 2 decimals.

## Fixture format

```
parser-fixtures/<service>-<kind>-<nn>.txt              kind ∈ checkout | confirm-email | receipt | negative
#! now=2026-10-24T14:00:00-04:00 tz=America/Toronto locale=en-CA currency=CAD
#! url=https://www.canva.com/pro/checkout
#! title=Canva Pro checkout
#! sender=email.canva.com
#! anchor=Manage subscription|https://www.canva.com/settings/billing-and-teams
<text body…>
```

`<name>.expected.json` lists the fields asserted. Omitted = don't care; `null` = must be absent. Extra keys:

- `"overallBelow": 0.5` asserts `confidence.overall < 0.5` (all negatives carry it).
- `"overallAtLeast": 0.8` asserts the confident path.

Accuracy is computed per field over the fixtures that assert it. Targets: service 95 %, trialEnd 90 %, price 85 %, negatives 100 %.

## Changing this contract

Bump the version at the top, add or adjust fixtures in the same PR, and get review from the other-language side and from both consumers (see the cross-review matrix in `trial-guard-lead`).

## Open questions (from QA review of v1.1, 2026-10-25)

Decided in v1.2: whole-word `free trial`; `free for the first <n> days`; extra number words; `runs until` / `no charge until` / `charge you on` cues; punctuation before an after-date cue. Still open:

| # | Question | Owner | Current behaviour |
| --- | --- | --- | --- |
| Q1 | Should intro offers get a reminder like a trial? | **Decided 2026-10-25: yes** (TG-11, M1) | Not yet implemented: not a trial; `nextChargeDate` set when a charge cue is present |
| Q2 | When one amount has two cycles ("$2.99/mo, billed annually $35.88"), which is the charge? | Parser Engineer | The first cycle after the amount wins |
| Q3 | Cancel URLs per locale (Crave French, audible.com vs .ca) | Parser Engineer | One `cancelURL` per service |
| Q4 | en-CA numeric dates: D/M or M/D? Canadian sites use both | Parser Engineer, with real fixtures | D/M unless one side is > 12 |
| Q5 | `|` inside fixture anchor text | Parser Engineer | Unsupported; split on the first `|` |
