# Data inventory

Owner: Privacy & Security Reviewer · Last reviewed: 2026-10-25 (M0)

| Data | Where it lives | Retention | Leaves the device? |
| --- | --- | --- | --- |
| Parser input text | Memory only, during a parse call | Discarded when the call returns | No |
| Services database | Bundled read-only JSON in app and extension | Replaced with each release | No |

M0 stores no user data. This table grows in M1 (subscriptions, settings, CloudKit) and M3 (extension storage).
