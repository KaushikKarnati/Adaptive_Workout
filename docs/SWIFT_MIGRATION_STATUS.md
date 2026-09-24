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

Final executable source: `37711e3` (later commits update documentation only). A clean archive of that commit contained no Dart source or Flutter manifest. Both clean checks ran with `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, excluding the installed Flutter SDK.

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

## Product and acceptance limits

Migration preserves the existing manual workflow and standalone adaptive backend. Real catalog activation, reviewed program bindings, complete safety/equipment inputs, the atomic cross-store capture/save adapter, target confirmation and live generated-session execution are still gated future work. Migration does not turn structural eligibility into a prescription.

VoiceOver, 200% Larger Text, physical haptic feel, broader supported-OS/device coverage, power-loss durability and release-distribution signing are not newly certified. No real-data conversion or recovery is claimed. Optional device tests and their isolated fixture routing remain available for a later acceptance pass.
