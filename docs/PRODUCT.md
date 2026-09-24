# Product Specification

> September 23 follow-up: [Day-one contracts](programs/DAY_ONE_CONTRACTS_2026_09_23.md) supersede the fixed weekday and 45–60-minute requirements below. Schedule and duration are user preferences; explicitly ended partial sessions advance. Program provenance is ChatGPT-created and owner-tested, with trainer review deferred. Existing catalog/safety gates remain unresolved.

> Scope update approved September 23, 2026: the product owner is the sole initial tester, using an iPhone 17 Pro. The September 29 target is a private offline build; broader supported-iOS compatibility remains required and must be verified separately. Earlier references below to two testers or an invited friend are superseded for this initial phase. Photo evaluation requiring a second evaluator remains unresolved and cannot be claimed complete. For week one, the owner-supplied program replaces the earlier strength-first plan and the old barbell benchmark goals are deferred. The three-month outcome period and existing safety/review gates are unchanged. See [the implementation tracker](IMPLEMENTATION_WEEK_ONE.md).


Status: refined product direction; training rules, measurable outcomes, and broader launch population remain subject to validation and approval.

## Problem

People who want structured resistance training are often forced either to design their own programs or choose from generic templates. The product should remove that programming burden by selecting each workout, including its exercises and prescriptions, from explicit goals, constraints, and recent performance.

## Initial target user

The product owner and one invited friend are the first users and testers.

The long-term vision may support beginners through advanced trainees and varied equipment. That is not an appropriate validation scope for the first engine. The initial evidence profile is limited to the two named testers; experience ranges and exclusions for any broader population remain to be approved.

Both initial testers report no current pain, injury, medical restriction, pregnancy, or other known limitation affecting participation. This is a self-reported product input, not medical clearance. Experience-based eligibility and exclusions for later testers remain deferred.

## Core promise

Open the app and receive a clear, explainable workout that adapts to recent training without having to select exercises or design the session.

The user chooses goals and provides constraints. The engine chooses the exercises and training prescription. The user logs results and reports exceptions. The engine uses those explicit inputs to produce the next recommendation.

## Initial tester goals

The two initial testers want to build lean, defined physiques with an emphasis on strength, aesthetics, and flexibility.

The product may support the resistance-training and flexibility components of that goal. It must not promise leanness or fat loss from workout programming alone, and nutrition tracking remains outside early V1.

When goals compete, the approved product priority is:

1. Strength
2. Aesthetics
3. Flexibility

Measurable outcomes for each goal remain to be approved before they affect recommendations.

## Initial training schedule

Both initial testers plan to train five days per week. Each recommended session must be designed to fit within 45 to 60 minutes.

If a planned workout is missed, that workout moves to the next available training day and remains the next recommendation. Later planned workouts shift forward in order; the missed workout is not silently discarded or replaced. Behavior for shortened sessions, repeated missed days, schedule changes, and partially completed workouts remains to be approved.

## Initial equipment profile

Both initial testers train at the same full-service commercial gym and intend to use all supported equipment categories. The initial profile may mark every equipment category in the approved V1 exercise catalog as available.

The application must store capabilities and equipment rather than a gym name or precise location. Availability applies only to equipment explicitly represented in the versioned catalog; it must never be interpreted as permission to infer unknown equipment. Temporarily unavailable, occupied, or unsuitable equipment remains an explicit supported exception.

## Product principles

- The app recommends a complete workout rather than presenting an exercise browser as the primary experience.
- Exercise selection is deterministic: the same explicit inputs and catalog version produce the same recommendation.
- Every recommendation includes a concise, factual explanation.
- User feedback changes constraints or supplies performance data; it does not require the user to program the replacement.
- Adaptation is based on recorded behavior and constraints, not variety for its own sake.
- Safety and uncertainty take precedence over completing a generated workout.

## User and engine responsibilities

### The user provides

- Primary training goal
- Schedule and available session duration
- Available equipment
- Relevant experience and capability inputs
- Exercise limitations and excluded movements
- Completed load, repetitions, RIR, skipped work, and exception feedback

### The engine decides

- Session structure and training targets
- Eligible exercises and exercise order
- Sets, repetition ranges, target effort, and suggested load
- Rest guidance
- Progression, maintenance, regression, deload, or substitution
- How to fit the recommendation within the available time

## Exercise-selection experience

The exercise catalog is an internal capability, not the main user interface. Users are not expected to browse the catalog or build workouts.

The initial exception controls should be limited to:

- Equipment unavailable
- Cannot perform this movement
- Pain or concerning symptom
- Replace for today
- Do not recommend again

When replacement is allowed, the engine selects the substitute and explains the change. A pain or concerning-symptom report must follow an approved safety flow and must not be treated as an ordinary preference swap.

## Meaning of personalization and adaptation

Personalization uses relatively stable inputs such as goal, schedule, equipment, experience, and limitations to create an initial plan.

Adaptation changes a future recommendation in response to recorded outcomes such as completed repetitions and load, reported RIR, skipped work, exercise availability, or an approved readiness input. Merely rotating exercises is not adaptation.

The initial two-person build adapts from explicit workout history and supported exception feedback only. It does not collect or use subjective readiness or platform health data.

Before recruitment for the Reddit TestFlight beta, the product will add user-authorized Apple HealthKit data on iOS. Health Connect is the preferred future Android source. A Fitbit or Google Health cloud integration may be considered separately. No health metric may affect a recommendation until its data source, validity limits, missing-data behavior, permission flow, and deterministic interpretation are approved.

## V1 candidate scope

