# Architecture

Status: native Swift/SwiftUI architecture for the owner-authorized iOS-first migration. Product/science decisions and existing safety gates remain unchanged. Native verification and data-cutover status are tracked in [Migration evidence](SWIFT_MIGRATION_STATUS.md); this document does not claim final acceptance.

## System boundary

The maintained application is an offline-first SwiftUI iOS app, targeting iOS 17 and later. Open `native/AdaptiveWorkout.xcodeproj` in Xcode. Pure Swift rules, logging, history and storage live in the local `native/Packages/WorkoutCore` package. Core operation requires neither a Flutter runtime nor an account, network service or cloud backend. Android is deferred until the iOS app proves useful.

The application exposes approved manual logging and descriptive history. The adaptive engine remains a standalone backend: its presence does not enable real recommendations or bypass pending catalog, safety, equipment, baseline or cross-store orchestration work. See [ADR 0018](decisions/0018-native-swift-migration.md). Historical ADRs preserve the original decisions and validation evidence; references there to Dart, Flutter and previous test counts describe the earlier implementation.

## Presentation and appearance

`AdaptiveWorkoutApp` composes `HomeView`, `ProgramLogController` and local repositories. `SettingsView`, `SetupView`, `HistoryView` and `SetEditor` use native SwiftUI controls, semantic colors and system typography. Views delegate mutations to application/presentation controllers and never calculate training rules or execute SQL. See [Interface design](UI_DESIGN.md).

`AppModel` loads and applies System/Light/Dark through SwiftUI's preferred color scheme. System is the default. `SqliteAppearanceRepository` keeps the validated preference in the separate schema-1 `appearance.sqlite` store; selection is acknowledged after save/readback. Appearance does not read or mutate training records.

`AppModel.cue` provides presentation-only UIKit selection, light impact and notification feedback. Explicit interactions and acknowledged results request semantic cues; an enabled UserDefaults preference and active application state guard playback. The existing `adaptiveWorkout.hapticsEnabled` key is retained. Domain policies and workout repositories have no haptic dependency, and unavailable feedback never blocks a workout action. The privacy manifest declares app-only UserDefaults access.

## Intended dependency direction

```text
Presentation -> Application -> Domain
                    |
                    v
              Repository interfaces
                    ^
                    |
             Data implementations
```

`WorkoutDomain` uses Foundation/CoreFoundation for value types and strict codecs, plus CryptoKit for deterministic SHA-256 integrity. It must not depend on SwiftUI, UIKit, Combine, databases, networking, analytics or subscription SDKs. Views and observable controllers stay on the main actor. Repository adapters serialize database operations; deterministic policies accept explicit inputs rather than consulting runtime state.

## Domain scope

- Versioned exercise catalog with license and provenance metadata
- Exercise eligibility and ranking
- Workout composition
- Progression
- Volume accounting
- Readiness and fatigue
- Load calculation
- Workout-time optimization
- Workout logging and history
- Recommendation explanations

Implemented areas include catalog validation/integrity, guarded eligibility, progression, warm-ups, planning, composition, logging/history, and recommendation snapshots/lifecycle. The list above is the product architecture scope, not a claim that ranking, volume, fatigue or time optimization have independently approved implementations.

## Native layout

```text
native/
  AdaptiveWorkout.xcodeproj
  AdaptiveWorkout/                  SwiftUI app, composition, native feedback, assets
  AdaptiveWorkoutUITests/           Native interaction tests
  Packages/WorkoutCore/
    Sources/WorkoutDomain/          Pure rules, immutable records, codecs and contracts
    Sources/WorkoutApplication/     Controllers, generation/lifecycle services, timing
    Sources/WorkoutPersistence/     SQLite adapters and pinned source import/projection
    Sources/CSQLite/                Apple's system SQLite module bridge
    Tests/WorkoutCoreTests/         Rules, controllers, persistence and parity fixtures
```

The package contains application-owned code; it does not download a third-party library. The app uses Apple's bundled SQLite through `SQLiteDatabase`. This is a language/runtime migration with preserved store contracts, not a switch to SwiftData.

## Storage and compatibility

Each store remains separate: `program_logging.sqlite` (SQL schema 2), `training_setup.sqlite`, `recommendations.sqlite`, `adaptive_workout.sqlite` (practice), `gym_profiles.sqlite` and `appearance.sqlite` (SQL schema 1). SQL versions and JSON payload versions are separate concerns. Adapters use bound SQL values and transactions, preserve prior payloads/action receipts where specified, reject unsupported schemas and never clear a store to recover from a read failure.

