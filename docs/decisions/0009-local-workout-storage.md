# ADR 0009: Local workout storage

Status: accepted September 23, 2026. The owner approved sqflite and Flutter SDK integration_test with “okay go ahead.”

## Problem

The installed sample keeps the latest set/count in widget memory and resets it on return to Today. It does not save each set or recover sessions after termination. Permanent logging is the next bounded feature; training-generation gates remain intact.

## Decision

Use SQLite through the `sqflite` package (current published version 2.4.4), pinned through the application lockfile. Add Flutter SDK `integration_test` as a development dependency for real on-device storage checks. No other direct packages are proposed. No cloud account or network service is required for storage.

[Flutter's SQLite recipe](https://docs.flutter.dev/cookbook/persistence/sqlite) uses sqflite. The [package documentation](https://pub.dev/packages/sqflite) documents iOS support, transactions and versioned database opening. Package selection is an engineering recommendation, not a guarantee of durability without tests.

Domain entities and repository interfaces remain pure Dart. The data implementation owns SQL, transactions and schema migration. An application controller coordinates saving; widgets render save state. Do not add database calls to widgets.

## First deliverable

A clearly marked practice session can log distinct exercise sets, close and reopen without losing acknowledged records, resume a draft, and show completed results. Saved practice data must never contribute to real progression. Keep the exercise catalog disabled until its reviews are complete.

## Schema contract

- `profiles`: local opaque ID, schema version, validated profile data; no required name, gym location or account.
- `sessions`: ID, profile ID, explicit UTC start/completion times, stable sequence, practice/real marker, draft/completed status, revision; immutable recommendation snapshot with rule/catalog version when real.
- `session_exercises`: session/slot identity, exact exercise/setup/load convention, ordering and prescribed targets, kept separate from actual results.
- `set_records`: stable ID, session/exercise ID, index/side, warm-up/working designation, load in integer micro-pounds, unit/convention, actual reps, nullable reported RIR, explicit validity flags and skip status.
- `actions`: unique action ID within profile, operation type, canonical payload and resulting revision; retries with identical identity/payload return the original outcome, while conflicting reuse is rejected.
- `set_revisions`: preserved prior record and correction metadata. History queries use the current record once, not every revision as extra volume.

Profile/session-scoped foreign keys, uniqueness constraints and domain validation must reject cross-profile references and duplicate set identities. Payload-size and numeric bounds must be explicit before accepting arbitrary imported data. Import/export remain a later bounded feature.

## Write and recovery behavior

Each accepted action is one transaction containing the data change, revision and action receipt. Show saved/completed only after the transaction succeeds. Disable repeated submission while saving; retain the same action identity for retry. Failed writes keep the entered values visible and show retry, never success. Repeated completion returns the existing completion rather than creating a second workout.

Save actual sets, corrections, skips and completion after each accepted action. Preserve targets and actuals separately. Invalid entries do not change durable state. Completed session corrections preserve original recommendation history and affect only future recalculation. Opening an unsupported newer schema fails visibly without deleting or replacing the database. Schema migrations are transactional; never recover an error by clearing user data.

Use parameterized values and transactions; enable foreign-key enforcement and verify it. The database remains in the app sandbox and must not be bundled into source control, printed in production logs or exposed by file sharing. This does not claim custom encryption or immunity to device backup behavior. Verify iOS file protection and backup handling before making stronger privacy promises.

## Acceptance checks

1. Log three distinct practice sets, terminate the app, reopen and recover all acknowledged values exactly once.
2. Interrupt an uncommitted write: restore either the old state or the committed new state, never a partial action.
3. Repeat an action/completion and retry a failed acknowledgement: no duplicate set or session.
4. Simulate a save failure: screen keeps inputs and never reports saved/completed.
5. Correct a saved set: one current set plus preserved revision; no duplicate volume.
6. Exercise missing/invalid numbers, RIR, units and references, two-profile isolation and warm-up/working distinction.
7. Verify schema creation, close/reopen, transaction rollback, unsupported-version refusal and future migration fixtures against actual SQLite on the physical phone. Pure fake repository tests alone do not establish storage durability.
8. Run formatting, analysis, unit/widget tests and the device integration test before reporting completion.

## Alternatives

Drift was an earlier architectural candidate, not an approved dependency. It offers typed query generation but introduces additional tooling for this small initial slice. Preferences storage is unsuitable for relational workout/action history. Handwritten native SQLite bridging would avoid a third-party plugin but adds platform maintenance and more code to verify. A JSON snapshot file would require custom concurrency, journaling and migration behavior that SQLite already provides.

## Approval boundary

Repository AGENTS.md states: “Avoid unnecessary dependencies. Explain and obtain approval before adding one.” The owner approved sqflite and the SDK integration_test package. Both approved dependencies have now been added. Approval of storage does not approve unrelated subscriptions, cloud sync or additional packages.


## Implemented first slice and remaining schema work

Schema v1 stores practice-only sessions, their two generic movement slots, individual set payloads, correction revisions and transactional action receipts. Profiles currently contain only opaque IDs. Session ordering uses explicit UTC start time plus stable ID; the real-program sequence, immutable recommendations, detailed per-side tracking and full profile schema are deferred until the real logging contract is integrated. Actual values are validated before writes; defensive format limits are 1,000,000 lb, 10,000 reps/RIR and 10,000 set index, not exercise recommendations. RIR remains nullable and unassessed validity stays explicit.

The production entry point now opens the persistent practice screen. The old temporary sample flow remains available only through explicit test/demo injection. No actual owner weights are seeded. The app uses no direct network storage service. Backup behavior and platform file-protection review remain open; no claim of custom database encryption is made.

The device acceptance workflow uses isolated databases named `practice_repository_fixture.sqlite` and `practice_restart_fixture.sqlite`. Always use `--no-uninstall` with Flutter integration tests: Flutter's default uninstall would remove app data. The tests delete only their named fixture databases, never the production `adaptive_workout.sqlite` database.

## Manual program logging extension — September 23

The owner authorized logging directly from the approved plan after verifying the preview. This slice uses a separate `program_logging.sqlite` schema v1, leaving existing practice tables and data untouched. It stores manual actuals, not generated recommendations or verified baselines. All records remain ineligible for progression. No new dependency is needed.

`logs` holds profile/session identity, revision, completion, validated actuals and an immutable prescription snapshot. `revisions` retains every prior accepted payload with a profile/session foreign key. `receipts` stores profile/action identity and the exact request for idempotent retries. Each write atomically updates the record, prior revision and receipt; a unique index permits one manual draft per profile. Stored prescriptions must match the pinned program version or loading fails visibly. Future program versions require an explicit historical reader/migration, never a silent rewrite.

Manual logging permits owner-specified exact setup labels and load conventions without declaring the setup verified. Alternatives require explicit variation selection. Dumbbell loads are per dumbbell; bodyweight and assistance remain distinct. Single-arm pulldowns record left and right separately. Warm-ups have separate identities and cannot satisfy working-set completion. Every working-set slot must have actuals or an explicit skip before finishing; otherwise the workout remains a recoverable draft. Finished workouts containing skips remain clearly labeled. This does not implement missed-day scheduling, partial-workout abandonment, exercise eligibility or warm-up prescription execution. Pain stops adding actual sets to the affected exercise; corrections and explicit skips remain available. Prior payloads retain corrected reports.

Format bounds match the practice logger for actual values, with a 120-character setup label and at most 100 warm-up indices per side/exercise. These are storage limits, not training targets. User data remains on device and is not printed in logs. Unsupported schema versions fail without deleting data. Device integration tests use only `program_logging_fixture.sqlite` and must run with `--no-uninstall`.
