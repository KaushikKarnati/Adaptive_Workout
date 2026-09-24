# Interface design

The maintained interface is native SwiftUI on iOS 17 and later, with a restrained
blue accent, semantic system surfaces, clear typography and generous spacing.
It has two persistent main screens: **Workout** for logging, history and graphs,
and **Settings** for appearance, haptics, the approved program, training setup and
gym inventory. Details expand inline; saved workouts open in the existing logger.
Small editing sheets and confirmation alerts stay local to these destinations.
The labeled tab bar preserves context, following [Apple HIG: Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars).

`AdaptiveWorkoutApp` composes `HomeView`, `HistoryView`, `SettingsView`, `SetupView`
and `SetEditor` under `native/AdaptiveWorkout/`. Practice remains hidden during
normal use; Debug builds can expose it explicitly with `--practice`. Hiding it
does not delete its separate records. New screens must use actual application
state, with no invented activity, readiness, progress or recommendation metrics.

## Appearance

Use SwiftUI semantic colors and standard system fonts, including Dynamic Type.
Primary text uses the primary role and supporting text uses secondary styling;
errors and confirmations must remain understandable through text, not color
alone. Native forms, pickers, toggles, disclosures and sheets provide the platform
interaction model. This migration does not require a custom imitation of another
Apple interface style.

System is the default and follows device appearance changes. Light and Dark are
intentional owner-requested overrides through `preferredColorScheme`. See
[Apple HIG: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode).
`AppModel` applies a choice after `SqliteAppearanceRepository` saves and reloads
the validated enum in the separate schema-1 `appearance.sqlite` store. Failed
loads/saves show an error. Appearance never changes workout, setup or
recommendation data.

## Type, layout and interaction

