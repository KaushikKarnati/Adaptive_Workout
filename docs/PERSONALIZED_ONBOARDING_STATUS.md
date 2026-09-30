# Personalized onboarding implementation — September 30, 2026

Status: profile/onboarding and program-draft foundation implemented. The complete
adaptive-training plan is **not complete**. No new review approval, baseline,
rehearsal attestation, equipment verification or production generation is created.

## Implemented

- Ten resumable native setup screens: welcome, goals/experience, schedule,
  environment/inventory/units, reported constraints, structured program draft,
  equipment requirements, baseline/rehearsal requirements, optional Health
  categories, and review. Setup is available from Home and Settings. Fresh normal
  stores open setup automatically; isolated test stores retain explicit entry.
- Fresh local profiles have no owner goal, gym, schedule, program, limitations or
  evidence defaults. Existing owner workout records retain `local_owner`; normal new-user
  manual logging and setup preparation use their new local profile identity. No history is reassigned.
- Separate schema-1 `user_profiles.sqlite` contains immutable profile revisions.
  Saves validate, compare expected revisions, transact, read back, and tolerate
  exact retries. Unknown schemas/corrupt data fail without clearing records.
- Structured drafts edit session/exercise order, sets, rep ranges, rests, pairing
  labels and locks. The owner program must be explicitly selected. Draft names
  are manual labels, not catalog identities. Edited drafts are **not executable**
  replacements for the current owner-program manual logger. No actual or saved
  prescription is changed by editing.
- Preference/program export to JSON and explicit restore into the current
  profile as a new revision. Restore validates size/schema/content, retains the
  current profile identity, and does not import evidence, history or Health data.
- Optional read-only HealthKit adapter for workouts, sleep, HRV, resting heart
  rate, steps, active energy, body mass, body-fat percentage and lean mass.
  Explicit connect/refresh requests selected categories, captures a 30-day
  replacement snapshot and retains raw source identities/stages/units. Snapshot
  validation rejects duplicate IDs, malformed/future/nonfinite records and
  excessive counts. Sleep overlaps are exposed rather than summed.
- Health samples are memory-only and cleared on screen/model disposal or explicit
  clear. Refresh failure keeps the previous in-memory snapshot. Missing data
  does not claim denied read permission or full recovery. No samples enter
  workout evidence or change prescriptions. HealthKit entitlement/purpose text
  is added; signed physical-device authorization remains unverified.

## Boundaries and remaining work

Equipment and baseline steps display unresolved requirements; authoritative
capture for this new profile flow is not implemented. Saving the final preference
review is not adaptive activation or completed full-program verification.
All activation blockers remain visible, even after all ten screens are saved.
Manual logging remains available after pausing setup.

The following parts of the requested plan remain unfinished:

1. Real catalog product/science/safety/equipment/license reviews and exact bindings.
2. Profile-scoped authoritative safety/setup/baseline/rehearsal capture and complete
   selected-program verification; legacy setup preparation remains separate.
3. Atomic multi-store source capture, revision checking, generation persistence,
   target confirmation, and production controller registration.
4. Executable edited programs, approved adaptive selection/restructuring and lock
   conflict evaluation. Draft locks are stored intent, not an active engine rule.
5. Reviewed recovery policy, readiness interpretation, shadow evaluation and
   metric-by-metric activation. Imported workout semantic deduplication, source
   overlap reconciliation and durable health refresh/deletion handling must be
   completed before those observations affect any rule.
6. Comparable PR/volume/muscle insights, verified plate breakdowns and data export
   covering all training stores. Current export covers profile/draft only.
7. Multiple environment editing/selection inside onboarding, guided confirmation
   and supported-profile eligibility. The current environment screen stores one
   active label/inventory; existing gym profiles remain separate.

New profiles must not use the legacy owner setup as their evidence. No selected
Health metric may affect prescriptions until its policy is reviewed. Goal and
experience labels do not supply training mappings. Supporting more user inputs
is not approval for a broader tester population.

## Verification

Current-run commands/results are recorded in SWIFT_MIGRATION_STATUS.md. Tests
use disposable fixture databases. Physical-device Health authorization, airplane
mode, real-data transfer, VoiceOver, Dynamic Type and one-handed acceptance must
be recorded separately; package/build results do not establish them.
