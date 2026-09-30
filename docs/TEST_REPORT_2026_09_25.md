# Full native app test — September 25, 2026

Status: complete. All automated functional scenarios passed across the recorded
runs after correcting one test-timing issue. A minor large-text visual limitation
and physical-device acceptance items remain.

## Tested state and environment

- Repository HEAD: `9a164acb4710f7ede58cf7e98eb9a8bb49400748`, with the existing
  uncommitted native feedback changes and this test expansion. This was not a
  clean-commit test.
- Xcode 27.0 (`27A266a`); Apple Swift 6.4 (`swiftlang-6.4.0.34.1`).
- Main simulator: iPhone 17 Pro, iOS 27.0, device
  `B2CDB159-8833-481A-91CC-D607C4578DC5`.
- Compatibility simulator: iPhone 16e, iOS 18.5, device
  `93C3A387-0221-4A6C-9E08-3C6C865AB469`.
- A dedicated temporary iPhone 16e / iOS 18.5 simulator was configured with
  `accessibility-large` text and dark appearance for a visual/workflow check.
  It was shut down and deleted afterwards. Existing simulator preferences were
  not changed.
- Every workflow used isolated fixture stores and preferences. No real workout
  data or physical phone was changed. Notification tests used an injected client,
  never actual production notification requests.
- Final source manifest: `/tmp/adaptive-full-source-manifest.txt` (80 Swift/project
  files), SHA-256
  `22669a5701abdf469d428860300566f5fa4379634d0f8c2a779edfc3182da925`.

## Checks

| Check | Result |
| --- | --- |
| Strict Swift formatting | Passed |
| Package build including tests | Passed |
| Mac core tests | 124 passed |
| Pinned wger importer tests | 3 passed |
| Generic iOS Debug build and static analysis | Passed |
| Generic iOS build-for-testing | Passed |
| Generic iOS Release build | Passed |
| Initial complete iOS 27 suite | 124 hosted core + 6 UI tests passed |
| Expanded iOS 27 suite | 132 hosted tests and 10 UI tests passed; one premature-alert-tap automation failure, resolved below |
| iOS 18.5 load-entry and notification tests | 3 UI + 7 native notification tests passed |
| Workout-switch scenario, iOS 18.5 | Passed |
| Original workout-switch code with corrected test, iOS 27 | Passed, then passed three consecutive stability iterations |
| Final UI scenario outcomes | All 12 distinct scenarios passed across the recorded runs |
| Dark / accessibility-large visual workflow | Passed navigation and saving; visual limitation below |

## Coverage added

`SetEntryCoverageTests` exercises bodyweight, assistance, copied assistance,
displayed-machine, plates-only and total-load values through the real form.
Existing workout-flow coverage exercises per-dumbbell values. Tests check exact
decimal preservation, no manual setup prompt, missing/malformed inputs remaining
unsaved, and successful correction.

`LifecycleCoverageTests` covers rest retention across tabs, cancellation of a
workout switch, confirmed switch after cancellation, rest clearing, preserved
finished history, deletion cancellation, and custom gym selection/address across
process restart.

`NativeNotificationTests` covers permission approval/denial/error; exact reminder
days/time and preference reload; disabling; partial scheduling failure and retry;
late asynchronous rest replacement; clear/relaunch cancellation; disabled/invalid
rest; visible rest-scheduling failure; fixture isolation; and competing saves.
The only notification implementation refactor is a small injected system boundary
so these tests can run without delivering alerts.

Existing tests cover all frozen program prescriptions, deterministic engine
contracts, malformed/missing/boundary input, manual/generated/practice separation,
canonical legacy JSON, exact integer loads/timestamps, receipts, profile isolation,
SQLite rollback/reopen/migrations, correction/deletion, appearance, history filters,
workout persistence across process restart, superset order, and offline wger names
and attribution. Backend tests do not activate the gated adaptive engine.

## Alert-test failure investigated and corrected

The first expanded test attempted to confirm the second workout-switch alert
immediately after choosing Tuesday. On iOS 27, this could tap before the alert
was ready and leave Monday unchanged. The test then failed its switch/history
assertions. Read-only inspection of that isolated fixture confirmed Monday
remained revision 0; it did not lose or corrupt a workout.

Initially this was suspected to be an app state-lifetime defect. Two tentative
alert-state changes were tried, but neither resolved the early-tap failure on
iOS 27. Waiting explicitly for the second alert, with a retained confirmation
screenshot, stabilized the test. The **original app alert implementation** was
restored and passed with the corrected test. The tentative app changes were
reverted, so this report does not count the initial diagnosis as a confirmed app
bug or claim that a product fix was required.

The retained regression checks cancelling a switch, confirming a subsequent
switch, the new Tuesday draft, cleared rest and preserved Monday history. Failed
investigation bundles remain failed evidence; the successful corrected-test runs
are recorded separately. The entire expanded suite was not rerun after this
small test-only synchronization correction; affected scenarios were rerun.

## Remaining visual limitation

At `accessibility-large` text size on the iPhone 16e, a native picker can truncate
its displayed selection (for example, Set validity shows `Un…own`). The full menu
choice and save action remain available, and the large-text test successfully
saved a set. This is a minor visual issue, not full accessibility acceptance.
Home text and form instructions wrapped; saving remained reachable by scrolling.

Screenshots inspected:

- `/tmp/adaptive-full-visual-attachments/2AB450D6-7A44-4BC8-B865-C77522BA041C.png`
  (large-text dark home).
- `/tmp/adaptive-full-visual-attachments/E236CCC6-6AA0-4E6C-BDF3-9168AEE2A5A2.png`
  (large-text set editor, including picker truncation).

## Not established by these tests

- Real locked-phone notification delivery, Focus/permission behavior and haptic
  feel. Notification logic passes with a simulated system client; this does not
  certify iOS delivery on the owner's phone.
- VoiceOver/Voice Control acceptance, all text sizes, Reduce Motion, every
  supported device/runtime, or iOS 17 runtime behavior. The iOS 17 deployment
  target builds, but no iOS 17 runtime is installed for execution.
- Real-data migration, backup restoration, physical power loss, distribution
  signing/TestFlight, or clinical/scientific validity of recommendations.
- Wger instructions/media or reviewed program bindings; the shipped library is a
  name/attribution reference, and selection gates remain disabled.

## Evidence

Logs are under `/tmp/adaptive-full-*.log`. Key result bundles:

- `/tmp/adaptive-full-suite-20260925.xcresult`: initial full suite, 130 passes.
- `/tmp/adaptive-full-expanded-20260925.xcresult`: expanded initial run, preserves
  the early-tap automation failure.
- `/tmp/adaptive-compat-20260925.xcresult`: iOS 18.5 load/notification coverage.
- `/tmp/adaptive-switch-regression-20260925.xcresult`: switch check on iOS 18.5 during investigation.
- `/tmp/adaptive-visual-20260925.xcresult`: dark / large-text check and screenshots.
- `/tmp/adaptive-full-final-regression-20260925.xcresult`: investigation run;
  visual test passed, early-tap switch test failed.
- `/tmp/adaptive-switch-original-confirmation-20260925.xcresult`: original app
  behavior with the corrected switch test, passed.
- `/tmp/adaptive-switch-stability-20260925.xcresult`: repeated corrected-test check.

Apple's no-AppIntents metadata-extraction warning and simulator debugger/
accessibility-class diagnostics were observed. They are tool/runtime diagnostics,
not new Swift compiler warnings. No check is treated as physical-device acceptance.