`ManualJSON` reproduces ordered Dart JSON encoding and exact UTF-8 receipt comparison. `ManualTimestamp` preserves integer microseconds with proleptic Gregorian conversion; `Date` is a presentation/interoperation view, not the authority for legacy bytes. Pounds remain integer millionths. Legacy optional-field omission, frozen program versions and audit identities survive decoding and correction.

Stores live in the app's Documents directory, matching the former iOS SQLite location within a given sandbox. The development native bundle has a separate sandbox, so equivalent paths do not automatically transfer the installed Flutter app's data. A protected production transfer/replacement and rollback proof remain separate from source migration. `StorageLaunchContext` confines Debug test/reset options and hosted tests to isolated fixture directories and preference domains. Production data must never be cleared by test setup.

## Data flow

This is the recommendation-service pipeline. The live manual logger invokes logging/history actions and does not register production generation.

1. The UI submits explicit goals, constraints, workout results, or exception feedback.
2. An application controller validates and coordinates the action.
3. Repository interfaces provide the versioned exercise catalog and local training history.
4. Domain services filter eligible exercises, rank candidates, compose the workout, and calculate its prescriptions.
5. The domain returns the recommendation together with stable explanation codes and the versions of rules and catalog used.
6. Repository interfaces persist the recommendation and subsequent results.
7. The UI renders immutable application state.

## Deterministic recommendation boundary

The engine must accept all decision-relevant state as explicit input. It must not depend on view state, wall-clock time, network responses, unseeded randomness, iteration order, or hidden mutable state.

A recommendation result should contain:

- Selected exercises and order
- Sets, repetition range, target effort, load, and rest where applicable
- Any substitutions or omitted targets
- Explanation codes and user-readable explanation parameters
- Rule-set version and exercise-catalog version
- Explicit constrained or no-recommendation status when necessary

The user interface may request a replacement by submitting a new constraint or supported exception. It must not contain its own replacement or workout-selection logic.

## Exercise content boundary

The catalog repository loads a reviewed, version-pinned wger exercise-data snapshot bundled for offline use. The application does not call wger while generating or presenting a workout and does not incorporate wger application code. Imported content remains in a separately identifiable data package under each record's applicable license, with attribution and modification history preserved. Images and videos are excluded from V1.

The domain consumes only validated internal catalog entities, never raw upstream records. Ingestion treats all upstream text and metadata as untrusted, converts permitted content to the approved plain-text and enum representation, rejects malformed or unsupported values, and produces a reproducible snapshot manifest and integrity digest. Instructions and any future media are presentation content and must not become hidden sources of domain behavior.

Catalog version `2026.09.08.1` is the first real source-backed slice and contains only the three approved benchmark identities. Its typed projection, pinned mapper fixture and integrity checks remain offline; current native test evidence is recorded separately. All entries remain disabled, and no application composition code loads the slice, until the pending review gates in `docs/catalog/BENCHMARK_CATALOG_2026_09_08.md` are complete.

The minimal internal entity and snapshot contract is defined in `EXERCISE_CATALOG.md`, its controlled IDs and bounds are defined in `EXERCISE_TAXONOMIES.md`, and the upstream mapping boundary is defined in `WGER_MAPPING.md`. The approved structural hard-filter and separate safety-gate boundary is defined in `EXERCISE_ELIGIBILITY.md`; exercise-specific mappings and clinical or training-science behavior remain gated by that document. Source DTOs, mapping-review records, import code, storage records, domain entities, and presentation models remain separate representations. Only the domain entity may cross into exercise selection.

The application-facing structural eligibility entry point is `ExerciseEligibilityEvaluator`. It receives the trusted, preconfigured catalog validator from the application composition boundary, revalidates the complete catalog and request envelope, recomputes the canonical constraint digest, invokes the private safety gate, and only then invokes the private eligibility filter. The filter receives an eligibility-only immutable projection, preventing presentation, provenance, muscle, benchmark, and relationship fields from becoming hidden inputs. Lower-level gate and filter types are library-private so callers cannot bypass validation. Synthetic fixtures exercise this boundary; it is not registered as a live recommendation flow. Native test results belong in the migration evidence log.

## Week-one progression boundary

