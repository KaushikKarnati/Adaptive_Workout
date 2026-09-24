# Native Swift behavior and reference map

Migration generator checkpoint: `b1da05d` (both implementations and generator scripts).

Reference Flutter commit: `c28d22f50dca8eced393e749d0142b0877b4ba0f`.
The maintained app is `native/AdaptiveWorkout.xcodeproj` (scheme
**AdaptiveWorkout**, iOS 17+). Flutter/Dart source and tests at the reference
commit remain historical comparison material; they are not required to build or
test the native app. Android is deferred until the iOS app proves useful.

This maps behavior groups and the assertions present in the native suites. It is
not an execution report or a claim of identical widget trees/test counts. Record
actual commands, results and limitations in [the migration status](SWIFT_MIGRATION_STATUS.md).
The owner asked to skip further physical-device checking at this checkpoint;
no skipped check is counted as a pass. See [the native workflow](TESTING.md).

All native core tests live in `native/Packages/WorkoutCore/Tests/WorkoutCoreTests`.
The same source files are built into the hosted **AdaptiveWorkoutTests** iPhone
target. Interaction tests live in `native/AdaptiveWorkoutUITests`.

| Reference behavior/tests | Native implementation | Native coverage / verification boundary |
| --- | --- | --- |
| owner_program_test | OwnerProgram | ManualLoggingTests; all 10 frozen v1/v2 prescription bytes from Dart |
| program_log_test | ManualLogging, ManualJSON | ManualLoggingTests, including invalid inputs, pain, side identity, skips, corrections, completion, Unicode identity and exact timestamps |
| program_log_controller_test | ProgramLogController | ControllerTests; uncertain committed writes, competing-action lock, exact-payload acknowledgement, retry and deletion |
| program_log_repository_test | ProgramLogRepository | ManualRepositoryTests; Dart payload/receipt reads, native writes, v1 upgrade/v2 tombstones, audit, rollback, profile separation, one draft, conflicts and future schema refusal |
| practice_record/controller/repository/restart tests | Practice, PracticeRepository, Debug-only practice entry | SettingsParityTests/SettingsRepositoryTests; fixture-only native developer UI; shared SQLite rollback/reopen checks |
| workout_history_test | History | ManualLoggingTests; comparable groups, exclusions, query/date/profile filters and historical program versions |
| program_logging_page/program_page/home/widget tests | HomeView, SetEditor, SettingsView | WorkoutFlowTests covers start, enter, save, tabs, independent process restart, correction, early finish, graph and confirmed delete; execution status is tracked separately |
| history page navigation and graph controls | WorkoutView-owned filters, HistoryView | HistoryNavigationTests covers retained search/date filters after opening a source workout, load/reps defaults and retained per-series metric; graphs also expose exact-value source links |
| session_timer_test | SessionTiming, WorkoutView presentation state | StorageTimingTests; explicit time, clamp, rounding, restart/cancel semantics; timers never enter training rules |
| appearance_test | AppearanceRepository, AppModel | AppearanceTests; WorkoutFlowTests appearance override and saved preference reopen; visual acceptance remains separate |
| haptics/gym_haptics tests | AppModel native UIKit cues and injected semantic callbacks | Source inspection retains active-application and enabled-preference guards; SwiftUI actions request semantic cues; foreground suppression, perceived feedback and comfort require hands-on acceptance |
| settings/two_screen_visual/history_visual tests | Native two-tab SwiftUI shell and Canvas graph | Native control semantics replace Flutter-specific golden/layout assertions; UI tests retain screenshot attachments, while Larger Text, VoiceOver, Voice Control and visual acceptance remain separate |
| training_setup/setup_intake tests | TrainingSetup, TrainingIntake, TrainingCodec | SettingsParityTests; schema 1/2 and legacy program bytes, unknown/stale equipment, confirmed baselines and retained reports/rehearsals |
| training_setup_controller/page/repository tests | TrainingSetupController, SetupView, TrainingSetupRepository | SettingsControllerTests/SettingsRepositoryTests; uncertain result retry, receipt conflict, profile isolation, audit, append-only intake; WorkoutFlowTests contains the unsaved-field/tab/save/restart flow |
| gym_profile/domain/controller/page/repository tests | GymProfiles, GymProfileRepository, GymSettingsView | SettingsParityTests/SettingsRepositoryTests; default unknown equipment, valid text/taxonomy, compare-and-save, retries, correction and selection |
| load_progression_policy_test | EngineProgression | EnginePolicyTests; gates, missing/invalid inputs, exact bounds, evidence streaks, unilateral and scoped history |
| warmup_policy/v2 tests | EngineWarmup | EnginePolicyTests; external ladders, bodyweight/assistance, verified rehearsals, continuation and stopped/incomplete inputs |
| session_planning_policy_test | EnginePlanning | EnginePolicyTests; explicit civil dates, ordered occurrences, active/terminal behavior, duration advice and historical Gregorian boundaries |
| exercise_catalog_validator/manifest tests | EngineCatalog, EngineCatalogValidator, EngineIntegrity | EngineCatalogTests; metadata, review/licenses, bounds, canonical digest, safe source host/path and exact disabled benchmark digest |
| exercise_eligibility_evaluator_test | EngineEligibility | EngineCatalogTests; safety precedence, malformed envelopes, restrictions, incomplete/unknown input, eligibility filtering and integrity |
| wger_source_mapper/benchmark_catalog_slice tests | WgerSourceMapper, EngineBenchmarkCatalog | WgerSourceMapperTests; pinned source identity, unknown HTML rejection, deterministic source mapping, licenses, missing/duplicate/oversized input; benchmark remains disabled |
| recommendation_history_test | RecommendationHistory | RecommendationHistoryTests; snapshot schemas, target identity, exact bytes, sticky pain, incomparable/missing evidence and immutable historical prescriptions |
| recommendation_history_repository_test | RecommendationHistoryRepository | RecommendationRepositoryTests; full audit chain, profile/history revisions, stale proposals, immutable receipts, rollback, future-schema refusal and native reopen |
| session_composer_test | EngineComposer | EngineComposerTests; exact complete snapshot bytes for all five Dart templates, reversed inputs, paired order/rests, unchanged confirmed targets, load proposals and blocked alternatives |
| persisted_rehearsal_test | EngineComposer + TrainingIntake | EnginePersistedRehearsalTests; persisted complete/incomplete/stale/reported/adverse records and overridden injections |
| session_generation_service_test | EngineSessionGeneration | EngineComposerTests; capture/save contract, failed save propagation and same-action retry; no production source is registered |
| saved_workout_service and device tests | SavedWorkoutService | SavedWorkoutServiceTests + RecommendationRepositoryTests; immutable prepared actions, commit/retry/reload, early completion, resumption and calendar queue |
| Dart program_storage_probe/storage_recovery_probe | Native repository tests and WorkoutFlowTests | Transaction failure injection, close/reopen, and a native terminate/relaunch scenario replace obsolete Dart probe entry points; test presence does not establish a final installed-app pass or physical power-loss recovery |

