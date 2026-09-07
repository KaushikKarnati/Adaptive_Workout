# Adaptive Workout

An offline-first mobile application that generates deterministic, evidence-informed workouts from a user's training history, equipment, goals, performance, and readiness.

## Current status

Step 1 foundation plus a sample-only workout interface for iPhone UX testing.

The current Welcome → Today → Preview → Active → Completion flow uses fixed illustrative data and does not save workouts or generate recommendations. Product and scientific rules must be approved before they become application logic.

## Planned stack

- Flutter and Dart
- Riverpod for state management
- Drift with SQLite for local persistence
- RevenueCat for subscriptions in a later phase
- GitHub Actions for continuous integration

## Core principles

- Offline-first and privacy-first
- No LLM dependency for workout generation
- Deterministic, independently testable workout engine
- Business logic separated from UI and persistence
- Small, reviewed changes with automated tests

## Start here

1. Read `AGENTS.md`.
2. Follow `docs/STEP_01_MAC_SETUP.md` on the development Mac.
3. Complete and approve `docs/PRODUCT.md` before implementing domain logic.
4. Read `docs/EXERCISE_CATALOG.md` and `docs/EXERCISE_TAXONOMIES.md` before changing catalog ingestion or exercise entities.
5. Record significant architectural decisions in `docs/decisions/`.
