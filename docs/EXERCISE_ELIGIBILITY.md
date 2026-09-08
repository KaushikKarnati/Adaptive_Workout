# Exercise Eligibility and Safety-Filtering Specification

Status: V1 structural product and engineering contract approved and implemented with synthetic tests on 2026-09-08. It is not connected to workout generation. Exercise-specific mappings, verified equipment data, clinical wording, and training-science rules remain separately gated.

## Purpose

This specification defines a deterministic, fail-closed boundary for deciding whether a reviewed catalog exercise may proceed to later ranking. It separates two concerns:

1. `SafetyGate` handles an already-classified pain or concerning-symptom event and active safety restrictions.
2. `ExerciseEligibilityFilter` applies explicit hard feasibility constraints to a validated catalog and candidate set.

This stage does not choose, rank, order, substitute, or prescribe an exercise. An eligible exercise is only permitted to enter a later, separately approved ranking stage; eligibility is not a claim that the exercise is optimal, medically safe for every person, or suitable for a complete workout.

## Existing policy boundary

The following repository decisions control this contract:

- Safety and uncertainty take precedence over completing a workout.
- Pain or a concerning symptom follows a separate safety path, stops the affected exercise, is preserved for review, causes no automatic substitution, and causes no load or volume increase.
- Missing or invalid safety information produces an explicit no-recommendation result.
- Only a manifest-valid, integrity-checked internal catalog may reach the domain.
- A catalog entry is selectable only when it is enabled and all product, science, safety, equipment, and license reviews are approved.
- Equipment, capabilities, limitations, and exercise exclusions are explicit inputs. Names, prose, diagnoses, facility names, and source metadata are not inferred into constraints.

The current U.S. Department of Health and Human Services guidance states that activity should be appropriate to a person's current fitness and health context and that people with symptoms or chronic conditions may need individualized professional guidance. This supports a conservative application boundary, but it does not supply executable symptom definitions or exercise-specific rules for this app. Those require qualified clinical review before outside testing. Source reviewed 2026-09-08: [Physical Activity Guidelines for Americans, second edition](https://odphp.health.gov/sites/default/files/2019-09/Physical_Activity_Guidelines_2nd_edition.pdf).

## Position in the engine

```text
Application input validation
  -> validated catalog and explicit constraint snapshot
  -> SafetyGate
       -> safety_stop, or
       -> normalized hard constraints
  -> ExerciseEligibilityFilter
       -> eligible candidate set, or
       -> constrained_no_candidate
  -> future ranking, composition, substitution, and prescription stages
```

Both stages are pure domain components. They must not read widgets, repositories, the wall clock, network state, HealthKit, live wger data, locale, unordered iteration, or hidden mutable state.

## Input contract

Every request includes the following immutable values. Omission of a required object is different from an explicitly empty collection.

### Version and catalog identity

- `eligibilityRuleSetVersion`: supported semantic version.
- `schemaVersion`: must match the validated manifest.
- `catalogVersion`: must match the validated manifest.
- `taxonomyVersion`: exactly the supported catalog taxonomy version.
- `catalogContentSha256`: must match the validated manifest.
- `constraintSnapshotSha256`: lowercase SHA-256 of the canonical explicit constraint snapshot used by this request. The guarded evaluator recomputes this value and rejects a mismatch; callers cannot choose the identity used by the safety gate.
- `catalog`: a complete validated internal catalog; raw wger or import models are forbidden.
- `candidateExerciseIds`: explicit unique internal exercise IDs, from 0 through the catalog entry-count limit.

The evaluator receives a preconfigured catalog validator from the trusted application composition boundary. Its import reference time and evidence-host policy are not request fields. This keeps validation reproducible without allowing a request to advance the validation clock or replace catalog policy.

