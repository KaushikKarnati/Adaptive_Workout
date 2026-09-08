# Training Science Specification

Status: draft and intentionally unimplemented; no training rules are approved.

This document will define the approved training assumptions used by the deterministic engine. Software agents must not fill gaps with invented physiology.

## Evidence and policy boundary

The engine may be informed by personal-training certifications, textbooks, professional standards, position stands, systematic reviews, and primary research. These sources do not become executable rules until their claims are translated into an explicit, reviewable specification.

Use the following evidence roles:

1. Current professional position stands and systematic reviews define the primary evidence boundary.
2. Primary studies may resolve a narrower question when higher-level evidence is unavailable.
3. Certification materials may inform terminology, trainer workflow, safety topics, and candidate rules.
4. Popular training books may provide hypotheses and coaching approaches, but they do not establish scientific consensus.
5. Product-owner choices resolve cases where evidence supports multiple reasonable approaches; these must be labeled as product policy.

Conflicting sources must be recorded rather than silently blended. Source popularity, certification branding, or repetition across books is not evidence of correctness.

## Content and licensing boundary

Access to a certification course, textbook, website, or exercise library does not by itself establish commercial reuse rights. The product must not copy third-party wording, media, database records, assessment instruments, branded models, or program templates without a documented license permitting the intended use.

The engine may independently implement approved general principles when legally permitted. Legal review remains required before commercial release when a rule, name, taxonomy, or dataset is derived from proprietary material.

## Exercise catalog requirements

Every exercise considered by the engine requires structured, reviewable metadata rather than only a name or demonstration:

- Stable internal identifier and catalog version
- Original source and license provenance
- Movement pattern and intended training role
- Primary and secondary muscle contributions
- Required equipment and setup constraints
- Supported experience or capability constraints
- Range-of-motion or execution assumptions used by selection rules
- Known exclusions and approved regression or substitution relationships
- Original or licensed instructions and media references

Catalog metadata represents product claims and must be reviewed. A third-party label is not automatically an approved scientific fact.

Wger is the approved upstream seed for the V1 exercise catalog. Only a reviewed, version-pinned offline snapshot is used; live upstream changes cannot alter recommendations. Importing a wger record does not approve its exercise name, description, muscle relationships, equipment relationships, technique, safety, or programming role. Each imported claim remains inactive until it passes the applicable scientific and product review. Wger images and videos are excluded from V1. The approved minimal internal data contract and its boundary between provenance, presentation, and engine fields are defined in `EXERCISE_CATALOG.md`.

## Proposed selection pipeline

This pipeline describes product structure, not approved physiological rules:

1. Establish the session targets from the approved plan and recent history.
2. Filter the catalog using equipment, capability, exclusions, and safety constraints.
3. Exclude candidates that violate approved recovery, overlap, frequency, or sequencing rules.
4. Score eligible candidates using approved goal fit, fatigue cost, progression continuity, time efficiency, and preference-history rules.
5. Select a complete session within the approved duration and volume bounds.
6. Assign sets, repetition ranges, target effort, load, and rest using separately approved rules.
7. Produce explanation codes directly from the rules that affected the result.

The presentation format for those explanations remains deferred. A candidate interface may show a short reason with optional expanded factors, but the underlying codes and parameters must remain factual, stable, and traceable to the rule used.

The structural hard-filter and separate safety-gate contract for step 2 is approved in `EXERCISE_ELIGIBILITY.md`. It deliberately excludes recovery, ranking, substitution, prescription, symptom interpretation, and supported-population rules. Exercise-specific mappings, clinical review, and the separately listed training-science rules remain required before real recommendation behavior.

If required data is missing or no safe feasible exercise exists, the engine must return an explicit constrained or no-recommendation result. It must not guess.

## Adaptation inputs

The initial two-person build may adapt only from completed repetitions, load, RIR, skipped sets, session completion, equipment availability, exercise exclusions, and supported exception feedback. Interpretation rules for each input still require explicit approval.

Subjective readiness and platform health data are inactive during the initial test. Before the Reddit TestFlight beta, approved readiness measures may use user-authorized Apple HealthKit data on iOS. Health Connect is the preferred future Android source; Fitbit or Google Health cloud data would require a separately approved integration. Each health input remains inactive until its source, interpretation, reliability limits, missing-data behavior, permission behavior, and effect on recommendations are approved.

The engine must not assume that a missing health sample means a poor or favorable readiness state. It must also account for unavailable devices, denied or partial permissions, delayed synchronization, duplicate sources, and measurements that are absent or not comparable between platforms.

Pain and concerning symptoms must not be converted into a training-readiness score or ordinary fatigue adjustment. They require a separate approved safety response.

