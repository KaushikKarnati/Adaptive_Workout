# Native migration evidence

The maintained app is native Swift/SwiftUI at `native/AdaptiveWorkout.xcodeproj`, scheme **AdaptiveWorkout**, iOS 17+. Android remains deferred. Source retirement is complete; final clean-checkout verification is recorded below.

## Owner decisions

- Native migration was explicitly approved.
- The owner deleted the old Flutter app and confirmed: **only test data; start fresh in Swift**. No real-workout transfer, recovery or retained-container replacement is required or claimed.
- The owner subsequently requested: **skip physical device checking; focus on migration**. No further iPhone or simulator checks are part of this completion pass. This changes the acceptance scope, not the meaning of a passed test.
- Native bundle identity remains `com.adaptiveworkout.adaptiveWorkout.native`; display name is **Adaptive Workout**.

## Reference and compatibility

- Original Flutter reference: `c28d22f50dca8eced393e749d0142b0877b4ba0f`.
- September 24, 2026 baseline: Dart formatting passed (113 files, zero changes), `flutter analyze` passed with no issues, and all 395 Flutter tests passed. Formatting was rerun after dependency resolution to remove initial missing-package warnings.
- Effective previous Runner target: iOS 17.0; native pins the same minimum. Build toolchain: Xcode 27.0 / Swift 6.4, Swift 6 language mode.
- Migration reference checkpoint: `b1da05d`. It retains both implementations and every newly created Dart parity generator before Flutter retirement. Use a separate checkout of that commit if regenerating fixtures; the active native project does not depend on those scripts.
- Native golden fixtures contain exact Dart-produced manual v1/v2 prescriptions, receipts, settings and recommendation payloads, plus all five composed session snapshots. Native tests verify byte equality, canonical catalog integrity, exact timestamp behavior and storage contracts.
- Raw wger snapshots were preserved byte for byte under `native/ReferenceFixtures/wger`. Source/license metadata and the disabled three-entry benchmark catalog remain intact.
- See [the behavior map](SWIFT_PARITY_MATRIX.md) for test-group coverage and historical paths.

## Local native verification