- Use semantic system font styles and allow important labels and explanations to
  wrap. Do not disable Dynamic Type to make a layout fit. See
  [Apple HIG: Typography](https://developer.apple.com/design/human-interface-guidelines/typography).
- Keep independent interactive targets at least 44 × 44 points and visibly
  separated. Give icon-only actions accessible names and show selected, disabled,
  error and pending states. See [Apple HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons).
- Respect safe areas, keyboard presentation and scrolling. Avoid fixed text
  heights and horizontal rows that cannot reflow at large text sizes.
- Group related content with sections and disclosures. Use a clear primary
  action; ordinary navigation, cancellation and editing should remain reversible.
- Retain standard SwiftUI focus, selection and accessibility behavior. Buttons
  embedded together in a Form row need an explicit style so one tap cannot trigger
  several row actions.
- Keep workout state and unfinished settings fields across tab/disclosure changes.
  Opening or canceling a picker/sheet must not save. Pending writes retain their
  exact action identity, block competing changes and offer a safe retry. Gym
  compare-and-save conflicts additionally expose an explicit reload of saved data.

Review narrow layouts, large text, both appearances, keyboard access and VoiceOver
focus/selected-state announcements. Visual similarity or a screenshot alone is
not accessibility acceptance. See [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

## Haptic feedback

Use short semantic system patterns following [Apple HIG: Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics).
`AppModel.cue` directly invokes UIKit selection, light impact and notification
feedback generators. There is no Flutter method channel, custom vibration,
audio requirement or haptic dependency in domain/storage code.

- Selection: a changed tab, Log/History mode, history/graph filter or metric,
  appearance, training-day/exclusion choice or equipment/set selector;
  acknowledged gym selection; clearing a rest timer.
- Light impact: an acknowledged new workout, or explicitly starting a rest
  countdown.
- Success: acknowledged set/correction, setup/preferences, gym edit, completion or
  deletion; a rest countdown completing while visible and foregrounded.
- Warning: destructive/early-finish confirmation and a newly selected pain status.
- Error: invalid submission or failed initiated save. Retry feedback follows the
  acknowledged outcome rather than the initial tap.

Loading, ordinary record navigation, typing, scrolling, canceling and reselecting
the same value stay quiet. Emit cues on explicit interactions and acknowledged
actions, never in view rendering or a general state-change listener. Feedback
failure cannot block an action; visible results and errors remain authoritative.

The **Haptic feedback** setting is on by default and retains the UserDefaults key
`adaptiveWorkout.hapticsEnabled`. App cues require both an enabled preference and
an active application. Muting suppresses app-requested feedback. UIKit and the
user's system settings determine hardware availability. `PrivacyInfo.xcprivacy`
declares app-only UserDefaults usage (`CA92.1`); no workout values are placed in
this preference. Tests can verify requested cues, gating and preference behavior;
perceived strength and comfort require a separate hands-on check.

## Program and setup presentation

The program preview preserves frozen prescriptions, session order, working-set
counts, repetitions, 2–3 RIR, paired rounds and rest scope. Superset rests follow
both exercises; unilateral rests follow both sides. Original weekday labels are
labels, not an automatic schedule. Thursday recovery remains no lifting, easy
walking, optional light mobility and the supplied 8,000–10,000 total-step target.
Approved alternative preferences and the disabled optional finisher must remain
visible without implying that an unverified variation is ready to execute.

Training setup saves explicit weekdays/duration, exclusions, draft or confirmed
physical equipment, exact available load settings and explicitly confirmed
starting loads. Missing capability/limitation assessments stay unknown. Equipment
revision changes can make old starting loads stale. User-reported work and
rehearsal attestations remain distinct from verified baselines; their append-only
storage API does not constitute a new live intake screen. Gym availability is a
location observation, not catalog approval, safety clearance or a starting-weight
recommendation. See [Gym profiles](GYM_PROFILES.md).

## Product boundaries

Display approved prescriptions and unavailable capabilities honestly. Views must
not calculate workout-generation/progression rules, enable catalog entries,
bypass safety/setup gates or treat manual/practice records as progression
evidence. Preserve explicit confirmations, pending-write locks, retries,
corrections, early-finish semantics and acknowledged deletion. A native interface
does not activate the standalone generated-workout backend.

## Session timers

Manual workouts show elapsed time from the saved start to the saved completion,
including early completion. Breaks, background time and time away are included;
this is elapsed time, not active exercise time. Reopening restores it from stored
timestamps with no schema change. Negative elapsed time after a clock change
displays as zero.

Each block offers an explicit countdown using its saved prescription's rest.
For supersets, start it after both exercises; for unilateral work, after both
sides. Starting a new countdown replaces the old one. It rounds remaining seconds
up, catches up when the app resumes and displays “Rest complete” at zero. It does
not automatically start, advance sets or authorize continuing.

Clear rest, workout changes, successful completion, screen disposal and app
termination clear the in-memory countdown. Switching tabs or viewing history
retains its deadline. A visible foreground completion cues once. A countdown
that elapsed while hidden or backgrounded stays silent on return. No background
alarm or notification is scheduled. Timer controls do not write workouts or
participate in deterministic training rules.

## History and graphs

Workout contains inline History and Graphs with a shared search and rolling
30/90/365-day or all-time filter. History groups finished manual sessions by local
start date, newest first, and opens a saved record within the same Workout screen.
Returning to history reloads repository data after corrections/deletions while
retaining filters and navigation context. Drafts and practice are excluded; early
finishes remain labeled.

Graphs show individual recorded working sets, oldest to newest, with load/reps
selection and an expandable exact-value list linked to the source workout. The
horizontal axis is set order, not elapsed time. Include only positive-repetition
sets explicitly marked valid; exclude warm-ups, skips, unknown/invalid/pain
records and missing values. Partition series by program version, template slot,
variant, exact setup, load convention and side. Bodyweight shows reps; assistance
is labeled as support, never strength gained. No estimated 1RM, volume, readiness
or recommendation metric is introduced. Support zero loads, one-point/constant
series and clear empty/error states. Search includes workout titles, prescribed
exercise names, recorded variants and setup labels.

The earlier interaction reference was [Flexify](https://github.com/brandonp2412/Flexify),
reviewed September 24, 2026, for searchable history, exercise graphs, metric
selection and source-workout navigation. This app's implementation uses its own
models, repositories and SwiftUI presentation; it includes no Flexify database,
chart package, assets or training algorithms. The upstream MIT notice is retained
in [the reference license](references/FLEXIFY_LICENSE.md).

## Verification and historical evidence

Current commands are in [Repository instructions](../AGENTS.md). Native package,
hosted iOS and interaction tests are separate scopes; use isolated fixture stores
and never reset production databases. Record actual build/test results, visual
checks and unresolved limitations in [Migration evidence](SWIFT_MIGRATION_STATUS.md).
The owner has deferred further physical-device checking at this migration
checkpoint. This document makes no final native test, VoiceOver, haptic-comfort,
installed-data transfer or device-acceptance claim.

Historical September 24 Flutter validation included successive 360/382/395-test
suites, separate appearance/haptics iPhone checks and light/dark screenshot
reviews. Those counts and captures belong to the previous implementation, whose
source and detailed evidence remain in Git history and the existing ADRs. They
are useful reference material, not proof that the native replacement passed the
same checks. Database reopen tests are not physical power-loss tests, and one
phone cannot establish coverage across every supported iOS version or device.