During the private test, a pain or concerning-symptom report must stop the affected exercise, must not automatically substitute another exercise, and must not increase load or volume. The report must be preserved for review, and the interface must provide neutral stop-training guidance with an appropriate-help escalation when needed. Exact symptom definitions, interface wording, and escalation instructions require qualified clinical review before outside testing; the engine must not invent them.

The private-test safety gate requires zero recommendations that violate an explicit limitation, excluded movement, unavailable-equipment constraint, or approved load or volume boundary. It also requires zero injuries or concerning events to which an app recommendation may reasonably have contributed and zero unresolved safety incidents at the end of the test. An unsafe or clearly unsuitable recommendation path must remain disabled until its explicit inputs and output are preserved, the cause is identified, the rule is corrected, a regression test is added, and relevant deterministic simulations pass. Missing or invalid safety information produces an explicit no-recommendation result rather than a guess. The product must not diagnose injury, prescribe rehabilitation, claim to prevent injury, or imply medical clearance.

## Goal interpretation required

The initial testers describe their combined goal as a lean and defined physique emphasizing strength, aesthetics, and flexibility. The approved product priority is strength first, aesthetics second, and flexibility third. These terms and their ordering express product intent, not executable scientific rules. Before implementation, each supported outcome requires an operational definition and measurement approach. Scientific specifications must define how the priority is applied when prescriptions conflict without bypassing safety constraints.

The approved strength benchmarks for the initial test are the barbell back squat, flat barbell bench press, and conventional barbell deadlift. Progress will be measured using estimated one-repetition maximum derived from logged working sets rather than requiring true maximum attempts. For each tester, private-test success requires an improvement of at least 5% in each benchmark over three months. This threshold is a product validation criterion, not a guaranteed physiological outcome and not an executable progression rule. Each tester must preserve the same benchmark setup and technique standard across baseline and final comparison windows. Other squat, press, or deadlift variations are separate exercises and do not contribute to these benchmark outcomes.

For strength-outcome evaluation, an eligible set uses the RIR-adjusted Epley estimate: `estimated 1RM = load × (1 + (completed repetitions + RIR) / 30)`. A set is eligible only when it is a working set of the exact approved benchmark variation, contains 2 to 10 completed repetitions, records an integer RIR from 0 to 3, and has a completed-repetitions-plus-RIR value from 3 to 10. The total external load must be valid, include the bar when applicable, and be normalized to a single internal unit before calculation. Warm-ups and sets containing assisted, failed, partial-range, pain-affected, or technique-invalid repetitions are ineligible. A set is also ineligible when its load, repetitions, RIR, variation, or validity status is missing.

For each lift, the baseline value is the median of all eligible set estimates from the tester's first three qualifying sessions, and the final value is calculated identically from the last three qualifying sessions. Each qualifying session requires at least two eligible sets. Comparison uses unrounded internal values; rounding is for display only. Another exercise or materially different variation must never be silently substituted. If either comparison window lacks sufficient comparable data, the result is `insufficient evidence`, not improvement or decline. The estimate is a consistent trend metric and must not be represented as the tester's measured true maximum.

For the private-test aesthetics outcome, each tester succeeds through either of two paths: average waist circumference decreases by at least 2.5 cm from baseline, or average waist circumference remains within 1 cm of baseline while standardized comparison photos show improved muscular definition. Waist measurements must be taken three times under consistent morning conditions and averaged. The measurement site is midway between the lowest palpable rib and the top of the iliac crest, with the tape level and the reading taken after a normal exhalation. Baseline and final photos must use the same front, side, and back views, lighting, camera distance, clothing, and poses. Photos are collected, stored, and compared outside the app during the private test; each tester may voluntarily share them with the other tester for assessment. The app must not request photo-library access or store, import, analyze, or synchronize body images. A seven-day average body weight may be recorded as supporting context. Consumer smart-scale body-fat estimates may also be retained as optional context but must not determine success.

For the external photo assessment, matching baseline and final images are randomly labeled A and B without revealing which is newer. The other tester scores each front, side, and back comparison as `+1` for visibly more muscular definition, `0` for no meaningful difference, or `-1` for visibly less muscular definition. The photo path succeeds only when the final images receive a total score of at least `+2` and no view receives `-1`; which images are final is disclosed only after the evaluator submits all scores. A comparison with inconsistent lighting, pose, distance, clothing, or framing is invalid and cannot be scored. This is a subjective private-test criterion and must not be represented as scientific proof of body-composition change.

