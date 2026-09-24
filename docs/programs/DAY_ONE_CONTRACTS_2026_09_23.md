# Day-one contracts — September 23, 2026

> Subsequent update: the owner approved [warm-up W1–W7](../research/WARMUP_REVIEW_2026_09_23.md). Bodyweight rehearsal targets and continuation checks are now implemented as standalone v2 policies. Earlier descriptions below of the unresolved warm-up policy are historical; exact setup verification, catalog bindings and application integration remain pending.

Status: owner decisions below are approved in conversation. Engineering contracts are defined here for staged implementation. Only the standalone scheduling and duration-comparison policies are implemented in this change; persistence, application integration, alternative selection and load confirmation are not yet implemented. No catalog review is marked approved by this document.

## Approved decisions

- Schedule belongs to each user. The owner's five-session sequence is a program, not a universal Monday/Tuesday/Wednesday/Friday/Saturday calendar. Keep the ordered sequence and use explicit user-selected training weekdays. Changing weekdays does not reset the sequence. Thursday and Sunday are not globally prohibited.
- A missed day does not advance the program or create catch-up work. Ending a partial session explicitly advances to the next program session on the next training opportunity; completed work remains recorded. An interrupted draft remains resumable until explicitly ended. Advancing is not evidence of a completed exposure.
- A proposed increase or reduction requires explicit confirmation before becoming the working target for future workouts and warm-ups. Preserve the prior verification.
- Tuesday may use lying leg curls as an alternative to seated curls. Retain seated-first preference. Exclusions are user-editable, and replacements remain limited to approved alternatives; the owner explicitly chose this over generating entirely different programs. The earlier skip list is an owner preference, not a universal ban on these exercises. Exact IDs must be reviewed before populating those exclusions; do not infer broad restrictions from names.
- Duration is a user preference, such as 45, 60 or 75 minutes, not a fixed 45–60-minute eligibility limit. These examples are not an allowed-value range. Display an over-target estimate without blocking, dropping work or shortening rest. Automatic restructuring to match a shorter duration is not approved for the fixed program.
- Program provenance: created with ChatGPT, supplied and adopted by the owner. The owner reports that it is working and that they see results. This is self-reported experience, not an independently measured outcome. The owner is the sole initial test subject and intends to consult a trainer later. No trainer review is currently available.

These decisions supersede conflicting calendar, hard-duration and Tuesday-alternative text in earlier documents. They do not change prescriptions, P4/P5 thresholds or the existing safety/catalog gates.

## Research and its role

Owner follow-up: asked about preparation for pull-ups, hanging knee raises and ab-wheel rollouts, the owner reported basic stretching followed by the exercise, with nothing specific for those movements. This is a description of current practice, not approval of a no-rehearsal policy. Stretch type/duration remain unspecified; the bodyweight/assisted rehearsal contract remains open.

The owner subsequently reported three sets of ten pull-ups: two unassisted sets and one assisted set. The owner confirmed machine assistance and recalled approximately 70 lb for the third set. This is an approximate displayed assistance setting, not added external load; exact machine identity, setting and increments remain unverified. This mixed working-set pattern is not a warm-up protocol or a verified baseline. Current P7/P9 and exposure comparability assume a selected variation/setup; they do not yet define a mixed unassisted/assisted prescription within one slot. Preserve the report without promoting it into progression evidence; define explicit per-set variation/setup/assistance and comparability rules before enabling that pattern.

Ab-wheel rollouts are performed from the knees. This narrows the intended variation but does not verify range, baseline or rehearsal settings. For knee raises the owner confirmed that the rounded cushion is behind the back, with forearms supported on pads while lifting the knees: a supported captain's-chair setup. This differs from the hanging variation named in the original template. Exact equipment/catalog identity and a reviewed versioned slot binding remain pending; do not silently rewrite the historical hanging-knee-raise prescription.

Reviewed September 23, 2026:

- [ACSM's 2026 resistance-training update](https://acsm.org/resistance-training-guidelines-update-2026/) emphasizes individualization and consistent participation. It does not validate this specific split, prescribe our calendar behavior, or supply a long-absence threshold.
- [Gravl fitness-plan setup](https://gravl.ai/help/gravl-essentials-set-up-your-fitness-plan) exposes training preferences including session duration. This supports making duration a user setting, not a physiological rule.
- [Fitbod gym-profile settings](https://fitbod.me/blog/your-gym-profile/) allow users to choose workout duration and preferences. We adopt configurable preferences; its exercise-generation behavior is not imported into the fixed owner program.

The ordered queue, early-end advancement and advisory duration comparison are owner/product policies. Research does not establish their medical safety or effectiveness. Calendar planning does not authorize training on every available day or replace eligibility checks.

## Implemented planning boundary

`SessionPlanningPolicy` takes immutable ordered session IDs, ISO training weekdays, complete scoped sequence history and an explicit requested civil date. Dates use UTC midnight as a civil-date container; the caller must extract the user's local year/month/day before constructing it, rather than converting a local midnight instant to UTC. Supported civil years are 1–9998 to keep a seven-day search representable.

History uses zero-based contiguous sequences, unique session IDs for each occurrence, an exact template reference and `active`, `completed` or `endedEarly` state. Only the final occurrence may be active. Misses have no sequence entry; an ended occurrence advances once, including cycle wrap. History input ordering does not affect the result. Missing history is not an empty first-time history. Repositories must scope history to the exact profile/program and supply all occurrences; the pure policy cannot prove omitted tail records are absent.

Results contain `session-planning-v1`, a reason, next template ID and eligible calendar date where applicable. Reasons are `next_session`, `resume_session`, `schedule_required`, `required_input_missing`, `invalid_input`, and `invalid_history`. An empty weekday selection requests scheduling setup; a missing selection is invalid. An active draft is returned for resumption without scheduling a second workout. The requested date is the earliest permissible planning date supplied by orchestration; after a terminal action it must be later than that workout's local date. This prevents silently creating a same-day second workout. Same-day retry returns the existing action receipt.

`compareSessionDuration` accepts positive preferred minutes and a nonnegative estimate in seconds. Missing estimates return `estimateRequired`; invalid preferences or negative estimates return `invalidInput`. Exact equality fits. An excess is advisory, never a generation gate. The estimate must eventually include walking, rehearsals, both sides, work, rests and transitions. No rep tempo or transition constant is invented here.

### Worked acceptance examples

| Explicit input | Expected behavior |
| --- | --- |
| Sequence A/B/C, selected Tue/Thu/Sun, request Wed Sep 23, no history | A on Thu Sep 24 |
| Same history, repeated missed days | A remains next; no catch-up sets |
| A ended early | B next; A actuals retained, incomplete evidence retained |
| A draft interrupted | Resume A; no new occurrence |
| Final session ended early | Wrap to first template once |
| Empty selected days | Schedule setup required |
| Missing history, duplicate sequence, unknown template | No planning result |
| Same inputs with reversed history/weekday ordering | Same output |
| Target 45 min, estimate 45 min | Within preference |
| Target 45 min, estimate 45 min 1 sec | Advisory exceeds-preference result |
| Target 90 min | Accepted preference; no 75-minute ceiling |
| Missing duration estimate | Unknown estimate, not a claim that it fits |

## Data contracts for subsequent implementation

All persisted objects carry schema version, stable ID, profile ID and revision. IDs are opaque and bounded; collections preserve duplicates until validation. Unsupported versions, invalid units, cross-profile references and stale revisions reject the action without changing durable data. Timestamps are explicit UTC instants; calendar dates and timezone context are separate. Health/workout payloads must not enter production logs.

| Record | Required content and invariant |
| --- | --- |
| Training preferences | Profile/revision; ordered program/version; selected ISO weekdays; preferred duration in positive whole minutes; exact persistent exercise exclusions. No owner schedule copied silently into another profile. |
| Equipment setup | Exact machine/variation/setup identity; unit and load convention; capability verification references; ordered available work and rehearsal settings. Per-dumbbell, plates-only, displayed-machine and assistance quantities remain distinct. |
| Baseline revision | Exact progression context; verified load; verification actor/time/reference; predecessor revision when replacing a target. No automatic promotion of practice/manual actuals. |
| Proposed load change | Recommendation ID; previous baseline revision; candidate load; exact context; rule version; evidence IDs/revisions; equipment/constraint/safety revisions. Proposal is not a verified target. |
| Target confirmation | Explicit user action ID/time; matching proposal and expected baseline revision; fresh current checks; resulting baseline revision. Reject stale inputs and recompute the proposal. Cancel/no response keeps the prior valid target. |
| Generation request | Profile, program and rule versions; catalog/schema/taxonomy/digest; requested civil date and timezone; preferences, safety, constraint, equipment, baseline and history revision references; explicit estimate-model version if available. One consistent read snapshot. |
| Recommendation | Immutable input references; ordered slots/variants/set prescriptions/warm-ups/rests; baseline or confirmed target references; duration preference and estimate/status; stable reasons/evidence; generation status. Unknown duration does not mean safe/eligible. |
| Session occurrence | Profile/program/template/recommendation IDs; unique monotonic sequence; draft/active/completed/ended-early state; started/ended instants and civil dates; expected revision. Terminal action and queue advancement occur atomically exactly once. |
| Actual and correction | Exact occurrence/slot/set/side/setup/convention; reps/load/RIR/validity/skip/warm-up status; immutable original and audited revisions. Read current corrected values once, retaining incomplete intervening exposures. |
| Safety report/restriction | Originating recommendation and exact affected context; immutable report identity; review/reset evidence; active status independent of whether the session ended. Correcting an entry never silently clears a restriction. |

Confirmation creates a new explicit verified target revision only after current checks pass. Subsequent warm-ups use that confirmed target. Two qualifying exposures at the new exact target are required for another increase/reduction; old-weight exposures remain in history and cannot form a new-target streak. A historical correction makes dependent unstarted recommendations/proposals stale; it does not rewrite an active prescription or silently erase a prior confirmation. Fresh safety/equipment failure blocks use of that target. The existing progression policy remains candidate-only until this orchestration is built.

## Storage decision

Preserve both practice and manual-program databases and their current v1 prescriptions. Add a separately versioned adaptive-workout store using the existing SQLite dependency; no new package. Keep preferences, verification revisions, recommendation snapshots, actuals, action receipts, sequence state and invalidation references together there so session actions can be transactional. A stale expected revision rejects a write; a repeated action ID with the same payload returns the original receipt, and a changed payload conflicts.

Readers dispatch by stored schema/program version. Never change a stored v1 prescription when adding Tuesday alternatives: publish a new binding/program version after historical readers exist. Failed migrations roll back and preserve the original database; newer unsupported schemas remain unopened rather than deleted. Export/deletion must cover all three stores. Exact export format and deletion-recovery protocol remain open; arbitrary import is out of scope.

## Catalog coverage and review packet

Every row below is pending exact source identity, controlled-taxonomy mapping and applicable reviews. These are template labels, not catalog IDs. Shared variations may reuse a reviewed catalog record, but each slot retains its own prescription and progression context. No approximate name matching.

| Variation needing coverage | Program slots |
| --- | --- |
| Incline dumbbell press | Monday 1 |
| Neutral-grip lat pulldown | Monday 2 |
| Incline machine press | Monday A1; Friday A1 |
| Chest-supported row | Monday A2 |
| Cable lateral raise | Monday B1; Wednesday A1; Friday B2 |
| Cable chest fly | Monday B2 |
| Leg press | Tuesday 1 |
| Leg extension | Tuesday A1; Saturday A1 |
| Seated leg curl | Tuesday A2; Saturday A2, preferred |
| Lying leg curl | Tuesday A2; Saturday A2, alternative |
| Machine calf raise | Tuesday B1; Saturday B1 |
| Cable crunch | Tuesday B2 |
| Machine seated shoulder press | Wednesday 1, preferred |
| Dumbbell seated shoulder press | Wednesday 1, alternative |
| Reverse pec deck | Wednesday A2 |
| Cable curl | Wednesday B1 |
| Overhead cable triceps extension | Wednesday B2 |
| Hanging knee raise | Wednesday final |
| Unassisted pull-up | Friday 1, preferred with baseline |
| Assisted-machine pull-up | Friday 1, alternative with own baseline |
| Seated cable row | Friday A2 |
| Single-arm cable pulldown | Friday 3, both sides |
| Machine chest fly | Friday B1 |
| Hack squat | Saturday 1 |
| Ab-wheel rollout | Saturday B2 |

Each review packet requires:

1. Exact wger base/translation IDs and UUIDs, pinned source bytes, attribution/licenses and modifications; no exercise media.
2. Exact internal identity and slot bindings, laterality, load semantics, equipment requirements and range/setup assumptions. Resolve vague labels such as calf machine, chest-supported row and cable fly before enabling.
3. Controlled movement/muscle/capability/limitation mappings with claim-level supporting references; record taxonomy gaps instead of coercing an unsupported movement.
4. Product, science, safety, equipment and license review records with status, reviewer ID, UTC timestamp and evidence reference. AI assistance and owner self-report must be labeled; neither is fabricated independent review.
5. Verified local equipment and own baseline for each alternative, including lighter rehearsal settings. Pull-ups, knee raises and ab-wheel rehearsal rules remain unresolved.
6. New immutable catalog/program-binding versions, canonical manifest/digests, disabled reasons and complete coverage tests. Unreviewed records stay disabled under the existing catalog contract.

## Open decisions and owners

| Item | Owner / next action | Needed before |
| --- | --- | --- |
| Actual selected weekdays and preferred duration | User, through future setup; no universal default inferred | Calendar/UI integration |
| Long absence and baseline reconfirmation | Owner with reviewed proposal; no inactivity percentage or arbitrary cutoff | Real next-session generation after a gap |
| Bodyweight/assisted rehearsals | [W1–W7 approved](../research/WARMUP_REVIEW_2026_09_23.md), domain targets/continuation implemented; exact setup verification, applicable catalog review and application integration remain pending | All five sessions activated |
| Rep/transition duration estimates | Owner supplies observations; engineering defines an explicit estimate model | Honest session estimates |
| Exact equipment identities/settings/baselines | Owner verifies privately; never committed as personal fixtures | Enabled real prescriptions |
| Catalog science/safety review evidence | No qualified reviewer currently named; explicit unresolved dependency | Catalog activation |
| Symptom return/reset wording | Qualified clinical review under existing safety contract | Re-enabling symptom-restricted path / outside testing |
| Export format and deletion scope/recovery | Engineering prepares concrete options for owner | Data ownership implementation |

Day 1 remains in progress while these items are unresolved. Trainer involvement is deferred by the owner; no review completion date is promised. Continue software contracts and synthetic tests without relabeling the real adaptive backend as complete.