## Preserved reference evidence

Frozen fixtures are checked in under
`native/Packages/WorkoutCore/Tests/WorkoutCoreTests`; native tests consume them
directly and do not regenerate their expected output from the Swift code under
test.

| Retained artifact | Purpose |
| --- | --- |
| `ManualGoldenFixtures.swift` | All ten frozen v1/v2 prescriptions, manual payloads and receipts, including Unicode and exact microseconds |
| `SettingsGoldenFixtures.swift` | Legacy setup/practice/gym encodings, schema versions, evidence and receipts |
| `RecommendationGoldenFixtures.swift` | Saved recommendation/occurrence and receipt compatibility |
| `EngineComposerGoldens.swift` + `EngineComposerFixture.swift` | Exact complete Dart-generated snapshots for all five approved templates and their synthetic explicit inputs |
| `WgerGoldenFixtures.swift` | Self-contained mapper test inputs for the pinned synthetic and benchmark snapshots |
| `native/ReferenceFixtures/wger/pinned_snapshot.json` and `benchmark_snapshot_2026_09_08.json` | Inspectable raw pinned source fixtures retained when the Dart test tree is removed |
| [Benchmark catalog provenance](catalog/BENCHMARK_CATALOG_2026_09_08.md) | Source IDs/URLs, both attribution records, modifications, snapshot digest and unresolved reviews |
| [Flexify license notice](references/FLEXIFY_LICENSE.md) | Preserved reference notice and attribution history |
| `native/AdaptiveWorkout/PrivacyInfo.xcprivacy` and `Assets.xcassets` | Native privacy declaration and app assets retained independently of the retired Flutter iOS wrapper |

The recorded SHA-256 of the raw benchmark fixture is
`ddd51de5e62e43fb768085840173b77c6f392ba28459d02a4a5f481fd8aa5721`;
the reviewed-entry canonical digest is
`4bda4d4b43bba409c66585acb76d88c871cda97d9b13ca0fe732595488578eb4`.
These identify different payloads. The three source-backed benchmark entries
remain disabled. Their presence in a test or typed projection does not grant
product, science, safety, equipment or licensing approval.

The retired sample-workout mock and Flutter Material/widget plumbing are not
additional native product screens. Old Dart generator/probe commands are no
longer the maintained workflow. The frozen Swift data, retained raw snapshots,
product specifications and reference commit provide the comparison evidence.
An intentional fixture change must cite an approved behavior change or a
separately reproduced source result; passing regenerated expectations is not
proof of parity.

## Remaining product and acceptance gates

- Live adaptive recommendation UI and the production atomic cross-store
  capture/compare-and-save adapter remain absent, as in the reference. The
  standalone services do not connect manual/practice records to progression.
- Current catalog review, durable safety inputs, exact equipment verification,
  confirmed baselines and live reported/rehearsal intake remain gated. Unknown,
  stale, incomplete or adverse data must continue to block the affected path.
- The owner chose a fresh native install with a distinct bundle identity. Store
  compatibility tests do not transfer another app's sandbox. A future migration
  of retained real user data requires separate backup/restore and replacement
  acceptance; it is not part of this fresh-start claim.
- Final physical visual/accessibility, timer/haptic experience, background and
  installed-app acceptance remain unverified wherever the evidence log has no
  completed result. Package tests and unsigned builds do not replace them.
- The three-month private outcome period, clinical wording review, supported-iOS
  coverage and broader release readiness remain product gates. HealthKit, cloud
  sync, Android, clinical clearance, and unapproved ranking/fatigue/volume rules
  are not delivered by a language migration.
