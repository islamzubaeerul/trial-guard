# Data inventory

Owner: Privacy & Security Reviewer · Last reviewed: 2026-10-25 (M0)

| Data | Where it lives | Retention | Leaves the device? |
| --- | --- | --- | --- |
| Parser input text | Memory only, during a parse call | Discarded when the call returns | No |
| Services database | Bundled read-only JSON in app and extension | Replaced with each release | No |

M0 stores no user data. This table grows in M1 (subscriptions, settings, CloudKit) and M3 (extension storage).

## Review: M0 (2026-10-25)

Privacy: Pass. No storage, no network APIs (CI guard added), no runtime dependencies, fixtures contain only fictional data. The weekly link-check job runs in CI only and touches no user data.
