# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- TG-1: Monorepo layout, README, changelog.
- TG-2: ADR-001 capture inbox pattern.
- TG-3: Parser contract (`docs/contracts/parser.md`).
- TG-4: First parser fixture corpus (32 trial cases, 10 negatives).
- TG-5: TypeScript trial parser with fixture-driven tests and accuracy report.
- TG-6: Swift trial parser in `TrialGuardCore` (port of TG-5).
- TG-7: Parser parity script.
- TG-8: Services database (40 entries) and validator.
- TG-9: CI workflow (lint, tests, fixtures, services DB, secret scan, no-network check, macOS Swift build).