The constraint snapshot contains only these normalized structural inputs: equipment inventory (`equipmentId`, `quantity`, and sorted item capability IDs), temporary equipment IDs, supported and unsupported functional-capability IDs, limitation IDs, persistent exercise exclusions, and request-scoped exercise exclusions. Map keys and every set-valued list are sorted before canonical JSON serialization and SHA-256 calculation; inventory rows are sorted by equipment ID and then by canonical row bytes. Candidate IDs, catalog identity, safety restrictions, names, and presentation data are excluded. Including safety restrictions would make their own identity circular.

Candidate-set construction is outside this specification. Passing every selectable catalog ID is allowed. Passing a subset does not authorize the filter to infer why those candidates were chosen.

### Equipment availability

- `equipmentInventory`: required map keyed by controlled equipment ID.
- Each present item has an integer `quantity` from 1 through 8 and a unique set of controlled equipment-capability IDs.
- `temporarilyUnavailableEquipmentIds`: required, possibly empty, unique set scoped to this request.

An explicitly empty inventory means no equipment is reported available. A missing inventory is invalid input. Duplicate equipment records, unknown IDs, invalid quantities, and capability IDs attached to an unknown equipment item are invalid; records are never merged implicitly.

Temporary unavailability overrides the ordinary inventory for the current workout and resets when that workout ends. This behavior was approved by the product owner on 2026-09-08. Permanent equipment changes are maintained separately in the user's equipment profile.

### Functional capabilities

- `functionalCapabilityAssessment`: required object containing disjoint, unique `supportedIds` and `unsupportedIds` sets.
- A controlled capability in neither set is `unknown`.

This tri-state representation prevents absence from being silently interpreted as support. A missing assessment invalidates the request. The approved product policy is that an exercise requiring an `unsupported` or `unknown` capability is ineligible without invalidating unrelated candidates. The source and user experience for establishing these states remain unapproved.

### Limitations and exclusions

- `limitationAssessment`: required object containing an explicit, unique set of controlled limitation-conflict IDs. An empty set means the user explicitly reported none; it is not medical clearance.
- `persistentExerciseExclusionIds`: required, possibly empty, unique set of internal exercise IDs.
- `requestExerciseExclusionIds`: required, possibly empty, unique set of internal exercise IDs.

Unknown or stale taxonomy and exercise references invalidate the request. The application must not infer a limitation ID from a diagnosis, health record, pain report, exercise name, or another tag.

### Safety state

`SafetyGate` receives a required, versioned safety state that is one of:

- `clear`: no active safety event or unresolved restriction applies to this request.
- `stop`: an already-classified pain or concerning-symptom event applies to the affected exercise context.
- `restricted`: one or more previously preserved, unresolved `SafetyRestriction` records apply.

The initial eligibility rule-set and safety-state schema versions are both `1.0.0`.

A persisted `SafetyRestriction` identifies the exact exercise-and-constraint combination using the exercise ID, canonical constraint snapshot or its integrity-linked version, catalog version, taxonomy version, eligibility-rule version, originating recommendation reference, regression-test reference, review state, and review reference. The pure eligibility input receives a validated active-reference projection containing all of those audit links; its only accepted review state is `unresolved`. The references are nonempty printable ASCII values of at most 128 characters. An applicable safety-stop result repeats the non-sensitive audit references so the decision remains traceable; the persisted restriction remains the authoritative record. Persistence, evidence content, and the workflow that removes a resolved restriction remain outside the domain filter. Neither representation contains diagnosis or free-form symptom text in the eligibility request. A restriction remains active until the cause is corrected, its regression test passes, the affected deterministic simulations pass, and the path is reviewed. For the private test, the product owner may approve a software or data correction; symptom-specific restrictions also require qualified clinical review before re-enablement or outside testing. This policy was approved by the product owner on 2026-09-08.

The gate consumes an already-classified state. It must not parse symptoms, decide whether a report is medically concerning, provide a diagnosis, or infer a limitation.

## Request validation

Validation occurs before either domain stage. Any of the following returns `invalid_input` or `catalog_unavailable` and no candidates:

- Missing required input or unsupported rule-set version.
- Manifest, entry-count, schema, taxonomy, provider, or integrity failure.
- Catalog version values that do not match the request.
- Any enabled catalog entry that fails the approved catalog contract.
- Duplicate candidate, inventory, capability, limitation, exclusion, or restriction identifier.
- Unknown catalog, taxonomy, equipment, capability, limitation, or exercise identifier.
- Invalid quantity, malformed version, or non-canonical digest.
- A supplied constraint digest that does not match the evaluator's canonical digest of the actual explicit constraints.
- A stale safety reference that has not been explicitly migrated to the active catalog and taxonomy versions.

The runtime must not skip a malformed enabled entry and continue with a partial catalog. Validation must observe duplicates before constructing set or map types that would erase them.

## SafetyGate decision table

| Input state | Result | Required behavior |
| --- | --- | --- |
| Invalid or missing safety state | `invalid_input` | Return no recommendation and do not run eligibility. |
| `stop` | `safety_stop` | Stop the affected exercise, preserve the report, block automatic substitution, and block any load or volume increase. After acknowledging the stop, the user may end the workout or continue only already-planned, unaffected exercises. |
| Applicable unresolved restriction | `safety_stop` | Keep the affected path disabled and do not run ordinary replacement for that path. |
| `clear` with no applicable restriction | `continue` | Pass normalized hard constraints to eligibility. |

The product owner approved the limited continuation behavior on 2026-09-08. Continuing does not authorize a replacement, a new recommendation, or any increased load or volume. Exact symptom definitions, user-facing safety language, escalation instructions, and return to the affected exercise require qualified clinical and product review.

## Eligibility rules

After successful request validation and a `continue` safety result, evaluate every candidate independently. All rules are conjunctive: failure of any rule makes that candidate ineligible, and no later rule may reinstate it.

### Catalog selectability

The candidate entry must be `enabled` and all five required reviews must be `approved`. This is checked defensively even when the catalog boundary already derives selectability.

### Exact exercise exclusions

A candidate is ineligible when its internal ID appears in either the persistent or request-scoped exclusion set. Persistent exclusion takes precedence for primary display when both apply, while both facts remain in the audit result.

The product owner approved these exception policies on 2026-09-08:

- “Replace for today” excludes the exact exercise for the current workout and resets when that workout ends.
- “Do not recommend again” excludes the exact exercise until the user manually restores it in Settings.
- “Cannot perform this movement” stops the current exercise and presents a short, structured capability-or-limitation follow-up. An explicitly selected controlled constraint follows its normal eligibility scope. If the user supplies no additional constraint, only the exact exercise is excluded for the current workout.

The follow-up must remain short and may be skipped. It must not infer a broader limitation from the button label or free text.

### Limitation conflicts

A candidate is ineligible when:

```text
candidate.exclusionTagIds ∩ limitationAssessment.ids is not empty
```

Only exact controlled IDs participate. An unrelated limitation does not affect the candidate.

### Functional capabilities

Every ID in `candidate.capabilityIds` must be explicitly present in `supportedIds`. A required ID in `unsupportedIds` produces `functional_capability_unsupported`; a required ID in neither set produces `functional_capability_unconfirmed`.

### Equipment

Every requirement is evaluated against the inventory item with the exact same equipment ID:

```text
available quantity >= required quantity
and
required capability IDs ⊆ capabilities on that same inventory item
and
equipment ID is not temporarily unavailable
```

Capabilities are item-scoped, not global. Extra equipment or capabilities do not compensate for a missing requirement. `plate_loaded_machine` does not satisfy a specific machine ID. An exercise with no equipment requirements passes this gate without inferring `bodyweight_space`.

The product owner approved the greater-than-or-equal quantity rule on 2026-09-08: an equipment requirement is satisfied when the available quantity equals or exceeds the required quantity.

### Non-operative fields

The following must not alter this filter's result:

- Exercise name, aliases, instructions, or other presentation text.
- Wger IDs, URLs, categories, source order, attribution, or license wording.
- Movement patterns, muscle IDs, laterality, tracking mode, or benchmark identity.
- Variation or substitution groups.
- Goals, workout history, preference history, readiness, recovery, fatigue, volume, frequency, sequence, or time estimates.