`LoadProgressionPolicy` implements the approved two-exposure external-load adjustment and bodyweight/assistance hold policy with explicit immutable inputs. It returns a candidate load, reason code, rule version and evidence IDs; it is not a complete workout recommendation. It is not connected to the live manual logger as an automatic load selector. Future application orchestration must map a freshly evaluated safety/eligibility result into its explicit gate and supply verified baseline/equipment and complete history. Missing or blocked gates return no candidate load. See [ADR 0007](decisions/0007-approved-week-one-progression.md) for exact load representation and history requirements.

## Deferred decisions

- Future package splits beyond the current domain/application/persistence boundaries
- New storage formats or schema migrations beyond the preserved contracts
- Production atomic cross-store capture and generated-workout orchestration
- Backup/export format
- Analytics and crash-reporting policy
- Subscription entitlement behavior
- Exact exercise-catalog import and update tooling
- Exercise-to-taxonomy mappings and review evidence
- Exercise-eligibility mappings, clinical review, and verified equipment inputs
- Initial exercise-scoring factors and deterministic tie-breakers

Each material decision should be recorded in `docs/decisions/` before implementation.

## Warm-up target boundary

`WarmupPolicy` calculates approved rehearsal-set targets from a matching verified baseline, explicit current gate and available settings. Its historical v1 entry point keeps missing/infeasible or bodyweight/assisted inputs blocked. Approved v2 bodyweight targets now use `BodyweightWarmupPolicy`, with separate assistance and verified range references. `externalWarmupV2` preserves the v1 external calculation; `evaluateWarmupContinuation` checks explicit feedback, rest, interruption and current gate without reading a clock. These policies are now consumed by the standalone session composer; live execution/UI integration remains pending. See [ADR 0011](decisions/0011-approved-warmup-v2.md). It does not control live exercise execution. The session composer applies the five-minute walking requirement once. See [ADR 0008](decisions/0008-approved-warmup-policy.md).


## Durable practice logging

Debug builds can explicitly expose developer practice with the `--practice` launch argument. `PracticeSettingsModel` calls the pure `PracticeRepository` contract implemented by `SqlitePracticeRepository`, retaining the existing `local_owner` context in the separate practice store. The UI acknowledges success after commit and validated reload, retains pending intent for retry, and blocks competing changes. Corrections preserve prior payloads while current history reads each set once. Practice never contributes recommendation evidence. SQLite schema-1 semantics and the historical implementation decision remain in [ADR 0009](decisions/0009-local-workout-storage.md).

## Approved program preview

`OwnerProgram.swift` contains the constant, versioned transcription of the owner-approved prescriptions, with ordered blocks, paired supersets, P1 effort targets, P3 rests and P7 alternative preferences. These template IDs are not catalog identities and do not bypass catalog eligibility, setup verification or baseline checks. `SettingsView` renders the templates read-only. No real-session database writes, automatic scheduling, load selection or optional finisher execution are enabled by this preview.

## Manual program logging

`ProgramLog` validates actual records and completion separately from constant prescriptions; it explicitly reports `recommendationEligible=false`. `ProgramLogController` owns pending actions and retry identity, and `SqliteProgramLogRepository` owns transactional persistence in a separate database. The program screen offers manual logging and history. Each stored session has a prescription snapshot; reads reject a mismatch with the pinned program version. No catalog entries are enabled and no manual actual automatically becomes a verified baseline. See ADR 0009 for the bounded storage extension.

## User-controlled calendar planning

### Local setup preparation

`SetupView` and its presentation adapter delegate preferences, equipment drafts and explicit starting-load confirmations to `TrainingSetupController`, through the pure `TrainingSetupRepository` protocol. `SqliteTrainingSetupRepository` stores versioned aggregates and atomic action receipts in a separate local database. Equipment revision changes make prior starting loads stale. Preparation variation keys are not approved catalog identities; these records do not enable recommendations. See [ADR 0012](decisions/0012-verified-training-setup-storage.md). The owner selected Monday–Friday and 60 minutes and will verify equipment gradually; these are owner preferences, not global defaults.

`SessionPlanningPolicy` independently maps an explicit ordered program, user-selected weekdays, scoped occurrence history and requested civil date to a next slot/date or resumable draft. Completed and explicitly ended-early occurrences advance; missed days do not. It does not determine exercise eligibility, recovery or load. `compareSessionDuration` reports an advisory comparison to a positive user preference, without enforcing a 45–60-minute limit or estimating durations. Both are standalone pure policies, not yet wired to storage or the app. [Day-one contracts](programs/DAY_ONE_CONTRACTS_2026_09_23.md) define the forthcoming immutable records, target-confirmation boundary and catalog review packet.

