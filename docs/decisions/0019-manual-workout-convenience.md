# 0019 — Manual workout convenience and local alerts

Status: owner-authorized September 25, 2026 feedback implemented in native UI.

The owner requested repeating the previous set, both rest and workout
notifications, automatic current-set advancement through supersets, home after
completion, removal of the exact-setup prompt, and wger exercise data.

- Copy previous set fills variation, load convention, exact weight and reps from
  the closest earlier non-skipped set of the same exercise, side and category.
  It does not copy RIR/validity or save/complete anything automatically.
- The set editor shares permitted load conventions with existing validation,
  instead of offering choices that the selected exercise cannot save.
- Empty setup labels are accepted only in manual logging. Existing labels and
  canonical payloads remain unchanged; corrections retain the label unless the
  variation changes. Unknown setups do not imply cross-session comparability.
  Verified setup, generated histories and training gates are unchanged.
- The current working target follows block/paired-round/side order, advancing
  only after acknowledged actuals or explicit skips. Pain stops and explicit
  completion remain enforced. Normal/early completion deselects the workout only
  after save/readback, including retries; finished history remains editable.
- Native local alerts are opt-in. Rest alerts use the current countdown deadline;
  replacements, clearing, finishing and relaunch cancel former requests. An alert
  may still arrive while the app is terminated. Workout reminders use explicit
  user-chosen weekdays and time, without program scheduling or automatic starts.
  Permission denial/failure remains visible; fixture tests never schedule real
  alerts. No account, network service or additional dependency is introduced.
- A pinned wger name/attribution reference is separately bundled for offline
  browsing. No instructions, media, program bindings or catalog selection are
  activated. See `docs/catalog/WGER_REFERENCE_2026_09_25.md`.

Notification settings are stored in the app's existing isolated UserDefaults
boundary. Core records retain existing repositories, integer load values,
receipts, audits and profile separation. Device alert delivery, accessibility
acceptance and haptic comfort are separate from package/simulator verification.
