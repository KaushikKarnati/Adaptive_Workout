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

- Exercise catalog
- Workout generation
- Progression
- Volume accounting
- Readiness and fatigue
- Load calculation
- Workout-time optimization
- Workout logging and history

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

1. The UI submits an explicit user action.
2. An application controller validates and coordinates the action.
3. Domain services calculate deterministic results from explicit inputs.
4. Repository interfaces store or retrieve records.
5. The UI renders immutable application state.

## Deferred decisions

- Exact package and feature boundaries
- Drift schema and migration strategy
- Riverpod provider structure
- Backup/export format
- Analytics and crash-reporting policy
- Subscription entitlement behavior

Each material decision should be recorded in `docs/decisions/` before implementation.