## Recommendation-linked storage and progression history

`RecommendationSnapshot` owns schema-1 self-contained ordered targets and immutable version/input/evidence references. Historical reads use that snapshot, never the current `ownerProgram` constant. `GeneratedOccurrence` validates actuals against exact saved targets and permits one audited set mutation or terminal transition at a time. `GeneratedHistory` validates a complete profile envelope and provides progression exposures without dropping incomplete or incomparable occurrences. Stable program IDs scope history across program versions; version changes break comparability.

`SqliteRecommendationHistoryRepository` implements the pure repository interface in a separate `recommendations.sqlite` store. Each mutation commits current state, prior revision, history revision and action receipt atomically. Reads validate relational identities, complete sequence and the audit chain. An older history revision invalidates unstarted recommendations while preserving active/historical prescriptions. Practice/manual data are never read by this adapter. The standalone composer consumes generated history and produces these snapshots; no live app caller is registered yet. Storage does not approve a catalog or clear safety gates. Fresh cross-store input capture and eligibility checks belong to upcoming orchestration. See [ADR 0013](decisions/0013-recommendation-history-storage.md).


## Deterministic session composition

`SessionComposer` calls the guarded evaluator, selects approved bound alternatives, consumes complete generated history and invokes progression and warm-up policies. It preserves ordered work, paired rounds and rest, adds walking once, and keeps proposed loads separate from confirmed targets. Recommendation payload schema 2 records rehearsal-specific identities, absent numeric rehearsal RIR, binding/rule references, per-slot reasons and proposed loads. Schema-1 historical encoding remains unchanged.

`SessionGenerationService` depends on an atomic capture/compare-and-save source interface. No production implementation is registered: independent setup/history stores and missing durable safety/rehearsal inputs do not yet provide the required consistency boundary. All five templates have synthetic composition fixtures; real catalog activation and the full Day 4 exit remain pending. See [ADR 0014](decisions/0014-session-composition.md).


## Owner program revision 2

The owner approved three shoulder-press working sets on September 24. Current previews/new manual sessions use `owner-program-v2`; manual logs retain their stored program version, resolve its frozen prescription and cannot change versions during correction. Legacy setup snapshots round-trip their original version. The set-entry dialog validates against the selected log rather than the latest template. Generated plans use `owner-generated-v3`; progression rule thresholds are unchanged. No historical payload rewrite or SQL migration is performed.


## Reported setup and persisted rehearsals

Training-setup payload schema 2 adds append-only reported work and rehearsal attestations to the existing transactional aggregate, retaining schema-1 compatibility. Reports cannot become baselines or progression evidence. The controller preserves evidence during later edits; the composer consumes saved complete rehearsal attestations only after exact current equipment and reviewed catalog matching. Draft/unknown/stale data remain blocked; adverse reports cannot be silently cleared. See [ADR 0015](decisions/0015-reported-setup-and-rehearsal-storage.md). A production cross-store generation adapter and live intake UI remain pending.

## Saved-workout lifecycle

`SavedWorkoutService` reloads generated occurrences with their immutable saved
prescriptions, prepares auditable set/terminal actions, and acknowledges them only
after repository commit and validated reload. Program queue position is derived
from committed terminal occurrences; explicit early finish advances once while
interruption remains resumable. Calendar lookup requires explicit local-date
conversion and schedules after the last terminal date. This backend service does
not authorize exercise execution or connect the live UI. See [ADR 0016](decisions/0016-saved-workout-lifecycle.md).

### Choosing today's manual workout

The manual log exposes an explicit picker for any of the five approved templates,
independent of today's weekday. Choosing the current draft resumes it. Choosing a
different template asks to finish the draft early, preserving recorded sets; only
a confirmed successful finish permits starting the selected template. These are
two durable actions: if starting fails, the finished workout remains in history
and the pending start can be retried. Opening/canceling the picker never writes.

Manual logs optionally store `endedEarly: true` alongside the terminal timestamp.
Older payloads omit the field and retain their encoding. Early completion permits
unrecorded targets, keeps corrections limited to existing records, and remains
ineligible for progression. Repository transition validation preserves the flag
and prevents changing the prescription. The SQL schema and one-draft index are
unchanged. This manual picker does not reset the adaptive program queue.

### Individual manual workout deletion