- Local onboarding and training profile
- Equipment and exercise constraints
- Automatic, deterministic exercise selection and workout generation
- Concise recommendation explanations
- Engine-selected substitutions for supported exceptions
- Set logging with reps, load, and RIR
- Rest timer
- Workout history
- Basic progression and volume insights
- Local export and deletion

## Explicitly outside early V1

- Social feed
- Coaching marketplace
- Live AI workout generation
- Wearable integrations
- Nutrition tracking
- Cloud synchronization
- User-authored workout programming
- Injury diagnosis, rehabilitation, or corrective-exercise claims
- Unlicensed third-party exercise instructions, images, videos, or proprietary programming systems

## V1 exercise-catalog source

The V1 exercise catalog uses a reviewed, version-pinned snapshot of exercise data from wger as its upstream seed. The snapshot is bundled for offline use; workout functionality must not depend on the live wger service. Adaptive Workout does not incorporate wger application code.

Each imported record must retain its wger UUID, source URL, author attribution, exact Creative Commons license and license URL, modification disclosure, review status, and snapshot version. Attribution must remain available from within the app. Wger-derived data and modifications remain separately identifiable and are distributed under the applicable content license. V1 excludes all wger images and videos because media carries separate per-asset licensing and review requirements.

Import does not make an exercise eligible for recommendations. Each record must pass schema validation and explicit product, scientific, safety, equipment, and licensing review first. Legal review remains required before commercial release, including review of ShareAlike distribution obligations.

## Decisions required from the product owner

1. Exact experience range and health exclusions for later testers. Both initial testers report no current training limitation, but the long-term ambition of supporting beginners through advanced trainees remains unapproved.
2. The priority of the approved strength, aesthetics, and flexibility outcomes is strength, then aesthetics, then flexibility.
3. Behavior for shortened sessions, repeated missed days, schedule changes, and partially completed workouts. A single missed workout is approved to move to the next available training day while preserving workout order.
4. Verification of the initial gym's supported equipment capabilities and loading increments against the approved V1 equipment taxonomy. A full-service-gym assumption cannot replace this verification.
5. Exact Apple Health metrics and approved readiness rules required before the Reddit TestFlight beta. The initial two-person build uses workout history alone.
6. Exact explanation format and level of detail. A short reason with optional expanded factors is a candidate pattern, not an approved design.
7. Free-versus-paid boundaries, deferred until the final pre-rollout phase.
8. Pain or concerning-symptom wording and escalation instructions require qualified clinical review before outside testing.
9. A future source, ownership, and commercial-license plan for exercise media. Wger media is excluded from V1.

## Validation phases

The first validation phase is a three-month private test conducted by the product owner and one invited friend. It can identify usability problems, logging friction, software defects, and obviously unsuitable recommendations. It cannot establish scientific effectiveness or safety for a broader population.

The three-month duration is approved. Progression to the TestFlight phase requires success across all of the following dimensions for both testers:

- Workout adherence: each tester completes at least 80% of planned workouts during the full three-month period, approximately 52 of 65 workouts at five planned workouts per week
- Strength improvement of at least 5% in each of the barbell back squat, flat barbell bench press, and conventional barbell deadlift for each tester, measured from comparable logged working sets using the approved RIR-adjusted Epley estimate and three-session median comparison; this is a private-test success criterion, not a guaranteed user outcome
- Aesthetic or body-composition progress demonstrated either by a decrease of at least 2.5 cm in average waist circumference or by waist circumference remaining within 1 cm of baseline while standardized comparison photos, voluntarily shared between and assessed by the two testers outside the app using the approved blinded three-view rubric, show improved muscular definition
- Flexibility improvement beyond the approved measurement threshold in at least two of the ankle knee-to-wall, active straight-leg raise, and shoulder-flexion tests, with no test worsening beyond its threshold
- App reliability and usability: zero lost, duplicated, or corrupted workout records; at least 98% of started workouts complete without a crash, frozen screen, or blocking app defect; no critical or high-severity defects remain unresolved before TestFlight; and both testers independently complete every critical workflow
- For each tester, at least 80% of completed workouts receive an ease-of-use rating of 4 or 5 on a five-point scale; a workflow that repeatedly causes confusion or requires external instructions fails review even when the numerical threshold is met
- Recommendation safety: zero explicit safety-constraint violations, zero injuries or concerning events to which an app recommendation may reasonably have contributed, and zero unresolved safety incidents at the end of the test

The supporting procedures still identified above must be approved before baseline collection or outside testing, as applicable. Success in one dimension must not compensate for failure in another. Any unsafe or clearly unsuitable recommendation must be recorded and investigated before broader testing.

Any injury or concerning event to which an app recommendation may reasonably have contributed immediately blocks broader testing and requires appropriate professional review. Every unsafe or clearly unsuitable recommendation path remains disabled until its inputs and output are preserved, its cause is identified, the rule is corrected, a regression test is added, and relevant deterministic simulations are replayed successfully. The application must return an explicit no-recommendation result when it lacks enough valid information to recommend safely.

After the two-person test meets its approved goals, Apple Health integration is complete, and the required safety, privacy, and quality gates pass, the product may expand to an invite-only TestFlight beta. Initial beta participants may be recruited from relevant Reddit communities in accordance with community rules. Recruitment language, consent, support capacity, participant criteria, retention targets, and willingness-to-pay measurement remain to be defined before recruitment begins.

The two-person test should specifically evaluate whether the recommended exercise is feasible, whether substitutions behave correctly, whether explanations match the actual rule used, and whether identical inputs reproduce identical recommendations.
