# Native iOS migration plan

> Historical implementation plan. The owner subsequently confirmed that the deleted Flutter app held only test data, approved a fresh Swift start, and requested skipping further physical-device checks. The protected real-data replacement and final phone-acceptance steps below therefore do not apply to this cutover. See [current migration evidence](SWIFT_MIGRATION_STATUS.md) and [ADR 0018](decisions/0018-native-swift-migration.md). Flutter paths below refer to the preserved reference in Git history.

Date: September 24, 2026. Status: planning only; implementation has not started.

## Objective and scope

Move the complete maintained application to Swift and SwiftUI, editable, buildable,
testable and runnable directly in Xcode without a Flutter runtime. iOS is the
priority; Android will be considered only if the iOS app proves useful.

Preserve approved behavior, offline operation, saved data and deterministic rules.
The first deliverable is a usable native manual logger. Full migration also ports
the existing standalone adaptive engine, repositories, development utilities and
their meaningful tests. Native logging alone does not constitute full migration.

This plan does not authorize new training rules, activate blocked recommendations,
add cloud services, HealthKit, subscriptions, notifications or Android support.
Existing product validation and catalog/safety review requirements still apply.
The previous September 29 private-build target is not a native-parity commitment;
reassess the schedule after the storage proof and first native workout flow.

## Verified starting point

Repository reference: `c28d22f50dca8eced393e749d0142b0877b4ba0f`.
The working tree was clean before this plan was added.

- 54 application Dart files, approximately 15,036 lines.
- 48 Dart files under `test` and 9 under `integration_test`, approximately 12,018
  combined lines. File counts include fixtures/helpers, not just test suites.
- Locally selected tools report Xcode 27.0 (27A266a) and Apple Swift 6.4.
  This is tool availability, not native build or device validation.
- Existing project settings mix iOS 15.0 and Xcode's recommended deployment
  target. Resolve the effective supported minimum before choosing native APIs;
  do not silently raise it based on the owner's phone.
- Production bundle identifier: `com.adaptiveworkout.adaptiveWorkout`.
- `lib/main.dart` launches the persistent Workout/Settings shell. The generated
  workout services are not registered as a live recommendation flow.

Current source and specifications are the migration reference. Older test counts
in documentation are historical evidence; establish a fresh baseline in phase 0.

## Proposed native structure

Build alongside the existing app, initially under `native/`, without modifying
the Flutter `ios/Runner` project in place:

```text
native/
  AdaptiveWorkout.xcodeproj
  AdaptiveWorkout/             SwiftUI app, composition, assets, privacy manifest
    Features/                 Workout, History, Settings, Program, Setup, Gyms
    Design/                   Shared styles and accessible controls
    Platform/                 Haptics, lifecycle and date conversion
  Packages/WorkoutCore/
    Sources/WorkoutDomain/    Pure rules, records, validation, repository protocols
    Sources/WorkoutApplication/  Actions, services and state coordination
    Sources/WorkoutPersistence/  SQLite adapters and versioned payload codecs
    Tests/                    Rule, application and persistence tests
  AdaptiveWorkoutUITests/    Critical native interactions
```

Views depend on application state/actions. Application code depends on domain
contracts; persistence implements them. Domain rules import neither SwiftUI nor
SQLite, and receive dates, clocks, IDs and other decision inputs explicitly.
Keep screen state on the main actor and serialize database work behind repository
boundaries. Do not hold a transaction open across an unrelated asynchronous wait.

Use SwiftUI with UIKit where necessary, native system assets, and Apple's bundled
SQLite through a small tested adapter. No third-party dependency is proposed.
Do not introduce SwiftData during the language migration. A local Swift package
organizes our own code; it does not imply a downloaded package dependency.
Reconsider the adapter only if the compatibility proof identifies a concrete need;
repository rules require approval before adding an external dependency.

## Feature and test inventory

