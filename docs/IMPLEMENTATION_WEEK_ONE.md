# Seven-day implementation tracker

> Historical implementation record. Flutter/Dart paths, commands and acceptance results below refer to the pre-migration source in Git history. The maintained implementation is Swift; see [ADR 0018](decisions/0018-native-swift-migration.md), [Architecture](ARCHITECTURE.md), [Testing](TESTING.md) and the [behavior map](SWIFT_PARITY_MATRIX.md) for current paths and status. Product and training gates remain in force.

Day 1: September 23, 2026. Target: September 29, 2026.

Current forward plan: [seven-day backend completion plan](BACKEND_COMPLETION_PLAN_7_DAYS.md), based on a fresh code/test audit and Fitbod/Gravl product research. It defines the remaining backend work, dependencies and acceptance gates. The original milestone table and dated entries below remain implementation history; later entries supersede earlier pending statuses. The new plan does not approve unresolved training rules or catalog reviews.

## Confirmed scope

- One initial tester: the product owner on an iPhone 17 Pro.
- Private offline build; preserve support for the agreed iOS range, not only the test phone. The owner chose the minimum iOS supported by Flutter; verify that minimum for the pinned SDK and define the simulator/device coverage matrix.
- The owner supplied [the five-session program](programs/OWNER_PROGRAM_2026_09_23.md). Preserve its prescriptions; resolve the listed ambiguities before executing them.
- Preserve existing uncommitted work. No new dependencies or commits are approved by this tracker.
- Three-month outcomes are not seven-day acceptance criteria. Existing catalog, safety, and scientific review gates remain in force.

## Daily milestones

| Date | Deliverable | Completion evidence | Status |
| --- | --- | --- | --- |
| Sep 23 | Executable baseline and reviewable contracts | Format/analyze/tests; rule examples; device/signing readiness | In progress |
| Sep 24 | Reviewed catalog and verified profile/equipment | Eligibility and exclusion tests; review evidence | Pending catalog review and inventory |
| Sep 25 | Durable logging | Restart recovery, write failure, duplicate-action, migration and isolation tests | Pending storage contract |
| Sep 26 | One complete approved generated session | Deterministic replay, duration/load feasibility and refusal tests | Pending warm-up, duration and catalog review |
| Sep 27 | Adaptation and supported replacement | Progress/hold/regress boundaries and safety precedence | Load policy tested; storage/UI/replacements pending |
| Sep 28 | Schedule, history, corrections, export/deletion | Carry-forward, no duplicate volume, correction and export tests | Pending policy decisions |
| Sep 29 | Full offline acceptance on owner's phone | Airplane-mode onboarding through second recommendation, termination recovery and accessibility | Pending Xcode/signing and implementation |

Work sequentially in bounded slices. A date is a target, not permission to bypass a gate. If a prerequisite remains unresolved, record the affected milestone as blocked; a sample logging demo does not satisfy generated-workout acceptance.

## Decisions and inputs needed

| Input | Owner / next action | Gate |
| --- | --- | --- |
| Reviewed five-session program | Program and P1–P10 approved; warm-up and time feasibility remain unresolved | Composition |
| Progression and replacements | P1–P10 approved; implement and test before integration | Adaptation |
| Equipment and units | Pounds confirmed; owner will verify increments, quantities, machine identity and safety capabilities | Eligibility and feasible loading |
| iOS version and signing | Owner reports latest iOS and is installing Xcode; numeric iOS version and developer membership remain unverified | Device installation |
| Supported iOS range | Flutter-supported minimum selected; verify pinned SDK support and deployment settings | Compatibility claim |
| Partial sessions and repeated misses | Prepare explicit options for review after program arrives | Schedule and adaptation |
| Storage | Prepare repository/schema/migration decision; request approval before any new dependency | Durable writes |
| Catalog reviews | Preserve evidence for science, safety, equipment and license reviews; publish new immutable version | Selectable catalog |

## Contract examples required before implementation

For each supplied training rule, record its identifier/version, source/reviewer, explicit inputs, expected output, reason code and normal/boundary/invalid/missing-data examples. Until approved, return blocked/no recommendation for that path.