Some of these fields may become inputs to later approved stages. Their exclusion here does not approve or reject future use.

## Result contract

The product owner approved the following closed result union on 2026-09-08:

- `evaluated`: filtering completed; one or more candidates are eligible.
- `constrained_no_candidate`: filtering completed; no candidate survived.
- `invalid_input`: required request data was missing, invalid, duplicated, unknown, or stale.
- `catalog_unavailable`: the complete catalog could not be trusted or validated.
- `safety_stop`: the separate safety path blocked ordinary eligibility or replacement.

Every result records:

- Rule-set, schema, catalog, and taxonomy versions.
- Catalog content digest.
- Constraint-snapshot digest and catalog-validation reference time.
- Sorted eligible exercise IDs when evaluated.
- Sorted per-candidate evaluations for every considered candidate.
- Stable request-level issue codes and structured parameters.

Candidate order in this result is canonical audit order only and never ranking. Sensitive free-form health or workout text must not appear in production logs or reason parameters.

## Stable reason codes

Candidate-level codes:

- `catalog_entry_unselectable`
- `exercise_excluded_persistent`
- `exercise_excluded_for_request`
- `limitation_conflict`
- `functional_capability_unsupported`
- `functional_capability_unconfirmed`
- `equipment_missing`
- `equipment_quantity_insufficient`
- `equipment_capability_missing`
- `equipment_temporarily_unavailable`

Request-level codes:

- `catalog_invalid`
- `schema_version_mismatch`
- `catalog_version_mismatch`
- `taxonomy_version_mismatch`
- `catalog_digest_mismatch`
- `constraint_digest_mismatch`
- `eligibility_rules_unsupported`
- `required_input_missing`
- `invalid_value`
- `unknown_taxonomy_id`
- `unknown_exercise_id`
- `duplicate_input`
- `stale_safety_reference`
- `no_eligible_exercise`
- `pain_report_requires_stop`
- `unresolved_safety_incident`

Codes carry typed parameters such as `exerciseId`, `equipmentId`, `capabilityId`, `limitationId`, `requiredQuantity`, and `availableQuantity`. Identifiers are parameters rather than being concatenated into code strings.

A trusted catalog that fails its own manifest or integrity validation returns `catalog_unavailable` with `catalog_invalid`. A valid catalog paired with stale or mismatched request identity returns `invalid_input` with the specific schema, catalog, taxonomy, or digest mismatch code. Multiple failures of the same candidate code produce one reason per distinct canonical parameter combination.

When it is safe to continue evaluation, the filter records every independently applicable candidate reason. Candidate results are sorted by exercise ID. Reasons are sorted by the order listed above and then by canonical parameter values. This all-reasons policy and canonical ordering were approved by the product owner on 2026-09-08. The UI shows one clear primary message by default and may offer the remaining factual details on request, but both views must derive from these same facts.

## Simple interface and AI boundary

The user-facing flow must minimize complexity even if a future AI-assisted interface helps collect structured answers or explain a result:

- Present one plain-language outcome, one recommended next action, and no unnecessary technical detail.
- Keep the structured “cannot perform” follow-up short, skippable, and limited to approved controlled choices.
- Offer secondary rejection details progressively rather than placing every internal reason on the main screen.
- An AI layer may help present approved choices or restate deterministic reason codes, but it must not decide eligibility, classify symptoms, infer limitations, invent medical advice, change reason parameters, relax a constraint, or override a safety stop.
- Core eligibility and safety behavior must remain deterministic, testable, offline-capable, and functional without an AI service.

Live AI workout generation remains outside early V1. This specification does not introduce an AI dependency or authorize sending safety, limitation, or workout data to a remote service.

## Accessibility contract

Every eligibility and safety outcome must be perceivable, understandable, and operable using supported iPhone accessibility features. Conformance is verified through testing and must not be claimed solely from source inspection.

