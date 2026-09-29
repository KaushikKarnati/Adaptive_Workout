# Interface design

The maintained interface is native SwiftUI on iOS 17 and later. The September 28
Stitch design uses amber accents, Space Grotesk, pale surfaces and white cards.
Four persistent destinations provide **Workout**, **Plan**, **History** and
**Profile**. Workout contains the dashboard, manual logger and committed summary;
Profile retains appearance, haptics, program details, setup and gym inventory.
The Stitch section below records reference-to-data differences and validation.

`AdaptiveWorkoutApp` composes `HomeView`, `HistoryView`, `SettingsView`, `SetupView`
and `SetEditor` under `native/AdaptiveWorkout/`. Practice remains hidden during
normal use; Debug builds can expose it explicitly with `--practice`. Hiding it
does not delete its separate records. New screens must use actual application
state, with no invented activity, readiness, progress or recommendation metrics.

## September 25 mockup scope

The owner requested the proposals in sections 1 and 2 of **Adaptive Workout
Mockups.pdf**, with the section-2 timer design adapted to native iOS. The following
mapping describes the current interface, not a claim of feature acceptance or
approval of the future recommendation engine.

| Mockup | Native presentation and boundary |
| --- | --- |
| 1a | One numbered five-session chooser; selecting the active draft resumes it. Switching templates retains the existing early-finish confirmation. |
| 1b–1c | Saved draft sets, completed-exercise summaries that reopen for correction, the next unrecorded set highlight, warm-up entry and a native set-entry sheet with exercise-valid load conventions. Rest starts explicitly. |
| 1d–1e | Finished manual history and descriptive graphs retain search, date filters, exact-value disclosures, zero baselines and dashed session boundaries. |
| 1f–1g | Inline appearance/haptic settings and a read-only program preview preserve prescription and setup-review boundaries. |
| 1h–1i | Light and Dark use native semantic surfaces and system text roles rather than fixed mockup color values. |
| 1j–1k | Cards, Table and Focus are selectable logging layouts. Focus shows one exercise, recorded-set progress, navigation and the next unrecorded-set action; All sets returns to Cards. |
| 2a–2b | A next-in-plan manual workout card explains its ordering and unavailable engine capabilities; Time available saves an advisory duration or No time limit. |
| 2c | Change exercise exposes the five exception choices. Persistent exclusions save an exact variation; ordinary replacement choices explain why automatic substitution remains unavailable. Pain opens the existing actual-set editor with Pain selected. |
| 2d | My gym includes availability filters, status words/symbols, confirmed category count, checked dates and saved observation notes. |
| 2e | Last trained has a persisted, off-by-default opt-in. Enabling it currently shows a review-unavailable screen: no production reviewed muscle-area mapping is wired in, so no area counts are displayed. |
| 2f–2g | A separate floating rest/workout timer capsule uses native glass or material in both appearances above the system tab bar. Previous setups show labeled valid history; “same setup” appears only when the current record supplies an exact comparable context. |

`AppModel` saves Cards/Table/Focus and the Last trained opt-in in local
UserDefaults under `adaptiveWorkout.loggingLayout` and
`adaptiveWorkout.lastTrainedEnabled`. These are presentation preferences, not
workout evidence. The same section-2 timer capsule is used across logging layouts;
Focus does not introduce a second timer or automatic rest transition.

The next-in-plan shortcut is a pure manual-history projection: an existing draft
wins, otherwise the latest finished or explicitly ended-early session advances
through the approved plan order. It does not consult weekdays, infer recovery or
invoke generated-workout orchestration. Completed-record navigation offers Next
workout to return to the card. Day names remain original plan labels.

The duration sheet offers 30/45/60/75 minutes, an existing custom duration and No
time limit. It saves the advisory preference locally; it neither estimates a
session duration nor drops exercises, changes rest or enforces a cutoff. Workout
and Settings share one setup presentation model so duration/exclusion changes use
the same repository-backed saved state while retaining unrelated form drafts.