| Existing capability | Native work and acceptance scope | Primary source/tests |
| --- | --- | --- |
| Two-tab shell | Workout/Settings, retained draft and unsaved settings state, inline disclosures | `features/home`, `features/settings`; home/settings/widget tests |
| Manual logging | Five templates; start/resume; working/warm-up/side records; validation; corrections; skips; finish/early finish; template switch; confirmed delete; stable retries | `domain/logging/program_log.dart`, `features/program`; program domain/controller/page tests; program repository integration test |
| Frozen programs | Preserve historical v1 and current v2 manual prescriptions and generated-version references; never resolve old logs using only today's template | `domain/workout/owner_program.dart`; owner-program and log tests |
| History and graphs | Search/date filtering, drill-down, correction/deletion refresh, exact-value disclosure and comparable series; no invented progress metrics | `domain/history`, `features/history`; history and visual tests |
| Timing | Saved elapsed-time semantics; in-memory rest deadline; background/tab behavior and once-only foreground feedback | `features/program/session_timer.dart`; timer tests; `UI_DESIGN.md` |
| Appearance and haptics | System/Light/Dark persistence; native semantic cues, mute, foreground guard, acknowledgement timing and quiet cancellation | appearance/haptics sources and unit/device tests; existing AppDelegate bridge |
| Training setup | Preferences, verified equipment/starting loads, revision/staleness rules, reports and rehearsal codecs; preserve incomplete/unknown blocking | `domain/training`, `features/setup`; setup/intake/controller/repository tests |
| Gym inventories | Local profiles, availability, corrections, selected gym and transactional save acknowledgement; gym availability does not grant recommendation eligibility | `domain/gyms`, `features/gyms`; gym tests and `GYM_PROFILES.md` |
| Catalog and eligibility | Snapshot mapping, provenance/licenses, canonical integrity, validation and guarded safety/eligibility; disabled real entries stay disabled | `domain/exercises`, `data/catalog`; catalog/mapper/eligibility tests and wger fixtures |
| Progression and warm-ups | Exact numeric rules, evidence exclusions, versions, ordered ladders, bodyweight/assistance handling, reason codes and missing-input rejection | progression and warmup/v2 domain tests |
| Planning and composition | Explicit civil dates, ordered queue, early completion versus interruption, paired rounds/rest/walking, stable output and blocked outcomes | planning/composer/persisted-rehearsal tests |
| Generated history and lifecycle | Immutable snapshots, audit chain, profile isolation, idempotent actions, stale revisions and saved-workout lifecycle | recommendation domain/repository tests; generation and saved-workout service tests |
| Practice and recovery tools | Preserve isolated practice storage and developer-only access; port useful recovery probes; no practice/manual progression evidence | practice tests; `tool/program_storage_probe.dart`, `tool/storage_recovery_probe.dart` |

Create a tracked parity checklist during phase 0 mapping each existing test case
or behavior group to a native test, manual check or documented obsolete
Flutter-only assertion. Line count and screenshot similarity are not completion
criteria. Native controls need equivalent usable behavior, not pixel-identical
Material widgets.

## Storage compatibility contract

| Store | Current SQL version | Must preserve |
| --- | --- | --- |
| `program_logging.sqlite` | 2 | Frozen prescriptions, logs, corrections, receipts, one-draft constraints and deletion tombstones; schema-1 upgrade |
| `training_setup.sqlite` | 1 | Versioned profile payloads, revisions and receipts; payload schema versions differ from SQL versions |
| `recommendations.sqlite` | 1 | Profiles, immutable recommendation payloads including versions 1/2, occurrences, audit revisions and receipts |
| `adaptive_workout.sqlite` | 1 | Separate practice records, corrections and actions |
| `gym_profiles.sqlite` | 1 | Validated inventory payload and local selection |
| `appearance.sqlite` | 1 | Validated appearance preference |
| Native UserDefaults | Not SQL | Existing haptic preference key and behavior |

Do not assume matching table names imply compatibility. Verify database paths,
PRAGMAs, constraints/indexes, transaction behavior, JSON field omission/null rules,
timestamp precision/time zones, integer/double representation, enum strings,
canonical ordering, SHA-256 inputs and rejection of unknown fields/versions.
Swift decoders must match existing validation; synthesized Codable alone is not
proof. Preserve bytes where receipt equality, digests or legacy encoding require
them. No health/workout payloads in production logs or committed fixtures.

Initially use synthetic, Dart-created databases. Test Dart write → Swift read,
Swift correction/write → Dart read, version-1 upgrades, unknown-version refusal,
malformed payloads, duplicate retries, revision conflicts, interrupted actions,
rollback, profile isolation and delete retry without resurrection. Reopen from a
second process, not merely a second repository instance.

The side-by-side development app uses a distinct bundle ID and its own sandbox;
it cannot automatically read the installed Flutter app's container. Use isolated
fixtures for development. Before production replacement, verify the exact installed
identity, team/signing, container paths and a recoverable local backup. Stop writes
across stores while capturing a coherent backup and handle SQLite journals/WAL
correctly; do not copy only a live main database file. Retain sensitive backups
outside Git and inspect a restored copy before proceeding.

Rehearse an update using disposable signed apps/fixture data first. Production
cutover should preserve the original bundle identity and install without uninstall
only after this rehearsal passes. Verify all stores and preferences afterward.
If identity/path preservation cannot be established, stop cutover and design an
explicit verified local transfer. Never fall back to deleting data or starting fresh.

Keep a recoverable pre-cutover snapshot and the Flutter source/build recipe.
Reinstalling an old binary is not by itself a rollback plan: later native writes
must either remain readable by Flutter or be preserved through a tested transfer.
Avoid irreversible schema changes during parity. A rollback must not silently
discard workouts recorded after cutover.

## Ordered implementation phases

### 0. Freeze the reference and record decisions

Create an isolated `codex/swift-migration` checkout when implementation starts;
record the reference commit and screenshots. Rerun Dart formatting, analysis and
tests, recording existing failures separately. Resolve effective minimum iOS,
signing identity and compatible API choices; record the migration ADR, native
test conventions and full parity checklist. Do not change training behavior.

Exit: reproducible baseline, complete checklist and explicit support/signing plan.

### 1. Native foundation and storage proof

Create the Xcode project/local package and test targets; launch a signed shell on
the owner's iPhone. Port manual log/program models, codecs and the program-log
repository first. Prove schema-1/2 compatibility and correction/delete/retry/reopen
semantics on disposable databases. Validate number/date/hash conventions before
they spread into further ports.