- Use plain, concise language with a descriptive heading, the affected exercise when appropriate, and an explicit next action.
- Never communicate eligible, blocked, warning, or error state through color, animation, sound, or an icon alone. Pair visual treatment with visible text and programmatic semantics.
- Provide accurate VoiceOver labels, values, traits, hints only when useful, logical reading order, and immediate announcement of a newly presented safety stop without repeatedly announcing sensitive details.
- Support Dynamic Type through the accessibility sizes, including at least 200 percent text enlargement, without truncating the outcome, hiding the action, overlapping controls, or requiring horizontal scrolling.
- Keep primary controls at least 44 by 44 points and support Voice Control, Switch Control, Full Keyboard Access where applicable, and an onscreen alternative to every gesture.
- Respect Reduce Motion and do not require timed interaction to read, acknowledge, expand, or act on a result.
- Use sufficient contrast in light and dark appearances and preserve meaning with Increase Contrast and Differentiate Without Color enabled.
- Keep the primary explanation independent of technical reason-code vocabulary; localize visible text without changing the underlying code or deterministic result.
- Preserve focus and entered structured choices when the user returns from an accessibility interruption or system overlay.

These requirements follow Apple's current [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/) and [VoiceOver](https://developer.apple.com/design/human-interface-guidelines/voiceover) guidance, reviewed 2026-09-08. Before declaring the flow accessible, tests must show that every common eligibility and safety task can be completed with the claimed feature enabled.

## Determinism and monotonicity

For identical validated input bytes and versions, output must be byte-equivalent after canonical serialization.

- Reordering catalog entries, candidates, inventory records, or set-valued IDs does not alter output.
- Adding unrelated equipment, capabilities, or limitations does not alter a candidate.
- Removing a required item or supported capability cannot make an ineligible candidate eligible.
- Adding an applicable limitation, exclusion, temporary unavailability, or safety restriction cannot leave the affected candidate eligible.
- Relationship membership, benchmark identity, or presentation changes cannot override a hard constraint.
- Empty eligible output never causes constraints to be relaxed or a fallback exercise to be guessed.

## Worked examples

### Eligible

A candidate requires one `standard_barbell`, `weight_plates`, and `loaded_hip_hinge`. The explicit inventory meets both equipment requirements, the functional capability is `supported`, the limitation and exclusion sets are explicitly empty, the safety state is `clear`, and the entry is selectable. The result contains the exercise ID in `eligibleExerciseIds` with no exclusion reasons.

### Multiple hard failures

A candidate requires a `cable_station` with `rope_attachment`, conflicts with `avoid_overhead_arm_position`, and is persistently excluded. The station lacks the attachment and the explicit limitation is present. The result marks the candidate ineligible and records, in stable order, `exercise_excluded_persistent`, `limitation_conflict`, and `equipment_capability_missing` with typed IDs.

### Missing assessment

The limitation assessment object is absent. The result is `invalid_input` with `required_input_missing`; the filter does not interpret the absence as no limitations.

### Safety event

The user reports an event that the approved interface has classified as pain or a concerning symptom for the active exercise. The safety result is `safety_stop`; the affected exercise stops, the report is preserved, and no substitute or increased prescription is produced. The app does not infer a diagnosis or limitation tag.

### No feasible candidate

Every candidate fails one or more hard constraints. The result is `constrained_no_candidate` with `no_eligible_exercise`. A later stage receives no candidates and must not bypass the filter.

## Required verification matrix

### Normal and boundary cases

- Fully selectable entry with all exact requirements satisfied is eligible.
- Zero and multiple equipment requirements behave conjunctively.
- Quantity exactly equal to, one below, and one above the requirement.
- Zero and multiple required capabilities; `supported`, `unsupported`, and `unknown` states.
- Empty explicit limitation and exclusion sets versus unrelated and intersecting values.
- Persistent, request-scoped, and overlapping exclusions.
- Temporarily unavailable equipment overrides ordinary availability.
- One eligible and one ineligible candidate produce stable independent evaluations.
- Empty candidate set and a candidate set at the catalog limit.

