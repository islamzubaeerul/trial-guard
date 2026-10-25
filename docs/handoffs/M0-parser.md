## Handoff: TG-3 to TG-9 (parser foundations)

What changed: Parser contract v1.1; 63 fixtures (46 trial, 17 negative; 20 written blind by QA); TypeScript parser; Swift port in TrialGuardCore; parity script; 40-entry services DB with validator; CI and weekly link check.

Files: `docs/contracts/parser.md`, `parser-fixtures/`, `extension/src/parser/`, `extension/tests/`, `extension/scripts/`, `ios/Packages/TrialGuardCore/`, `services-db/`, `scripts/parser-parity.sh`, `scripts/parity-compare.mjs`, `.github/workflows/`.

How to verify:
1. `cd extension && npm ci && npm test` → 76 tests pass.
2. `npm run report` → every target met; "Failing fixtures" section absent.
3. `npm run validate:services` → 0 errors (40 "never verified" warnings are expected).
4. `npm run lint:no-network` → clean.
5. On a Mac with Xcode 16+: `swift test --package-path ios/Packages/TrialGuardCore` → all tests pass.
6. `./scripts/parser-parity.sh` → "Both parsers agree on every field of every fixture."

Tests added: `parser.fixtures.test.ts` (43), `parser.units.test.ts` (13), `ParserFixtureTests.swift`, `ParserUnitTests.swift`.

Known gaps / follow-ups:
- Swift code has not been compiled yet: no Swift toolchain in the build sandbox. Steps 5–6 are the first real run. Expect a few compile fixes.
- All 40 cancel links are unverified (`lastVerified: null`); the weekly CI job will check them once the repo is on GitHub.
- Fixtures are synthetic. Real anonymized trial emails are needed to measure real-world accuracy.
- TG-10 (Xcode project) is blocked on Xcode access.

Next: QA Engineer for verification against the held-out set; iOS Engineer for step 5.