Exit: Xcode build/device launch and cross-language storage checks pass; no real
workout store has been modified. Resolve compatibility failures before UI expansion.

### 2. First usable native workout

Implement the two-tab shell, program display and complete manual logging flow:
select → start → log → save → terminate/reopen → correct → finish/early finish →
open history. Include safe template switching, confirmed deletion, error recovery,
pending-write locks and exact stored prescriptions. Preserve timer semantics.

Exit: owner can log a complete fixture workout offline on the iPhone; interrupted
saves and retries neither lose nor duplicate records. This is the first usable
milestone, not permission to replace the production app yet.

### 3. Complete visible feature parity

Port history/graphs, settings, appearance, native haptics, training setup and gym
inventory, including their repositories. Retain unsaved fields and workout state
across tabs/disclosures. Port practice access to a developer-only entry point.
Inspect narrow layouts, large Dynamic Type, both themes, VoiceOver navigation,
keyboard entry, empty/error states and background/resume behavior.

Exit: every current user-facing workflow has a mapped passing check, with any
hands-on accessibility/haptic acceptance explicitly recorded rather than assumed.

### 4. Port the remaining adaptive backend without activating it

Port catalog validation/mapping, guarded eligibility, progression, warm-ups,
planning, generated history, composition and lifecycle/application services in
that dependency order. Use synthetic approved test bindings only in test targets.
Reuse frozen input/output fixtures from Dart; compare complete outputs including
reason codes, evidence IDs, ordering, quantities, versions and digests. Port
repository device tests and recovery probes.

Exit: all existing engine behavior has parity evidence, and real incomplete setup,
catalog and safety inputs remain blocked. No synthetic review records ship as
production approval.

The production atomic capture/compare-and-save adapter, unresolved safety/catalog
review, target confirmation and live generated-workout execution are separate
future features. Swift migration neither solves nor bypasses these gaps. Multiple
independent database reads are not an atomic cross-store capture.

### 5. Cutover rehearsal and physical acceptance

Run the full native suite and release build, rehearse app replacement and recovery
with disposable data, then perform a protected real-data cutover when authorized.
Inspect saved counts, IDs, prescription versions, corrections, deletion tombstones,
setup and gym preferences. Test offline use, cold launch, backgrounding, resumed
drafts and durable corrections on the physical phone. Keep tests on fixture stores.

Exit: installed native app and historical data verified; rollback procedure tested;
no unresolved data-loss, duplication, regression or unexplained build warning.
Broader OS/device coverage is explicitly separate from one-phone validation.

### 6. Retire Flutter from the maintained app

After parity and acceptance, remove Flutter runtime/build dependencies and obsolete
Dart tooling from the active tree, retaining the reference in Git history. Update
README, architecture, testing instructions and AGENTS.md for native commands, and
resolve Flutter-specific wording in relevant specifications without altering their
approved product rules. Preserve provenance, fixtures and license notices.

Exit: a fresh checkout opens, builds and tests in Xcode without Flutter installed;
all maintained application code is Swift; the parity checklist has no unexplained
omissions. Retaining Flutter as a temporary reference is not the final state.

## Verification and reporting

- Before implementation baseline: `dart format --output=none --set-exit-if-changed .`,
  `flutter analyze`, `flutter test`; repeat if Flutter reference code changes.
- Native package: `swift test --package-path native/Packages/WorkoutCore`.
- App: shared Xcode build/test schemes and `xcodebuild` with explicitly discovered
  destinations; signed release installation and launch on the physical iPhone.
- UI/device tests use isolated stores and a test identity. Package tests on a Mac
  do not substitute for iPhone SQLite, lifecycle or UI tests.
- Lock native formatting/check commands after inspecting the installed toolchain;
  do not add a formatter dependency by default.
- Record commands, results, fixture scope, device/OS, visual inspection and
  unverified items for each phase. Never count a compile as a passed device test.
- Review every final diff for unrelated edits, embedded secrets, sensitive logs,
  weakened validation and accidental new product behavior.

No implementation or test execution is claimed by this planning document. Only
source inspection and local Xcode/Swift version checks were performed for it.

## Effort and checkpoints

This is a substantial port, not a one-session conversion. Do not commit to a
calendar deadline from line counts. Estimate remaining effort after phase 1 using
actual codec/repository porting and test results, then revise after phase 2 based
on native UI/device work. The critical path is compatibility → durable logging →
feature/engine parity → protected cutover. Complete one bounded slice per change.

## References

- Repository authority: [Architecture](ARCHITECTURE.md), [Product](PRODUCT.md),
  [Testing](TESTING.md), [Interface](UI_DESIGN.md), [day-one contracts](programs/DAY_ONE_CONTRACTS_2026_09_23.md)
  and the referenced [decision records](decisions/README.md).
- [Apple: organizing code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
  supports the proposed native package organization.
- [SQLite backup API](https://www.sqlite.org/backup.html) documents consistent
  SQLite backup mechanics; a multi-store app still needs its own coherent capture.