### Invalid and missing cases

- Every required object missing independently.
- Duplicate and unknown IDs in every input collection.
- Candidate absent from the validated catalog.
- Invalid equipment quantity or capability attached to the wrong item.
- Unsupported rule, schema, catalog, or taxonomy version.
- Manifest digest, entry count, or complete-catalog integrity failure.
- Missing assessment versus explicitly assessed empty state.
- Stale persistent exclusion or safety restriction after a catalog migration.

### Safety and conflict cases

- Pain or concerning-symptom state bypasses ordinary eligibility and replacement.
- Required capability plus matching limitation: limitation remains exclusionary.
- Persistent exclusion plus request replacement: persistent exclusion cannot be bypassed.
- Safety restriction plus otherwise eligible candidate: restriction wins.
- A forged request constraint digest is rejected before it can bypass a matching restriction.
- Multiple simultaneous failures return every applicable reason in canonical order.
- No eligible candidate returns the explicit constrained result.

### Accessibility and simple-flow cases

- Each of the five result categories exposes a concise heading, state, affected exercise where applicable, and one next action to assistive technologies.
- VoiceOver and Voice Control can reach, understand, and activate every action in logical order.
- At 200 percent Dynamic Type, no outcome or required action is truncated, overlapped, hidden, or dependent on horizontal scrolling.
- Eligible, excluded, invalid, unavailable, and safety-stop states remain distinguishable without color, motion, or sound.
- Reduce Motion does not remove information, and every gesture has an onscreen alternative.
- The short “cannot perform” flow can be completed or skipped without typing and without navigating a complex questionnaire.
- Expanded internal reasons remain optional and do not obstruct the primary outcome or action.
- Any AI-assisted explanation exactly preserves the deterministic status, reason codes, parameters, and safety action; AI unavailability does not block the core flow.

### Property and regression cases

- Permutations of every unordered input produce byte-equivalent output.
- Repeated identical inputs and versions produce identical output.
- Hard exclusions are monotonic and cannot be reversed downstream.
- Presentation, provenance, muscle, benchmark, and relationship mutations cannot affect eligibility when catalog validation and selectability remain equivalent.
- Raw wger/import models cannot cross the domain boundary.
- Every unsafe or clearly unsuitable recommendation becomes a preserved regression case before its path is re-enabled.

## Explicit non-goals

- Exercise ranking, scoring, ordering, continuity, or tie-breaking.
- Session-target construction or workout composition.
- Substitution eligibility, equivalence, priority, or automatic replacement.
- Sets, repetitions, load, RIR, rest, tempo, progression, regression, or deload rules.
- Recovery, fatigue, overlap, volume, frequency, sequence, readiness, or HealthKit rules.
- Medical screening, diagnosis, rehabilitation, corrective exercise, injury-prevention claims, or medical clearance.
- Symptom classification, urgency, clinical escalation wording, or return-to-training decisions.
- Facility inference from a gym name or the phrase “full-service gym.”
- Production UI implementation; this contract defines only the required simple-flow and accessibility acceptance conditions for consuming stable results.

## Remaining gates before real recommendations

The product owner approved the product and engineering policies in this specification on 2026-09-08: capability handling, equipment quantity, temporary equipment scope, all three exercise-exception scopes, limited post-safety-stop continuation, contextual safety restrictions, fail-closed migration, all-reasons auditing, the five result categories, a simple interface, and accessibility as a required acceptance condition.

The pure structural filter may be implemented and tested with synthetic fixtures. It must not power real workout recommendations until the following external-verification or qualified-review work is complete:

1. Clinically reviewed symptom definitions, neutral interface wording, escalation instructions, and return-to-affected-exercise policy before outside testing.
2. Verified initial-tester equipment quantities and machine capabilities.
3. Exercise-specific capability, limitation, equipment, and safety mappings with review evidence.

Ranking, substitution, training-history feasibility, supported-population rules, and physiological safety bounds require separate specifications and are not blockers to reviewing this structural filter, but they are blockers to generating real workouts.
