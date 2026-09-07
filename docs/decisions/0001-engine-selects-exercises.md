# ADR 0001: The Engine Selects Exercises

## Status

Accepted as product direction. Scientific selection rules and the exercise-catalog source remain unapproved.

## Context

The product is intended to remove the burden of workout design. Presenting a large exercise library for users to browse and assemble would shift programming responsibility back to the user and weaken the adaptive-workout promise.

The engine still needs explicit goals, equipment, schedule, capability, limitations, and workout results. It also needs a controlled way to respond when an exercise is unavailable, unsuitable, or associated with pain.

## Decision

The exercise catalog is an internal engine resource rather than the primary user experience.

The user provides goals, constraints, logged results, and supported exception feedback. The deterministic domain engine selects exercises, orders them, assigns the approved prescription, and chooses any supported substitution.

The initial user experience will not require users to browse exercises or manually construct workouts. It may expose limited exception actions such as equipment unavailable, cannot perform, replace for today, do not recommend again, and a separate pain or concerning-symptom action.

Each recommendation records its rule-set version, catalog version, and explanation codes. If no safe feasible recommendation exists, the engine returns that result explicitly rather than selecting an ineligible exercise.

## Consequences

- Exercise eligibility, ranking, tie-breaking, and substitution become core domain behavior requiring specifications and unit tests.
- The exercise catalog requires sufficient structured metadata, provenance, and commercial usage rights.
- Onboarding and logging quality directly affect recommendation quality.
- Explanations must be generated from the rules actually used.
- The UI remains simpler, but the domain engine carries more responsibility and requires conservative failure behavior.
- User preferences may influence selection only through explicit approved inputs; they do not become an alternate manual-programming system.

## Alternatives considered

### User-built workouts

Rejected for the core experience because it preserves the programming burden the product is meant to remove.

### Engine proposal with unrestricted manual editing

Rejected for V1 because it blurs responsibility for the final prescription and makes adaptation history harder to interpret.

### Random exercise rotation

Rejected because variety alone is not adaptation and unseeded randomness violates deterministic-engine requirements.
