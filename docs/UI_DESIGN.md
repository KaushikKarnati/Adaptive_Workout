# Interface design

The interface uses a restrained blue accent, quiet surfaces, clear typography and generous spacing. The Training home prioritizes manual workout logging, followed by the approved program and training setup. Practice is hidden from normal navigation; its code and records are preserved for explicit development/test injection. Future screens should extend these patterns using real application state; do not add invented activity, progress, readiness or recommendation metrics.

## Appearance

`AppTheme` in `lib/ui/app_theme.dart` defines both appearances. Screens consume semantic `Theme.of(context).colorScheme` roles and shared text styles instead of hardcoded foreground/background colors. Use `primary` for important actions, `onSurface` for primary content, `onSurfaceVariant` for supporting text and error roles for actionable failures. Preserve readable foreground/background pairs in both appearances; convey status with words or symbols as well as color.

System is the default and follows device appearance changes. Optional Light and Dark overrides implement the owner's explicit request. Apple generally recommends following the system without a separate app switch; this intentional exception keeps System first and explains the override. See [Apple HIG: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode).

The preference is local to this device. `AppearanceController` accesses the pure `AppearancePreferencesRepository` contract; `SqliteAppearanceRepository` stores one validated enum value in the separate `appearance.sqlite` database. The controller applies a selection after a successful save and surfaces load/save failures. Appearance does not change workout, setup or recommendation records.

## Type, layout and interaction

- Use the platform default font, including the iOS system typeface, without bundling fonts. Shared styles establish the hierarchy: 34-point page titles, 22-point section titles and 17-point primary body text. Preserve text scaling and allow important labels and explanations to wrap. See [Apple HIG: Typography](https://developer.apple.com/design/human-interface-guidelines/typography).
- Keep interactive hit regions at least 44 × 44 logical points, with space between independent actions. Shared filled buttons are at least 52 points high, and icon/text buttons at least 48 points high. Provide descriptive labels, tooltips for icon-only actions and visible selected/error states. See [Apple HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons).
- Let screens own safe areas, scrolling and page padding. `AppContent` only centers content and caps its width at 680 logical points. Use roughly 20–24 points of page/card padding, and avoid fixed text heights or horizontal layouts that cannot reflow.
- Reuse `AppPageHeader`, `AppSectionHeader` and `AppNotice` from `lib/ui/app_components.dart`. Headers already include spacing and heading semantics. Cards group related content; one prominent action establishes each screen's priority. Secondary details can use disclosure controls.
- Retain standard Flutter control interaction, focus and semantic behavior. Current Material controls are adapted with shared colors, shapes and typography; iOS navigation uses Cupertino transitions. This is not a native Liquid Glass implementation.

Review future screens at narrow widths, large text sizes, both appearances and with VoiceOver. Check contrast, focus order, selected-state announcements, keyboard access and access to all actions; appearance alone is not an accessibility certification. Reference: [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

## Haptic feedback

Use short, semantic system patterns following [Apple HIG: Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics). `AppHaptics` is presentation-only and sits above navigation so dialogs share the same preference. An iOS method channel invokes UIKit's selection, light impact and notification feedback generators; no custom vibration, audio or new dependency is used.

- Selection: changed appearance, training-day/exclusion choices and equipment/set selectors.
- Light impact: a new workout successfully created and reloaded.
- Success: acknowledged set/correction, setup/preferences, completed workout or deletion.
- Warning: destructive/early-finish confirmation and a newly selected pain-affected status.
- Error: invalid submission or failed initiated save. Retrying uses the final acknowledged outcome, never the original tap.

Loading, ordinary navigation, typing, scrolling, canceling and reselecting the current value stay quiet. Do not attach haptics to build methods or general controller listeners. Feedback failures never block an action, and visual confirmations/errors remain the source of truth.

The **Haptic feedback** switch under **Appearance & feedback** is on by default and saved in device-local UserDefaults. Muting it suppresses app cues; the switch itself uses controlled feedback rather than an adaptive control that emits an extra independent vibration. The native bridge also checks mute and foreground state before playing. UIKit determines whether hardware/system settings permit a cue. Unsupported platforms stay quiet. `PrivacyInfo.xcprivacy` declares app-only UserDefaults usage (`CA92.1`); no workout information enters this preference.

Widget tests cover muted/unsupported states, native failures, changed-vs-unchanged selection, delayed save acknowledgement, safe retries, and no independent switch vibration on iOS. `integration_test/haptics_test.dart` checks the native channel, preference reread, semantic requests and invalid arguments on the physical iPhone, restoring the previous preference. These checks verify requests and state; perceived strength and comfort require the user's physical assessment.

Haptics follow-up validation on September 24: all 360 local tests, formatting, static analysis, and the native haptics integration test passed. The signed release build also passed. A separate attempt to refresh the appearance screenshots stalled after device launch while connecting to the debugger; it was stopped with no tests run. The earlier appearance captures remain the visual evidence for the design pass; the new feedback section has narrow-screen/large-text widget coverage.

## Product boundaries

Display approved prescriptions and explain unavailable capabilities honestly. UI changes must not enable catalog entries, bypass setup or safety gates, calculate workout rules in widgets, or imply that manual/practice records are progression evidence. Preserve confirmations, pending-write locks, retry behavior and success acknowledgements owned by the existing controllers.

## Validation

Verified September 24, 2026:

- Formatting and static analysis pass. The full local suite passes, including home navigation, approved content, 320–390-point layouts at 2× text, both appearances, primary/appearance touch targets, system switching, persistence-controller retries and semantic text/action contrast of at least 4.5:1.
- `integration_test/appearance_test.dart` passed on the physical iPhone. All three preferences survive native SQLite close/reopen. UI rendering uses isolated in-memory workout/setup fixtures and does not touch production workout records.
- Twelve physical-iPhone captures were visually reviewed: home, appearance, program, setup, log and active session in both Light and Dark. Optional captures use `--dart-define=CAPTURE_UI=true` and write `tmp/ui-review-<screen>-<appearance>.png` inside the test app container.
- The signed regular release app was rebuilt, installed without uninstalling and launched on the physical iPhone after testing.
- Complete VoiceOver acceptance, all accessibility text sizes and broader device/OS compatibility remain unverified. Database reopen is tested; it is not a physical power-loss test.

For device validation run `flutter test integration_test/appearance_test.dart -d <physical-device-id> --no-uninstall`, then restore the regular release app. Only the separate `appearance_test_fixture.sqlite` is deleted by this test.

## Session timers

Manual workouts show a pinned elapsed-time bar, measured from their saved start
until the saved completion (including early completion). Breaks, background time
and time away from the app are included; this is elapsed time, not active exercise
time. Reopening restores it from existing timestamps, with no schema change.
Negative elapsed time after a device-clock change is displayed as zero.

Each block offers an explicit countdown using its saved prescription's rest.
For supersets start it after both exercises; for per-side work after both sides.
Starting another countdown replaces the previous one. The countdown rounds up
remaining seconds, catches up on foreground resume, and shows “Rest complete” at
zero. It does not automatically start, advance sets, or authorize continuing.
Clear rest, leaving the workout screen, app termination, switching workouts and
successful completion clear the countdown. No background alarm or notification
is scheduled. Timer display and controls use no new dependency or workout writes.
