# Native testing strategy

The maintained app is Swift/SwiftUI, opened through
`native/AdaptiveWorkout.xcodeproj` with the **AdaptiveWorkout** scheme. The local
package is `native/Packages/WorkoutCore`; no Flutter or Dart installation is
required. [The behavior map](SWIFT_PARITY_MATRIX.md) identifies the native
counterpart of each reference behavior. [Migration evidence](SWIFT_MIGRATION_STATUS.md)
records actual commands, results and limitations; a test listed here is not a
claim that it passed.

The owner asked to skip further physical-device checking at the migration
checkpoint. Use local native checks for the current work and leave skipped
installed-app checks explicitly unverified. The owner chose a fresh start with
the distinct native app identity; storage compatibility does not automatically
transfer data from the deleted Flutter test app or another sandbox.

## Native quality workflow

Run from the repository root with the selected Xcode toolchain:

```sh
xcrun swift-format lint --strict --recursive native/AdaptiveWorkout native/AdaptiveWorkoutUITests native/Packages/WorkoutCore/Sources native/Packages/WorkoutCore/Tests native/Packages/WorkoutCore/Package.swift
swift build --build-tests --package-path native/Packages/WorkoutCore
swift test --package-path native/Packages/WorkoutCore
xcodebuild -project native/AdaptiveWorkout.xcodeproj -scheme AdaptiveWorkout -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Package tests execute on the Mac. The generic iOS build checks the native app
against its iOS deployment target without installing or launching it. To compile
the hosted core and interaction test targets as well, use:

```sh
xcodebuild -project native/AdaptiveWorkout.xcodeproj -scheme AdaptiveWorkout -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build-for-testing
```

The package has no downloaded third-party dependencies. Report unavailable
commands, failures and meaningful warnings accurately. Record the tested
revision/working-tree state and Xcode/Swift versions; rerun affected checks after
fixes. Never call a build a test pass, use an older run as proof of later edits,
or treat failure-injection rollback as physical power-loss recovery.

## Test layers and locations

- `native/Packages/WorkoutCore/Tests/WorkoutCoreTests`: pure domain rules,
  numerical boundaries, canonical fixtures, application controllers, SQLite
  migrations, transactional rollback and close/reopen recovery.
- **AdaptiveWorkoutTests**: the same core test sources hosted by the native iOS
  app. This target supports later explicit on-device verification.
- `native/AdaptiveWorkoutUITests`: **WorkoutFlowTests** covers manual
  start/save/correction, tab state, process restart, early finish, history/graphs,
  deletion, appearance and saved/unsaved setup. **HistoryNavigationTests** covers
  retained history search/date filters and per-series graph metric after opening
  a saved workout. Tests retain screenshots as result attachments.
- Deterministic simulations remain separate from production rules. A native
  implementation or synthetic fixture does not count as the three-month outcome
  study or approval of real prescriptions.

Additional native coverage added during the September 25 full test:

- `SetEntryCoverageTests`: supported load conventions, bodyweight/assistance,
  repeat-prefill, exact decimals and rejected/corrected form inputs.
- `LifecycleCoverageTests`: rest retention, cancel-then-confirm workout switching,
  deletion cancellation, and custom gym persistence.
- `VisualLayoutTests`: dark appearance and scrollable logging, also executed on
  an isolated smaller simulator with accessibility-large text.
- `NativeNotificationTests`: hosted-iOS-only tests of permission outcomes,
  scheduling failures/retries, cancellation races, persistence and fixture
  isolation using an injected notification client. These tests do not deliver
  alerts and are conditionally excluded from the Mac package runner.

The full-test findings and exact run boundaries are in
[September 25 test report](TEST_REPORT_2026_09_25.md). A passing mock notification
test does not establish locked-phone delivery. A passing large-text save flow
does not establish full accessibility acceptance.

Every algorithmic rule needs normal, boundary, invalid and missing-data cases;
every bug fix needs a regression case. Unit tests establish contracts, while
interaction tests establish the exercised UI behavior. Screenshot presence alone
does not establish visual or accessibility acceptance.

## Storage and fixture isolation

Repositories use temporary databases in core tests. **StorageTimingTests** covers
fixture-path validation and separation of both databases and preferences. Native
UI tests use a unique `--fixture-directory NAME`; `--reset-fixture` is used only
for that fixture's initial launch. The terminate/relaunch phase reuses the same
name without resetting it. Never uninstall between phases when checking durable
records. Release builds reject developer fixture/practice arguments, and hosted
test startup is isolated from production storage.

**ManualRepositoryTests**, **RecommendationRepositoryTests** and
**SettingsRepositoryTests** cover acknowledged payloads and receipts, revisions,
profile separation, idempotent retries, rollback, unsupported schemas and
reopening. **ControllerTests** and **SettingsControllerTests** cover uncertain
save results, retained pending intent and blocked competing actions. Keep exact
legacy JSON bytes, integer load values, microseconds, audit history, old program
versions and deletion tombstones in these assertions.

Practice remains Debug-only through explicit `--practice` injection. Its
`adaptive_workout.sqlite` records are separate from manual logs and generated
history and never become progression evidence. No test should clear a normal
app store to recover from an error. A future transfer of real data needs its own
protected source backup, sandbox/replacement rehearsal, restore and rollback
checks.

**EnginePolicyTests**, **EngineCatalogTests**, **WgerSourceMapperTests**,
**EngineComposerTests**, **EnginePersistedRehearsalTests**,
**RecommendationHistoryTests** and **SavedWorkoutServiceTests** cover the
standalone adaptive pipeline. In particular, all five complete composed
snapshots are compared to frozen Dart output bytes, and the real three-entry
catalog digest is pinned while all entries remain disabled. Manual/practice
records and reported setup values must remain excluded from generated progression
evidence. A service tested with a synthetic atomic source does not establish a
production cross-store adapter.

Frozen expected bytes live beside the Swift tests and are not regenerated from
the implementation under test. Raw source snapshots are retained under
`native/ReferenceFixtures/wger`; attribution and pending reviews are documented
in [the benchmark source record](catalog/BENCHMARK_CATALOG_2026_09_08.md). See
[the preservation map](SWIFT_PARITY_MATRIX.md#preserved-reference-evidence) before
changing a fixture or notice. Removed Dart probes and fixture generators are not
current test commands; the reference implementation remains in Git history.

## Later installed-app acceptance

Resume these checks only when the owner requests device verification. Select an
explicit supported physical iPhone in Xcode; configure signing for the native
bundle and run the hosted and interaction test targets against isolated fixtures.
Do not silently substitute another destination for the requested device.

Record install/launch, acknowledged save, independent app termination/relaunch,
resume, correction, finish, history/source navigation and confirmed deletion
separately from package tests. Check Light/Dark/System appearance, keyboard and
sheet behavior, long content, and retained fields across tab changes. Confirm
rest deadlines resume correctly, foreground completion gives at most one cue,
and hidden/background expiry produces no catch-up haptic. Test the mute
preference and actual feedback comfort hands-on.

VoiceOver reading/action order, Voice Control names, 200-percent Larger Text,
Reduce Motion, Differentiate Without Color and exact graph-value access require
explicit acceptance. Supported-iOS/device coverage, interruption during an
uncommitted write, physical power loss, backup/file protection and final signed
release behavior remain separate until documented results exist. The current
migration does not claim these waived checks passed.

## Product outcome and release gates

The September 23 scope decision made the owner the sole initial tester on an
iPhone 17 Pro, with a September 29 private offline target. Earlier two-tester
wording below describes the broader approved protocol; it does not add a second
person to the current owner phase. Photo evaluation requiring another evaluator
is unresolved. The owner-supplied week-one program supersedes the earlier
strength-first plan, and the barbell benchmark goals below are deferred; the
language migration does not activate them. See [the implementation tracker](IMPLEMENTATION_WEEK_ONE.md).

The three-month outcome period and existing safety/review gates remain in force
before broader release. Catalog review, qualified review of clinical wording,
verified equipment/baselines, durable safety inputs, live intake and the production
atomic cross-store generation adapter are still required for real adaptive
recommendations. Current manual logging and descriptive graphs do not claim to
provide those features. HealthKit, cloud sync and Android are outside this
migration.

Retain the approved broader outcome criteria below for future readiness review;
they are requirements, not implemented reporting screens or observed results.
A TestFlight readiness review must cover adherence, strength, aesthetics/body
composition, flexibility, reliability/usability and recommendation safety without
omitting a category, followed by supported-device acceptance before release.

- Adherence is calculated for each tester over the full three-month period and must be at least 80% of planned workouts; a carried-forward workout counts only when completed
- Strength-outcome reporting covers only the approved barbell back squat, flat barbell bench press, and conventional barbell deadlift without combining or silently substituting non-equivalent variants
- Estimated one-repetition-maximum reporting uses only sets that satisfy the approved eligibility rules and never requires a true maximum attempt
- Each tester must improve estimated one-repetition maximum by at least 5% in each approved benchmark over the three-month private test; reports must show each lift separately and must not imply that this result is guaranteed for other users
- Eligible-set estimates use `load × (1 + (completed repetitions + RIR) / 30)` with 2 to 10 completed repetitions, integer RIR from 0 to 3, and completed repetitions plus RIR from 3 to 10
- Eligibility tests reject warm-ups; missing or invalid load, repetitions, RIR, variation, or validity status; and assisted, failed, partial-range, pain-affected, or technique-invalid sets
- Load tests include the applicable bar weight, normalize units before calculation, compare unrounded values, and restrict rounding to display
- Baseline and final values for each lift are independently calculated as the median of all eligible estimates from the first and last three qualifying sessions, respectively, with at least two eligible sets required per session
- Insufficient comparable data returns `insufficient evidence`, and no exercise or materially different variation may be silently substituted
- Each tester's baseline and final comparison sets must use the same documented benchmark setup and technique standard
- Each tester satisfies the aesthetics criterion either by reducing average waist circumference by at least 2.5 cm or by keeping it within 1 cm of baseline while meeting the approved standardized-photo definition criterion
- Baseline and final waist values are each the average of three measurements collected using the approved site and consistent morning conditions; seven-day average body weight and smart-scale estimates are context only
- Standardized photos use matching front, side, and back views, lighting, camera distance, clothing, and poses; the testers may voluntarily share and assess them outside the app
- Private-test builds do not request photo-library access or store, import, analyze, or synchronize body images
- Matching baseline and final photos are randomly labeled A and B, and the evaluator submits all front, side, and back scores before learning which images are final
- Each view is scored `+1` for visibly more muscular definition, `0` for no meaningful difference, or `-1` for visibly less muscular definition; the photo path requires a total of at least `+2` for the final images and no `-1` view
- A comparison with inconsistent lighting, pose, distance, clothing, or framing is invalid and cannot contribute to the result; photo scoring is reported as subjective private-test evidence rather than scientific proof of body-composition change
- Flexibility reporting separately records the three-attempt average for each side of the ankle knee-to-wall and active straight-leg raise tests and the three-attempt average for shoulder flexion
- Flexibility improvement thresholds are 2 cm for the more restricted ankle, 5 degrees for the more restricted active straight-leg raise, and 8 degrees for shoulder flexion
- Each tester must exceed the threshold in at least two of the three flexibility measures without any measure worsening beyond its threshold; pain stops the affected test and follows the safety process
- Flexibility results must not be described as an injury diagnosis, proof of safer lifting, or evidence of reduced injury risk
- Baseline and final flexibility tests occur before training at approximately the same time of day, with no lifting or dedicated stretching earlier that day and with the same room, equipment, camera, evaluator, and setup
- Testing uses five minutes of easy walking, three practice attempts, and then three valid recorded attempts per side separated by 30 seconds; the average is reported
- Pain stops the affected test, observable compensation or setup error invalidates an attempt, and inability to collect three valid attempts returns `insufficient evidence`
- Knee-to-wall tests are barefoot with heel flat and knee tracking over the second toe; great-toe-to-wall distance is recorded to 0.1 cm at the farthest valid knee contact
- Active straight-leg raises use a supine position, secured straight non-test leg, straight test knee, relaxed ankle, and a fixed perpendicular side photo at the first knee bend, pelvic movement, or comfortable active end range
- Shoulder-flexion tests use a marked standing position 1.5 metres from a side-on shoulder-level camera, thumb upward, elbow straight, neutral trunk, and comfortable active end range without leaning or arching
- A tester within one improvement threshold of a documented valid measurement ceiling at baseline meets that measure by maintaining it without threshold-level decline; ceiling status and value must be recorded before testing and cannot arise from pain, compensation, or invalid setup
- No workout record may be lost, duplicated, or corrupted during the private test
- At least 98% of started workouts must complete without a crash, frozen screen, or app defect that prevents completion; the report must show both the numerator and denominator
- No critical or high-severity defect may remain unresolved before TestFlight readiness is approved
- Each tester must independently demonstrate starting and resuming a workout, logging and correcting a set, skipping work, requesting a supported replacement, completing a workout, and finding a previous workout
- Each tester records a one-to-five ease-of-use score after every completed workout, and at least 80% of each tester's completed workouts must score four or five
- A critical workflow fails usability review if it repeatedly causes confusion or requires external instructions, even when the numerical ease-of-use threshold passes
- Safety validation requires zero recommendations that violate an explicit limitation, excluded movement, unavailable-equipment constraint, or approved load or volume boundary
- Safety validation requires zero injuries or concerning events to which an app recommendation may reasonably have contributed and zero unresolved safety incidents at the end of the private test
- Pain or concerning-symptom input must stop the affected exercise, preserve the report, avoid automatic substitution, and avoid any load or volume increase
- Every unsafe or clearly unsuitable recommendation must become a preserved regression case; the affected path remains disabled until its cause is corrected, its regression test passes, and relevant deterministic simulations are replayed successfully
- Missing or invalid safety information must return an explicit no-recommendation result
- Tests and product language must not diagnose injury, prescribe rehabilitation, claim injury prevention, or imply medical clearance; symptom wording and escalation instructions require qualified clinical review before outside testing


## Algorithm test rule

Write expected input/output examples before implementing each rule. Include normal, boundary, invalid, missing-data, unit-conversion, and regression cases.

For exercise selection, tests must also cover:

- Identical explicit inputs produce identical recommendations
- Catalog iteration order does not change selection
- Stable tie-breaking between equally scored candidates
- Equipment and capability constraints remove ineligible exercises
- User exclusions are respected
- A supported exception produces an eligible engine-selected substitute
- Pain or concerning-symptom input follows the safety path rather than an ordinary substitution path
- No feasible candidate returns an explicit constrained or no-recommendation result
- Recommendation explanations match the rules that actually affected selection
- Eligibility and safety results remain understandable and operable with VoiceOver, Voice Control, 200-percent Larger Text, Reduce Motion, and Differentiate Without Color enabled
- Each result uses visible text and programmatic semantics rather than color, motion, sound, or an icon alone, and exposes one clear primary action
- Any future AI-assisted explanation preserves the deterministic status, reason codes, parameters, and safety action exactly; core filtering remains functional when AI is unavailable
- Historical recommendations remain interpretable using their recorded rule-set and catalog versions
- Catalog import is reproducible from the recorded wger snapshot identifier and produces the expected manifest and integrity digest
- Every imported record retains its wger base and translation IDs and UUIDs, API and page URLs, both attribution records, modification disclosure, and review status
- Records with missing, unsupported, or inconsistent license metadata are rejected; attribution output covers every shipped wger-derived record
- Imported HTML, active content, malformed URLs, unknown enums, invalid relationships, duplicate identifiers, and unsupported values are rejected or converted only through an explicitly tested allowlist
- Wger images and videos are absent from the V1 bundle, and core workouts require no live wger network access
- An imported record remains ineligible for recommendation until all required product, scientific, safety, equipment, and licensing reviews pass
- Catalog contract tests cover every required field, allowed enum, referenced identifier, null-versus-empty rule, length bound, uniqueness constraint, and selectable-state invariant in `EXERCISE_CATALOG.md`
- Property tests demonstrate that source-only and presentation-only fields cannot change exercise eligibility, ranking inputs, or recommendation output
- Reordering catalog entries or set-valued identifiers does not change the validated entity set or deterministic recommendation output
- Canonicalization tests sort entries and set-valued IDs, verify the RFC 8785-compatible restricted catalog payload encoding, and check the expected lowercase SHA-256 digest from fixed fixtures
- Eligibility tests recompute the canonical explicit-constraint digest, reject a supplied mismatch before safety evaluation, and prove that each included constraint field affects the digest while excluded presentation and candidate fields do not
- Eligibility monotonicity tests prove that adding a hard exclusion cannot make an ineligible candidate eligible, and combined-failure tests retain every applicable reason in canonical order
- Boundary tests cover every maximum in `EXERCISE_TAXONOMIES.md`, including exact-limit acceptance, one-over rejection, entry-count limits, and decompressed-size limits
- Wger mapping fixtures cover every source muscle, equipment, category, language, and license ID listed in `WGER_MAPPING.md`; an upstream ID/name mismatch fails import instead of silently remapping
- A missed workout remains the next recommendation and shifts later workouts forward without changing their order
- Schedule behavior depends on an explicit requested date and history rather than the wall clock
- The initial owner build remains functional without HealthKit authorization or health data

## Simulation rule

Simulation code must use seeded randomness, preserve reproducible cases, report distributions rather than only averages, and never silently change production rules.
