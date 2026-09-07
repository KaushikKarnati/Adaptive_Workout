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

The catalog repository loads a reviewed, version-pinned wger exercise-data snapshot bundled for offline use. The application does not call wger while generating or presenting a workout and does not incorporate wger application code. Imported content remains in a separately identifiable data package under each record's applicable license, with attribution and modification history preserved. Images and videos are excluded from V1.

The domain consumes only validated internal catalog entities, never raw upstream records. Ingestion treats all upstream text and metadata as untrusted, converts permitted content to the approved plain-text and enum representation, rejects malformed or unsupported values, and produces a reproducible snapshot manifest and integrity digest. Instructions and any future media are presentation content and must not become hidden sources of domain behavior.

The minimal internal entity and snapshot contract is defined in `EXERCISE_CATALOG.md`, its controlled IDs and bounds are defined in `EXERCISE_TAXONOMIES.md`, and the upstream mapping boundary is defined in `WGER_MAPPING.md`. Source DTOs, mapping-review records, import code, storage records, domain entities, and presentation models remain separate representations. Only the domain entity may cross into exercise selection.

## Deferred decisions

- Exact package and feature boundaries
- Drift schema and migration strategy
- Riverpod provider structure
- Backup/export format
- Analytics and crash-reporting policy
- Subscription entitlement behavior
- Exact exercise-catalog import and update tooling
- Exercise-to-taxonomy mappings and review evidence
- Initial exercise-scoring factors and deterministic tie-breakers

Each material decision should be recorded in `docs/decisions/` before implementation.