`ProgramLogController` coordinates confirmed deletion through its repository,
retaining retry identity until a validated reload confirms absence. Manual SQLite
schema 2 removes workout payloads, revisions and associated receipts atomically;
minimal deletion identifiers prevent stale save retries from resurrecting a log.
Schema-1 upgrades preserve existing payloads. See [ADR 0017](decisions/0017-delete-manual-workout.md).

## Primary app entry

The normal app entry is `AdaptiveWorkoutApp` with `HomeView`, a persistent two-tab shell: Workout
and Settings. Workout contains the manual logger and inline searchable history
and graphs; opening a saved record selects it in the same logger. Settings has
lazily created, state-preserving disclosures for appearance and haptics, program,
training setup and gym inventory. Embedded content does not push extra screens;
small editing/confirmation dialogs remain local to the two destinations. Switching
tabs retains workout state and unfinished settings fields. Practice screens remain
available through explicit development/test injection only; their repositories
and saved data are preserved. Hiding practice does not delete it.

### Manual session timing

The presentation-only timer controls in `HomeView` derive total elapsed time from existing
saved start/completion timestamps. `RestCountdown` stores an in-memory deadline
selected explicitly from the displayed prescription block. UI refresh ticks do
not accumulate time or mutate workout data; resume recomputes from timestamps.
The countdown is cleared on workout selection changes/completion and page disposal.
Switching tabs retains its deadline; hidden/background views do not tick or emit
completion feedback. Returning updates the display without a catch-up haptic.
Neither timer participates in deterministic training rules. See UI_DESIGN.md
for background, restart and notification limitations.

## Gym location inventories

Settings contains local gym profiles with explicit equipment availability,
per-location corrections and offline selection persistence. The pure gym domain
is separate from exact training setups and does not authorize recommendations.
`GymSettingsModel` validates exact save acknowledgements and exposes explicit conflict reload; the separate schema-1
`gym_profiles.sqlite` adapter uses transactional compare-and-save. Homewood has
location metadata only, with all equipment initially unknown. See
[Gym profiles](GYM_PROFILES.md) for provenance, boundaries and validation.

### Manual history presentation

`HistoryView` loads profile-scoped manual logs through `ProgramLogController` and
`ProgramLogRepository`. Pure Swift projections in `History.swift` filter finished
logs and partition comparable recorded sets. SwiftUI renders descriptive graphs
with an accessible exact-value disclosure; no additional dependency or schema is
introduced. Opening a source workout selects it in the existing logger. Returning
to history refreshes its repository view while retaining filters. Drafts/practice
remain excluded, and recommendation evidence adapters are unaffected.

## Verification boundary

Run the native format/build/package checks listed in `AGENTS.md` and record exact
results in [Migration evidence](SWIFT_MIGRATION_STATUS.md). Xcode exposes the app,
hosted core-test and UI-test targets. Build success, package-test success, native
interaction checks and protected installed-data cutover are distinct claims. The
owner deferred further physical-device checking at this migration checkpoint;
remaining device behavior and accessibility acceptance must stay explicitly
unverified. The Flutter reference is retained in Git history, not as a required
runtime for the maintained app.

Independent appearance-store failures are reported with a retry while workout storage remains usable. Pending manual actions expose their submitted values separately from committed records until exact reload acknowledgement succeeds.

## September 25 manual workflow and reference content

`ManualWorkoutFlow` shares load-option semantics with the manual validator and
orders explicit working targets by block, round, exercise and side. Views render
the first unrecorded target; copying earlier actuals only prefills an unsaved form.
Manual setup labels may now be empty under owner authorization. This does not
relax verified setup or generated-recommendation contracts. Unknown manual setup
is session-scoped in descriptive chart groups. Canonical legacy payloads remain
unchanged. `ProgramLogController` deselects only newly acknowledged completions,
including retries, retaining completed-history correction behavior.

`WorkoutNotifications` owns native notification effects on the main actor and
saves independent local preferences. `WorkoutReminderSchedule` validates explicit
calendar inputs outside views. Core logging never requires notification permission.
No notification contains actual exercise/health measurements; test fixtures disable
system notification mutations. Local alerts remain subject to iOS delivery policy.

`WgerReferenceRepository` verifies a separately bundled, pinned presentation-only
name/attribution index. It does not expose `ExerciseCatalog` or supply exercise
selection, training rules or program bindings. The broader source index does not
replace the reviewed-catalog pipeline or activate any pending review gate.