Final executable source: `37711e3` (later commits update documentation and generated Xcode workspace metadata only). A clean archive of that commit contained no Dart source or Flutter manifest. Both clean checks ran with `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, excluding the installed Flutter SDK.

| Check | Result |
| --- | --- |
| `xcrun swift-format lint --strict --recursive` over maintained Swift source/tests and Package.swift | Passed; no formatting diagnostics |
| `swift test --package-path native/Packages/WorkoutCore` in the clean checkout | **115 tests passed, zero failures**, 13.8 seconds |
| `xcodebuild ... -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build-for-testing` | Passed; app, hosted core tests and UI tests compiled without launching a device |
| `xcodebuild ... analyze` | Passed |
| `xcodebuild ... -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` in the clean checkout | Passed |
| Retained raw wger files compared to the original fixture bytes | Exact match |
| `git diff --check` and maintained documentation link checks | Passed |

Clean-checkout logs are `/tmp/adaptive-native-clean-core.log` and `/tmp/adaptive-native-clean-release.log`; final Debug/test compilation and analysis log is `/tmp/adaptive-native-final-debug.log`. These local temporary logs are not committed or guaranteed to persist. Full reproducible command forms are in [Testing](TESTING.md).

Xcode reports one tooling warning category: **AppIntents metadata extraction skipped, no AppIntents.framework dependency found**. This app does not implement App Intents; no additional framework was added to suppress the message. No Swift compiler or analyzer warning remains.

The final regression cases include invalid UTF-8 storage refusal, fixture/preferences isolation and strict fixture names, finite/extreme timer inputs, exact save acknowledgement, inspectable pending values, and appearance failure leaving workout storage usable. No third-party runtime or build dependency was added.

## Earlier iPhone evidence, before checks were deferred

These checks ran on the connected physical iPhone 17 Pro, before the final source changes. They are useful subset evidence, not a pass for the complete final revision.

- 41 hosted core tests passed (`/tmp/adaptive-native-unit-device-1.xcresult`).
- Workout screen test passed: start, save, tabs, terminate/relaunch, correction, early finish, graph and confirmed deletion (`/tmp/adaptive-native-ui-device-5.xcresult`).
- Settings test passed: Light appearance, retained unsaved duration across tabs, save, terminate/relaunch and restored preference (`/tmp/adaptive-native-settings-device-1.xcresult`).
- Screenshots from those tests were inspected; a duplicated settings title was corrected and checked on the later run.
- Initial screen testing encountered the free-profile app-slot limit. The owner subsequently removed the old test-only Flutter app. No user app was uninstalled by the migration tools.
- An attempted later hosted suite failed at compilation on a missing `try`; the source was corrected. It is not counted as a passing device suite. Some earlier attempts also exposed a stale Xcode package build graph; clean generated build data resolved it.
- No simulator was used. Final phone install/launch, the new history navigation test, recent error-handling UI and complete device suite remain unrun at the owner's request.

## Simulator launch repair — September 24, 2026

The owner subsequently requested simulator diagnosis. A fresh Debug simulator
build reproduced missing WorkoutApplication/WorkoutDomain/WorkoutPersistence
module errors: the app compiled arm64 and x86_64 while its package dependencies
compiled only the active arm64 destination. Setting project Debug
`ONLY_ACTIVE_ARCH = YES` aligns app and test targets with package builds.
Release settings are unchanged.

Verification on the booted iPhone 17 Pro, iOS 27.0 simulator:

- Explicit-destination simulator build passed after the previously failing build.
- New `LaunchTests.testAppLaunchesIntoWorkoutShell` passed, verifying the start
  control and both tabs using an isolated fixture store.
- App installed and launched successfully with a separate simulator fixture.
- Strict Swift formatting, package build with tests, all 115 package tests, and
  the generic iOS unsigned build passed.
- AppIntents extraction warnings remain as described above. Simulator test logs
  also emitted debugger-version and duplicate Apple accessibility-class
  diagnostics; the launch test nevertheless passed.

Logs: `/tmp/adaptive-workout-simulator-build.log`,
`/tmp/adaptive-sim-launch-test.log`, `/tmp/adaptive-sim-package-build.log`,
`/tmp/adaptive-sim-package-test.log`, and `/tmp/adaptive-sim-device-build.log`.
This is a launch regression check, not full simulator workflow or physical-device
acceptance.

## Product and acceptance limits

Migration preserves the existing manual workflow and standalone adaptive backend. Real catalog activation, reviewed program bindings, complete safety/equipment inputs, the atomic cross-store capture/save adapter, target confirmation and live generated-session execution are still gated future work. Migration does not turn structural eligibility into a prescription.

VoiceOver, 200% Larger Text, physical haptic feel, broader supported-OS/device coverage, power-loss durability and release-distribution signing are not newly certified. No real-data conversion or recovery is claimed. Optional device tests and their isolated fixture routing remain available for a later acceptance pass.

## Workout feedback implementation — September 25, 2026

Added explicit previous-set copying, variation-compatible load choices, removal
of the manual setup prompt, current-set highlighting/scrolling in paired order,
and return home after acknowledged normal/early completion. Existing setup labels
and canonical legacy records remain intact. Empty-setup chart groups are scoped
to their session. Added opt-in rest alerts and weekday/time workout reminders;
fixture sessions cannot schedule or remove production alerts. Added a separately
licensed offline wger name/attribution reference (788 entries), not an activated
recommendation catalog. See ADR 0019 and the September 25 wger snapshot document.

Verification completed:

- Required strict Swift formatting lint: passed.
- Required `swift build --build-tests --package-path native/Packages/WorkoutCore`:
  passed.
- Required package test command: 124 tests passed, zero failures.
- Required generic iOS unsigned build: passed after final source changes.
- Python pinned-import tests: three passed (reproducibility, invalid source fields
  and incomplete source rejection).
- Explicit iPhone 17 Pro / iOS 27.0 simulator destination
  `B2CDB159-8833-481A-91CC-D607C4578DC5`: nine targeted hosted core tests passed.
- Four targeted UI tests passed across runs: history/filter navigation;
  log/copy/correction/restart/home; paired-round current-set navigation; and
  notification controls plus searchable bundled wger content. All use isolated
  fixture stores. Notification fixtures deliberately do not request permission
  or deliver system alerts.
- Inspected the captured workout screenshot: current-set label/highlight and
  saved values are visible. This is not a full visual/accessibility acceptance.

An initial simulator build used a stale package build graph and could not find a
new domain type; a fresh `/tmp/adaptive-feedback-derived` build resolved it.
The initial settings test tapped a switch label without changing the switch;
targeting the switch control corrected the test. A subsequent search-field test
exposed an initially collapsed search UI; the library now keeps its navigation
search field visible, and the rerun passed. These failed attempts are not counted
as passing checks. Apple's existing AppIntents extraction warning (no AppIntents
framework), debugger lookup and duplicate accessibility-class simulator diagnostics
remain external tool/runtime messages, not newly introduced Swift warnings.

Evidence logs: `/tmp/adaptive-final-format.log`,
`/tmp/adaptive-final-package-build.log`, `/tmp/adaptive-final-package-test.log`,
`/tmp/adaptive-final-ios-build.log`, `/tmp/adaptive-import-test.log`,
`/tmp/adaptive-ui-test-fresh.log`, `/tmp/adaptive-convenience-test.log` (includes
one earlier failing settings test alongside passing superset/hosted tests), and
`/tmp/adaptive-settings-final-test.log` (passing final settings rerun).

No physical phone was changed or used for acceptance. Locked-phone notification
delivery, notification permission/Focus behavior, haptic comfort, VoiceOver,
installed real-data migration and power-loss behavior remain unverified. Wger
instructions/media and reviewed program bindings remain outside this reference
slice; no scientific, safety, equipment or license review gate was bypassed.

## Full native test sweep — September 25, 2026

The owner requested full app testing. See [the detailed report](TEST_REPORT_2026_09_25.md)
for source state, destinations, per-run outcomes, screenshots and limitations.
All runs used isolated fixture data. No physical-device acceptance is claimed.

- Mac package build and all 124 core tests passed; strict formatting and three
  pinned-import tests passed.
- Generic iOS Debug build/static analysis, unsigned Release build and test-target
  compilation passed. Apple's existing AppIntents warning remains explained.
- Initial full iOS 27 simulator run passed 124 hosted tests and six UI tests.
- Expanded coverage passed all 132 hosted tests, including eight new native
  notification tests using an injected system-client boundary. Ten of eleven UI
  scenarios passed in that run; one new switch test tapped its second alert too
  early. The corrected test explicitly waits for the alert and retains a screenshot.
- An initial suspicion that switch state was being lost was disproved by testing
  the original alert implementation with the synchronized test. Tentative app
  alert changes were reverted. Failed investigation runs are preserved in the
  detailed report and are not counted as passing suites.
- iOS 18.5 on iPhone 16e additionally passed three load-entry UI tests, seven
  notification-client tests and the switch scenario. Dark/large-text logging
  passed on an isolated temporary simulator, with a minor native-picker selection
  truncation observed. The temporary simulator was deleted after testing.

New coverage includes every offered load convention through the form, rejected
and corrected inputs, rest/tab retention, switch/deletion cancellation, gym
persistence and notification failure/cancellation races. The app changes from this
test sweep are limited to injecting the native notification system boundary for
isolated tests. Final functional scenario outcomes and the repeated alert-test
check are in the detailed report. Locked-phone delivery, physical haptics,
VoiceOver acceptance and real-data transfer remain unverified.
