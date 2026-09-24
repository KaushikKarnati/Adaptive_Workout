# ADR 0011: Approved bodyweight warm-ups and explicit continuation

Status: accepted after the owner approved the researched W1–W7 policy in conversation.

## Decision

Implement `owner-warmup-v2` as standalone pure domain policies. Retain v1 external-load calculation and expose its identical values under a v2 result, without changing historical v1 behavior. Five-minute walking and optional personal stretching remain composition/presentation requirements.

Bodyweight rehearsal targets carry exact profile/slot/exercise/setup context, a verification reference, reps/rest, and an assistance quantity or range reference where applicable. All are non-working sets. Identifiers are nonempty printable ASCII without spaces, at most 128 characters. Verification references identify immutable revisions; a changed setup requires a matching new verification. Repository/application code must supply only current, reviewed verification data and fresh guarded eligibility for every involved variation.

Machine assistance is a separate positive integer in millionths of a pound, selected exactly from a required unique verified ladder; zero is represented by the separately confirmed unassisted variation instead. Settings are validated before set conversion, and their order has no effect. No guessed bodyweight or assistance percentages. Core ranges are opaque verified setup references. Rollout containment is an explicit verified relationship; no ordering or physical distance is inferred from reference strings. Supported knee raises require the same working and rehearsal range reference. Exact easy assistance and comfortable rollout endpoints remain owner verification inputs.

The continuation decision requires current permitted checks, completed rehearsal, explicit easy/controlled feedback, elapsed rest at least the prescribed rest, and explicit continuation. Symptoms take precedence; interruption or unknown interruption status requests preparation review. The returned permission concerns only the next planned action. Callers must bind all execution input to the exact saved target; this function does not infer that relationship or persist execution state.

## Consequences and boundaries

No widgets, clocks, network, packages or database schema changes. Targets and verification collections are immutable; missing, invalid and mismatched inputs fail closed. The domain does not enable catalog records or the mixed working-set progression contract. Production orchestration must preserve once-per-session walking, once-per-movement rehearsals, both superset rehearsals before working rounds, actual duration, duplicate-action receipts, safety reports and resume state. Those integration tasks are not claimed complete by standalone policy tests.

See [approved evidence review](../research/WARMUP_REVIEW_2026_09_23.md). Exact numeric defaults are owner-approved policy, not scientifically proven optima.
