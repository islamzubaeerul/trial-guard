# Trial Guard

Catch a free trial the moment you sign up, and get reminded before it bills.

Trial Guard is a free, local-first iOS app plus a browser extension. It has no account, no backend and no bank linking. Your data stays on your devices and in your own iCloud.

- **Spec:** Trial Guard — Architecture & Design Spec (https://claude.ai/artifact/FA5C34KZKHbZQuWCxNMXmo)
- **Bundle ID:** `com.substacks.trialguard`
- **Status:** M0 Foundations (target Nov 7, 2026)

## Repository layout

| Path | What lives there | Owner role |
| --- | --- | --- |
| `ios/` | Xcode project, app targets, `Packages/TrialGuardCore` | iOS Engineer |
| `extension/` | Manifest V3 browser extension (Safari, Chrome, Edge, Firefox) | Extension Engineer |
| `extension/src/parser/` | TypeScript trial parser | Parser Engineer |
| `ios/Packages/TrialGuardCore/Sources/TrialGuardCore/Parser/` | Swift trial parser | Parser Engineer |
| `parser-fixtures/` | Shared test corpus both parsers must pass | Parser Engineer |
| `services-db/` | Known-services database and validator | Parser Engineer |
| `site/` | Privacy policy, support page, QR landing page (GitHub Pages) | Release Engineer |
| `docs/` | Tickets, contracts, ADRs, handoffs, test plans | Tech Lead |

## Quick start

```bash
# TypeScript parser, services DB, fixtures
cd extension && npm ci && npm test
npm run report           # per-field accuracy over parser-fixtures/
npm run validate:services

# Swift parser (macOS with Xcode 16+ or Swift 6 toolchain)
swift test --package-path ios/Packages/TrialGuardCore

# Compare both parsers case by case
./scripts/parser-parity.sh
```

## How work is done

Every change follows the team process in the `trial-guard-lead` skill: ticket → design → contract → build → peer review → privacy review → QA → merge. See `docs/tickets/` for current work and `docs/adr/` for decisions.

## Licence

To be decided before launch (see open question in the spec). All rights reserved until then.
