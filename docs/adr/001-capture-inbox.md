# ADR-001: Extensions hand captures to the app through an App Group inbox

Status: Accepted · Date: 2026-10-25 · Ticket: TG-2

## Context

The spec (§6) has the app, share extension, widgets, App Intents and Safari extension all reading and writing one SwiftData store in the App Group, with CloudKit mirroring enabled.

Each extension runs in its own process. When several processes open a CloudKit-mirrored Core Data / SwiftData store, each starts its own mirroring machinery. This is a well-known source of duplicate records, history-tracking conflicts and silent sync stalls. Share extensions also have a tight memory budget (~120 MB), and starting CloudKit inside one is wasteful.

## Decision

1. Only the **main app** opens the CloudKit-mirrored SwiftData store.
2. Extensions and intents call `CaptureInbox.write(_:)`, which atomically writes `Inbox/<uuid>.json` (a `Capture` value) into the App Group container.
3. Right after writing, the extension schedules **provisional reminders** for that capture with `ReminderScheduler.scheduleProvisional(for:)`, using identifiers derived from the capture UUID. The user is covered even if they never open the app.
4. The main app calls `CaptureInbox.ingest(into:)` on launch, on foreground and in its daily `BGAppRefreshTask`. Ingest dedupes (same `serviceKey` or normalized name, `trialStart` within 48 h), saves, reconciles reminders (which replaces the provisional ones), and only then deletes the inbox file.
5. Ingest is idempotent: the subscription keeps the capture UUID as its `id`, so a crash between save and delete can't create a duplicate.
6. Widgets read from a small `Snapshot.json` the main app writes after every save, not from the store.

## Alternatives considered

- **Shared store in every process (spec as written):** simplest code, but carries the multi-process mirroring risk above.
- **Shared store with CloudKit disabled in extensions:** two configurations of one SQLite file; still multi-process writes with history tracking, and fragile.
- **Darwin notifications + XPC to the app:** the app may not be running, so captures would be lost.

## Consequences

- A capture becomes a full subscription record only when the app next runs. Reminders fire regardless.
- `Capture` becomes a versioned, Codable contract shared by Swift and the Safari native handler (`docs/contracts/native-messaging.md`, M3).
- Widgets show data as of the last app save. That is acceptable for "next trial ending".
- The spec doc §6 should note this refinement.
