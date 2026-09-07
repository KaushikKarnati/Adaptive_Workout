# Architecture

Status: initial direction; decisions requiring product or scientific judgment remain unapproved.

## System boundary

Version 1 is an offline-first Flutter application. Core workout generation, logging, history, and progress analysis run locally. No user account or cloud backend is required for the first validated release.

## Intended dependency direction

```text
Presentation -> Application -> Domain
                    |
                    v
              Repository interfaces
                    ^
                    |
             Data implementations
```

The domain layer must not depend on Flutter, Drift, RevenueCat, analytics, or platform APIs.

## Planned modules

- Versioned exercise catalog with license and provenance metadata
- Exercise eligibility and ranking
- Workout composition
- Progression
- Volume accounting
- Readiness and fatigue
- Load calculation
- Workout-time optimization
- Workout logging and history
- Recommendation explanations

## Planned Flutter layout

```text
lib/
  core/
  data/
    database/
    repositories/
  domain/
    exercises/
    progression/
    readiness/
    volume/
    workout/
  features/
    onboarding/
    workout/
    history/
    progress/
    settings/
  design/
```

This layout is a starting boundary, not permission to create every folder or abstraction before it is needed.

## Data flow

1. The UI submits explicit goals, constraints, workout results, or exception feedback.
2. An application controller validates and coordinates the action.
3. Repository interfaces provide the versioned exercise catalog and local training history.
4. Domain services filter eligible exercises, rank candidates, compose the workout, and calculate its prescriptions.
5. The domain returns the recommendation together with stable explanation codes and the versions of rules and catalog used.
6. Repository interfaces persist the recommendation and subsequent results.
7. The UI renders immutable application state.

## Deterministic recommendation boundary

The engine must accept all decision-relevant state as explicit input. It must not depend on widget state, wall-clock time, network responses, unseeded randomness, iteration order, or hidden mutable state.

A recommendation result should contain:

- Selected exercises and order
- Sets, repetition range, target effort, load, and rest where applicable
- Any substitutions or omitted targets
- Explanation codes and user-readable explanation parameters
- Rule-set version and exercise-catalog version
- Explicit constrained or no-recommendation status when necessary

The user interface may request a replacement by submitting a new constraint or supported exception. It must not contain its own replacement or workout-selection logic.

## Exercise content boundary

The catalog repository may load bundled or locally persisted data, but the domain consumes only validated catalog entities. Third-party content must retain provenance and license metadata through ingestion. Instructions and media are presentation content and must not become hidden sources of domain behavior.

## Deferred decisions

- Exact package and feature boundaries
- Drift schema and migration strategy
- Riverpod provider structure
- Backup/export format
- Analytics and crash-reporting policy
- Subscription entitlement behavior
- Exercise-catalog source, commercial license, and update process
- Initial exercise-scoring factors and deterministic tie-breakers

Each material decision should be recorded in `docs/decisions/` before implementation.