The logging/storage contract must separately represent targets and actuals, warm-up and working sets, units, validity, skips, pain reports, corrections, drafts and completion. Define action identity and transaction boundaries before writes; acknowledge success only after durable saving. Keep storage behind repository interfaces and preserve historical rule/catalog versions.

## Day 1 environment findings

- Installed Flutter 3.47.2 / Dart 3.13.2; host and Dart executable are arm64.
- Initial test run failed before executing tests because `flutter_tester` was missing.
- Flutter's installed cache code intentionally uses the directory `darwin-x64` for the host-specific `darwin-$arch/artifacts.zip`; the directory name alone does not establish binary architecture.
- Restored matching artifacts with `flutter precache --universal --force` (exit 0); `file` confirms the restored test runner is an arm64 executable.
- `xcode-select -p` points to CommandLineTools; `xcrun xctrace list devices` fails because xctrace is unavailable. `/Applications` contains `Xcode.appdownload`, not a usable `Xcode.app`. Device signing and installation are unverified.

## Day 1 code slice

Pin the raw benchmark fixture digest and validate source timestamp calendar/clock/offset fields before Dart can normalize overflow. Preserve valid offset conversion and fractional-second truncation, and preserve missing timestamps as unknown. No catalog record is enabled by this change.

Validation on September 23: `dart format --output=none --set-exit-if-changed .` passed (18 files, zero changes); `flutter analyze` passed with no issues; `flutter test` passed all 98 tests; `git diff --check` passed. Physical-device, signing and storage integration checks remain unverified.

The [rule contract](programs/WEEK_ONE_RULES_PROPOSAL.md) is approved by the owner on September 23. Full Day 1 is not complete until remaining contracts are resolved. Xcode installation is in progress per the owner; wait for their completion message before device checks.