Equipment unavailable opens the gym checklist; Cannot perform and Replace for
today do not manufacture substitutes. Do not recommend again saves an explicit
variation exclusion without altering the manual prescription or past records.
Pain remains a separate actual-entry route: only an accepted saved Pain record
invokes the existing manual exercise-stop behavior. Opening/canceling the sheet
is not a persisted safety event. This interface adds no clinical approval,
symptom classification, escalation advice or return-to-training policy.

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

`WorkoutTimerCapsule` in `WorkoutComponents.swift` groups rest status, remaining
time, total elapsed time and Clear rest. It uses the opaque Stitch card and amber
progress track above the persistent navigation. At accessibility text sizes it
uses a compact labeled countdown and clear button. Both variants use the same
existing deadline; no timer state or training rules depend on this styling.


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

## September 28 Stitch redesign

The owner supplied four light screens in `stitch_adaptive_workout_ios_redesign`:
Workout dashboard, active workout/rest/error state, descriptive history and workout
completion. Their rendered PNGs and HTML colors take precedence over conflicting
palette prose in the accompanying DESIGN.md. These files are visual references,
not approval for new training rules, analytics or integration claims.

`StitchDesign.swift` supplies the #F9F9FF canvas, white cards, #F3F3FA/#EDEDF5
metric panels, #894D00 amber actions, peach badges, typography and completion
components. Space Grotesk is bundled under its SIL Open Font License in Resources;
font registration occurs at launch with no network request or package dependency.
System/Light/Dark still use the saved appearance preference. Dark is an adaptation
because no dark Stitch reference was supplied. Custom fonts retain Dynamic Type.

The persistent navigation now has Workout, Plan, History and Profile. Workout
starts at a dashboard and explicitly resumes its saved draft. Plan shows the
approved prescriptions. History is a direct destination with Workouts, Recorded
trends and Last trained. Profile retains appearance, haptics, program details,
training setup and gym inventory. The workout and profile views remain mounted to
preserve timer deadlines and unfinished settings fields across navigation.
History source links select the record in Workout. Completion displays only after
an acknowledged terminal action, with a separate route to correct saved sets.

The active workout retains Cards/Table/Focus, warm-up entry, explicit rests,
manual exceptions and the original write/retry locks. The rest dock uses an opaque
rounded white card, large tabular countdown and amber progress track. It does not
claim Live Activity integration, background synchronization or automatic pacing.
Returning to the dashboard disarms foreground completion haptics while retaining
the in-memory deadline. Reopening recomputes the countdown from its deadline.

### Reference-to-data differences

- Greeting, dates, plan names, exercises, counts and elapsed times use application
  state. Alex, MetroFlex, sample workout names and sample kg loads are not seeded.
  Facility context links to saved gym/setup controls instead of inventing a gym.
- Working-slot record counts include explicit skips where labeled. Work-record
  counts exclude warm-ups/skips. The approved plan's set counts are unchanged.
- Time available is an advisory saved preference, not a generated duration estimate.
- History uses the existing exact-context load/repetition series. No estimated
  1RM, tonnage/PR delta, overload, muscle stimulus or recovery claim is introduced.
- Completion shows elapsed time, records and per-exercise work/warm-up counts.
  Active/rest time splitting, session RPE, session notes, sharing and automatic
  routine adjustment have no approved contracts and are not presented as working
  actions. Saved completion needs no second misleading "Save" action.
- Errors appear only for actual failed/unacknowledged writes; no mock IO_ERR_09 or
  "0 Data Loss" guarantee. Pain retains the explicit actual-set editor and existing
  stop rule; the design's new symptom categories do not change safety policy.
- iOS safe areas, native sheets and SF Symbols remain platform-native. The four
  supplied light references guide visual hierarchy; pixel identity across devices,
  Dynamic Type settings and different real data is not asserted.

At accessibility text sizes the persistent navigation uses icon buttons with full
accessibility labels, the header shortens its title, and the dock uses a compact
labeled time plus a 48-point Clear rest button. Content typography continues to
scale. This avoids consuming the entire workout viewport with fixed controls.

Physical-device navigation refinement (2026-09-28): switching main tabs dismisses
the keyboard while preserving unsaved setup fields. The device regression checks
entry before/after navigation, saving, and persistence after relaunch.