The private-test flexibility outcome uses three measures: ankle dorsiflexion with the knee-to-wall test, posterior-chain flexibility with the active straight-leg raise, and shoulder flexion with standardized photography. Improvement beyond measurement variation is defined as at least 2 cm for the more restricted ankle, at least 5 degrees for the more restricted active straight-leg raise, and at least 8 degrees for shoulder flexion. A tester succeeds by exceeding the threshold in at least two of the three measures while no measure worsens beyond its corresponding threshold. These measures evaluate range-of-motion change only; they must not be presented as an injury diagnosis, proof of safer lifting, or proof of reduced injury risk.

Baseline and final flexibility testing occurs before training at approximately the same time of day, with no lifting or dedicated stretching earlier that day. The same room, equipment, camera, evaluator, and setup are used. Each session begins with five minutes of easy walking followed by three practice attempts for each test. Three valid recorded attempts are completed per side with 30 seconds between attempts, and their average is used. Pain stops the affected test and is recorded through the safety process. An attempt with observable compensation or a setup error is invalid and may be repeated; inability to collect three valid attempts produces `insufficient evidence` for that measure.

For the knee-to-wall test, the tester is barefoot with the heel flat and the knee tracking over the second toe. The foot is moved away from the wall until the knee can just touch it without the heel rising. The distance from the great toe to the wall is recorded to 0.1 cm. For the active straight-leg raise, the tester lies supine with the non-test leg straight and secured, keeps the tested knee straight and ankle relaxed, and raises the leg until the knee bends, the pelvis moves, or comfortable active range ends. A perpendicular fixed-position side photo is used to measure the thigh angle. For shoulder flexion, the tester stands on a marked spot 1.5 metres from a side-on camera positioned level with the shoulder, keeps the thumb upward, elbow straight, and trunk neutral, and raises the arm to comfortable active end range without leaning or arching. The angle is measured from the standardized photograph.

If a tester begins within one approved improvement threshold of a test's documented valid measurement ceiling, maintaining that range without worsening beyond the threshold counts as meeting that measure. Ceiling status and the applicable measurement ceiling must be recorded at baseline and cannot be assigned retrospectively. Pain, compensation, and invalid setup never qualify as a ceiling result.

Workout programming alone must not be represented as sufficient to produce leanness or fat loss. Nutrition tracking is outside early V1, and the engine must not infer nutrition intake or energy balance.

## Initial schedule constraint

The first evidence profile assumes five training days per week and a session duration of 45 to 60 minutes. These are approved product constraints, not evidence-based prescriptions. A missed workout carries forward to the next available training day, remains the next recommendation, and shifts later workouts forward without changing their order. Schedule evaluation must receive the relevant date and history as explicit inputs rather than reading the wall clock. Workout composition rules must still specify how volume, exercise selection, rest, and time estimates fit within the approved bounds, including behavior for repeated missed days and partial sessions.

## Initial equipment constraint

The first evidence profile assumes a full-service commercial-gym setting shared by both initial testers. All equipment categories explicitly represented in the approved V1 catalog are considered available to both testers unless an exception is reported. Selection rules must use explicit catalog equipment identifiers rather than a facility name, location, or open-ended concept of "all equipment." Exact machine capabilities and loading increments remain catalog data that must be defined and validated before use.

## Validation boundary

The product owner and one invited friend will be the first users and testers. Their testing may reveal usability issues, logging errors, and recommendations that are obviously unsuitable for either tester. Results from two people do not validate the scientific effectiveness or safety of a rule, and they do not replace explicit rules, cited evidence, worked examples, or automated tests. A later TestFlight beta likewise provides product-validation evidence rather than controlled scientific validation.

Both initial testers report no current condition or limitation affecting training. The engine must treat that as self-reported input rather than medical clearance. Supported-population rules and exclusions for broader testing remain unapproved.

## Specifications still required

- Exercise-to-muscle contribution model
- Effective-set accounting
- Minimum and maximum weekly volume rules
- Fatigue and readiness inputs
- Recovery decay model
- RIR interpretation and missing-RIR behavior
- Progression and regression rules
- Deload triggers
- Exercise substitution rules
- Exercise-specific eligibility mappings, plus ranking, tie-breaking, and continuity rules
- Explanation codes for every selection and adaptation outcome
- Load rounding and equipment increments
- Safety bounds and impossible-input handling
- Supported population and explicit exclusions
- Operational definitions and conflict-resolution rules for strength, aesthetics, and flexibility goals, using the approved priority order
- Five-day schedule composition, session-time estimation, and missed-or-incomplete-session behavior
- Exercise-to-taxonomy mappings, facility-specific machine capabilities, loading increments, and unavailable-equipment behavior

Every rule should include:

- Purpose
- Inputs
- Formula or decision table
- Valid range
- Missing-data behavior
- Worked examples
- Test cases
- Source or product-owner rationale
- Evidence strength and date reviewed
- Deterministic tie-breaking behavior