[Flutter's current support matrix](https://docs.flutter.dev/reference/supported-platforms), verified September 23 for Flutter 3.47, lists iOS 15–27 on ARM64. Minimum target: iOS 15. Existing project settings mix explicit 15.0 and Xcode-recommended values; normalize and verify the effective deployment target once full Xcode is available. No full-range compatibility claim has been validated.


## Approved-policy implementation slice — September 23

Owner approved P1–P10 and logging conventions and reports running the latest iOS; no numeric OS version has been inferred. Xcode installation is underway and device checks await the owner's completion message.

Implemented `LoadProgressionPolicy` for P4–P6, baseline/current-check blocking, and P9's bodyweight/assistance hold. This is a candidate-load domain module, not a live recommendation or complete adaptation loop. It preserves evidence IDs and rule version, requires both sides of unilateral work, and does not filter incomplete sessions out of the latest-two-exposure sequence. No dependencies added and no commits made.

Validation: 56 progression tests pass; full `flutter test` passes 154 tests. `dart format --output=none --set-exit-if-changed .` passes (20 files, zero changes); `flutter analyze` reports no issues; `git diff --check` passes. Final code and documentation changes inspected. Device/storage integration remains unverified.

Next integration work: reviewed program catalog and verified inputs, logging/storage contract, then orchestration that derives the progression gate from the current guarded eligibility result and supplies complete persisted history. Warm-up and duration feasibility remain unresolved.

## Xcode and research update

Xcode 27.0 (27A266a) is installed and selected at `/Applications/Xcode.app/Contents/Developer`; Flutter's Xcode check passes. An iOS 27 simulator runtime is installed. A connected physical iPhone reports iOS 27.0. The owner reports free Apple membership; personal-team signing and actual app installation remain unverified. Android SDK is absent, outside this week's iOS scope.

The owner authorized a researched warm-up draft and internet-derived equipment examples. See [warm-up proposal](programs/WARMUP_PROPOSAL.md) and [equipment assumptions](programs/EQUIPMENT_REFERENCE_ASSUMPTIONS.md). The owner approved the warm-up rules, retaining unresolved-setup blocking. Equipment examples remain provisional rather than verified gym inputs.

Device preference: the owner requests physical-iPhone testing only. Do not download or launch simulators. The installed simulator runtime was merely observed during environment inspection. The current Flutter iOS artifact download supplies the physical-device build.


Warm-up implementation validation: 19 new tests pass; full suite passes 173 tests. Formatting passes for 22 files with zero changes; static analysis reports no issues. `flutter build ios --debug --no-codesign` succeeds and produces `build/ios/iphoneos/Runner.app`. This is an unsigned physical-device build, not an installed or tested phone app. No simulator was downloaded or launched by this task. Signing, installation and device acceptance remain outstanding.

`WarmupPolicy` implements the approved target calculation only; application execution checks for symptoms/comfortable effort, bodyweight rehearsal, full duration accounting and UI/storage integration remain outstanding. Internet-derived equipment references have not enabled any catalog record or altered a personal load.


## Physical-phone installation — September 23

After explicit owner authorization, the existing Apple development identity and project team successfully signed the app. `flutter build ios --debug` succeeded and `devicectl device install app` confirmed installation. Then `flutter run --release` built, installed and launched the release build on the connected physical iPhone. A subsequent device process listing confirmed `Runner.app/Runner` running. No simulator was used, signing settings were not changed, and no paid membership was purchased.

This confirms build/sign/install/launch only. The installed app still presents the sample workout flow; durable logging and the complete approved recommendation pipeline are not implemented. Visual phone acceptance, restart recovery, accessibility and full offline end-to-end validation remain outstanding. No source-code changes or test rerun were needed for this installation step.

## Next milestone after successful phone launch

The owner confirms the installed sample works. Prepare durable practice-session logging next: distinct sets, save acknowledgement, draft recovery and completion/history, isolated from real recommendation evidence. [ADR 0009](decisions/0009-local-workout-storage.md) is a concrete storage proposal with schema, transaction/retry behavior and device acceptance checks. Approval is required before adding sqflite and the SDK integration_test dependency; neither has been added. No code behavior changed in this planning step.

## Durable practice logging — September 23

Owner approved ADR 0009 and the sqflite / SDK integration_test dependencies. Implemented native SQLite storage behind a pure Dart repository interface, transactional receipts, revision checks, profile isolation, corrections, resumable drafts and completed-session history. The default app now opens the practice logger. Synthetic practice records remain separate from recommendation evidence; the complete approved program and progression pipeline are not yet connected.

Validation: 202 local tests and six physical-iPhone database integration tests passed. The separate debug integration restart harness encountered Flutter debugger/DDS and VM-service stream errors and did not produce a clean overall pass. An independent release-mode probe successfully saved three synthetic records and recovered their exact values after replacement/termination and launch in a different process (28035 to 28040). The probe uses only practice_release_probe.sqlite; it does not reset the production database. This verifies committed-record recovery, not power loss during an uncommitted write. No simulator was downloaded or launched.

Remaining acceptance: owner interaction and airplane-mode checks, VoiceOver, full real-program logging and recommendation integration, supported-iOS deployment-target normalization, future migrations and export/deletion. The earlier milestone table remains a schedule, not a completion claim.

Final verification for this slice: format passes (33 files, zero changes), analysis reports no issues and diff whitespace checks pass. The normal `lib/main.dart` release build was restored, installed without uninstalling, launched and confirmed running on the owner's phone (process 28042). No commits were created.

## Owner acceptance — September 23

The owner reports: “the practice test saved and i have verified it.” Mark manual practice-save acceptance confirmed. This statement does not independently confirm every correction/history, airplane-mode or accessibility check.

Next bounded implementation slice: represent the approved five-day program as versioned domain data, preserving exercise order, supersets, three paired fly/lateral-raise rounds and approved prescriptions. Connect real-session logging only after its storage contract and required catalog/setup gates are satisfied. Unresolved equipment and bodyweight warm-up setups remain blocked; practice history must not become progression evidence.

## Approved program preview — September 23

Added all five approved session templates and a read-only preview accessible through “Your program” on the practice screen. Preserves ordered exercises, paired supersets, the three-set fly amendments, rep ranges, 2–3 RIR, upper-bound/default rests, single-arm pulldown per-side reps and approved alternative preferences. Thursday recovery is displayed; Sunday scheduling is not invented. Optional conditioning remains off. The existing practice database and saved records are unchanged. Real-session logging, verified catalog/setup selection and adaptive recommendations remain separate unfinished work.

Preview validation: all 208 tests pass, including exact prescription/rest/order checks, immutability, alternative preferences, superset counts and enlarged-text preview rendering. Formatting passes for 37 files and analysis reports no issues. No new dependencies or database migration were introduced.

## Manual program logging — September 23

The owner confirmed program visibility and authorized the next logging slice. The program screen now opens manual workout logging/history: select a training day, record prescribed set actuals or explicit skips, record warm-ups separately, distinguish exact setup/variation/load convention, and record both sides of single-arm pulldowns. An unfinished workout resumes as a draft. Completion requires all working-set slots recorded or explicitly skipped; skipped work stays visible. Completed records support audited corrections. Pain blocks additional actual sets for that exercise. Pending saves retain their action and values for retry and prevent navigation from discarding them.

Storage uses separate `program_logging.sqlite` with transactional session revisions, action receipts, immutable prescription snapshots, profile isolation and one-draft uniqueness. Existing practice storage was not migrated or cleared. Manual entries are explicitly ineligible for recommendations and do not establish verified baselines. No dependencies added; no commits created.

Validation: 222 local tests pass; format passes (47 files, no changes); analysis has no issues; whitespace diff check passes. Four physical-iPhone integration tests pass, covering duplicate/stale actions, unchanged corrections, audited corrections, reopen/profile isolation, rollback after receipt failure, one-draft uniqueness, future schema and prescription mismatch refusal, completion and post-completion edits. A separate release probe passed transactional checks and full-process recovery (seed process 28102; verification process 28104), recovering 18 recorded working-set slots including explicit skips and the corrected actual value. It also confirmed unsupported-schema refusal preserves fixture records. Probes use isolated synthetic databases only.

Still pending: owner acceptance of real manual logging; physical airplane-mode and VoiceOver checks; verified catalog/equipment/baseline onboarding; warm-up execution and bodyweight gaps; recommendation orchestration; schedule/abandonment policy; supported-iOS normalization; backup/file protection and export/deletion. This is a manual logger, not a completed adaptive training engine.

The normal `lib/main.dart` release build was restored after device probes, installed without uninstalling and confirmed running on the owner's physical phone (process 28106). No simulator was downloaded or launched.

## September 23 — Day-one policy decisions and planning implementation

Recorded owner-selected scheduling/duration, advancement after explicitly ending a partial workout, explicit confirmation of target-load changes, editable exclusions and approved alternatives (including Tuesday lying curls). Program provenance is ChatGPT-created and owner-tested; trainer involvement is deferred. [Day-one contracts](programs/DAY_ONE_CONTRACTS_2026_09_23.md) define data records, the storage extension and a 25-variation catalog coverage/review packet. Remaining decisions have named roles and milestone dependencies; no absent reviewer or review evidence is fabricated.

Implemented pure `SessionPlanningPolicy` and advisory duration comparison with eight additional tests. No app/UI wiring, persistence change, catalog activation, dynamic replacement execution or load-confirmation execution is claimed. Existing manual v1 prescriptions remain unchanged to preserve historical records. Earlier Day 1 work remains in progress; long-absence handling, bodyweight rehearsals, timing assumptions and required reviews are open.

Validation for this slice: `dart format --output=none --set-exit-if-changed .` passed (49 files, zero changes); `flutter analyze` passed with no issues; `flutter test --reporter compact` passed all 235 tests; final diff/whitespace review passed. Dependency resolution noted four newer versions outside current constraints; no dependency changed. Physical-device/native integration tests were not run because this change adds standalone domain policies and documentation, with no device/storage integration. Existing uncommitted work was preserved; no commit was created.

## September 23 — Warm-up v2 approved and domain policies implemented

The owner approved the [researched W1–W7 policy](research/WARMUP_REVIEW_2026_09_23.md) after reviewing the findings. Added standalone bodyweight/assistance target generation, a v2 wrapper retaining the external-load calculation, and explicit continuation checks for feedback, rest, interruption and fresh gate inputs. Assistance uses its own quantity; supported knee raises and kneeling rollout ranges require matching verification. No guessed warm-up setting is derived from the owner's approximate working assistance.

Validation: 15 new tests passed; full `flutter test --reporter compact` passed **250 tests**. `dart format --output=none --set-exit-if-changed .` passed (51 files, zero changes), `flutter analyze` passed with no issues after correcting four brace-style notices, and final diff/whitespace review passed. No dependencies changed; the existing four newer-outside-constraints package notices remain. Physical-device/native integration tests were not rerun: this change has no storage/UI integration. Real equipment verification, reviewed variation bindings, persistent execution/receipts and app integration remain pending. No existing v1 prescriptions or catalog availability were changed; no commit was created.

## Day 3 backend — recommendation-linked storage and trustworthy history

Implemented immutable versioned prescription snapshots, separate generated occurrences/actuals, exact target validation, stable per-profile sequences, one active occurrence, completion/early end, transactional receipts, audited corrections and conservative history-revision invalidation. Historical prescriptions do not depend on the current program constant. Corrections retain pain-stop flags. The repository validates complete sequence and audit chains before exposing history. The progression adapter keeps intervening incomplete/incomparable exposures, exact setup revisions and baseline-confirmation references; it excludes warm-ups and never reads practice/manual stores.

Validation: 278 unit/widget tests, seven native SQLite integration tests on the authorized iPhone 17 Pro simulator, formatting (66 files, zero changes), static analysis (no issues), and whitespace review passed. Tests cover two-exposure increase followed by correction-driven hold, interrupted/early-ended evidence, version/setup/baseline comparability, both sides, malformed payloads, isolated profiles, retry/conflict, transactional rollback, stale future rejection, historical reads and unsupported-schema preservation. Synthetic fixture data only; no dependencies changed. Physical-device, full-process interruption, airplane-mode and full adaptive-loop acceptance were not run for this slice.

Remaining: guarded Day 4 composition and consistent current-input acquisition across stores; Day 5 live execution/scheduling and proposal confirmation; real catalog review/verified setup; Day 6 ownership services. The current UI stays unchanged. Backend storage success does not mean the full adaptive workout generator is enabled.


## Day 4 backend — deterministic composition infrastructure

Implemented the guarded pure-Dart composer for all five templates, approved alternatives, external and bodyweight rehearsals, once-per-session walking, paired-round ordering, preserved work/rest and separate progression proposals. New schema-2 recommendation payloads preserve exact cross-setup rehearsal identities, absent numeric rehearsal RIR, working/rehearsal ranges, binding references, per-slot reasons and proposed loads; old snapshots retain their encoding. A bounded version/reference validation fix permits the real dotted catalog-version format. All fixture reviews are synthetic and remain outside app assets.

Validation: formatting passed for 72 files with zero changes, static analysis passed, all 301 unit/widget tests passed, and eight native recommendation-history SQLite tests passed on the authorized iPhone 17 Pro / iOS 27 simulator. The native suite verifies schema-1/schema-2 coexistence, retry, history correction/invalidation, transaction rollback and refusal/preservation cases. No physical-device or full live-session acceptance was performed. No dependencies or production UI changed.

**Day 4 remains partial.** The application service defines and tests atomic capture/compare-and-save through a source interface, but a production adapter is not implemented or registered. Setup/history live in separate databases and durable safety/rehearsal inputs are still absent. Real reviewed catalog bindings, that consistency boundary, durable verification and subsequent live execution/confirmation remain pending. Monday has not passed the reviewed-real-catalog end-to-end exit. See [ADR 0014](decisions/0014-session-composition.md).

## September 24 — approved three-set shoulder press

Owner explicitly approved updating shoulder press to three working sets. Current previews and new manual workouts use `owner-program-v2` (3 × 8–12, unchanged rest/RIR); generated recommendations use `owner-generated-v3`. Frozen v1 templates, per-log version dispatch, version-preserving corrections and legacy setup decoding preserve old two-set records. The set-entry dialog validates against its selected historical log. No personal working loads were seeded and no production database was migrated.

Validation: format passed (72 files, zero changes), static analysis passed, all 304 unit/widget tests passed, and five native manual-program SQLite tests passed on the authorized iPhone 17 Pro simulator, including v1/v2 reopen and rejected in-place version changes. Whitespace review passed. No physical-phone install was performed for this change.

## Reported setup and durable rehearsal intake

Added schema-2 setup payloads for append-only working reports and bodyweight rehearsal attestations, retaining old payload compatibility and existing atomic SQLite receipts/audit. Controller intake preserves draft/unknown fields and subsequent preference edits preserve evidence. The composer now consumes complete saved attestations through exact current equipment and catalog bindings, while missing links, stale revisions, ambiguity, unknown feedback and adverse reports remain blocked. Working reports never become baselines or progression history. See ADR 0015.

Consolidated the conversation into a private local draft and readable summary outside source control: 28 reports and four unlinked rehearsal attestations. No owner values were seeded into tests or production app databases. Formatting (76 files), analysis, all 315 unit/widget tests, six native simulator setup-storage tests, and whitespace review passed. No new dependencies. The real catalog, exact setup linking, broader safety persistence, atomic cross-store generation adapter, intake UI and physical acceptance remain pending.

## Day 5 — saved-workout lifecycle backend slice (September 24)

Implemented `SavedWorkoutService`: saved-prescription resumption, set/correction
and completion/explicit early-finish actions, safe receipt retries, and next-session
planning derived from committed terminal history. Early finish retains partial
actuals; missed days and corrections do not consume queue entries. Next-session
planning requires explicit local end-date conversion. See ADR 0016.

Verification for this slice: formatting passed (79 files, zero changes), static
analysis passed, and all 323 local tests passed. The isolated
`integration_test/saved_workout_service_test.dart` passed on the connected physical
iPhone (iOS 27.0) with `--no-uninstall`, proving SQLite close/reopen recovery,
terminal receipt retry, retained actuals/audit revisions and one queue advancement.
An initial fixture assertion expected two audit entries; the repository correctly
includes the current state as a third entry. The corrected revision-chain assertion
passed. This is database reopen coverage, not process-kill or power-loss proof.

Full Day 5 remains pending: live execution UI, fresh safety/rehearsal orchestration,
target confirmation, production generation consistency and the broader adaptation
acceptance flow. No catalog review gate was cleared and no dependency was added.

### Choose today's workout — September 24 follow-up

Owner approved choosing any of the five lifting templates for today, regardless
of the original weekday label. The manual log now exposes “Choose today’s workout”
even when a Monday draft is open. Selecting the same template resumes it; switching
requires explicit early finish and preserves partial records. Cancel keeps the
current draft. Thursday does not invent a sixth lifting prescription.

Validation: formatting and static analysis passed; all 327 local tests passed.
All six native manual-log repository tests passed on the connected iPhone using
isolated fixtures and `--no-uninstall`, including early finish, retry, another
chosen day, database reopen and corrections. Widget tests exercise the picker,
cancellation, same-template resumption and failed saves; enlarged-text set entry
also passes without hit-test warnings.

### Delete individual manual workouts — September 24 follow-up

Added confirmed deletion from history rows and open workouts (including drafts).
The repository atomically removes the workout, corrections and associated save
receipts. Minimal opaque deletion identifiers prevent stale retries from restoring
the workout. Schema 1 upgrades to schema 2 without rewriting existing records.
See ADR 0017. Practice and generated recommendation history are outside this slice.

Validation: formatting and analysis passed; all 330 local tests and seven physical
iPhone manual-store integration tests passed. The isolated native fixtures verify
migration preservation, stale/action conflicts, rollback of partially attempted
deletion, receipt/revision removal, reopen/retry, profile isolation and prevention
of resurrection. No owner workout was deleted during implementation or testing.
