# Adaptive Workout

An offline-first mobile application that generates deterministic, evidence-informed workouts from a user's training history, equipment, goals, performance, and readiness.

## Current status

A physical-iPhone practice logger with local SQLite storage, plus independently tested eligibility, progression and warm-up domain policies.

The production app saves practice sessions, distinct sets, skips, corrections and completion, resumes a saved draft, and displays history. Save confirmation follows a committed transaction; failed saves retain input for safe retry. Practice records never affect real recommendations. The original temporary sample flow remains available through explicit demo/test injection. Full approved-program generation and real training history integration remain pending.

The approved structural exercise-eligibility and safety gate is implemented with synthetic domain tests, but it is not connected to the sample UI or used to generate real workouts.

A real wger-backed catalog slice now pins the three approved benchmark identities and attribution under catalog version `2026.09.08.1`. The entries remain disabled pending science, safety, equipment, and licensing review and are not connected to workout generation.

## Planned stack

- Flutter and Dart
- Riverpod for state management
- SQLite through the approved sqflite package for local persistence
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
5. Read `docs/EXERCISE_ELIGIBILITY.md` before implementing safety or exercise filtering; its structural contract is approved, while exercise mappings and clinical or training-science behavior remain gated.
6. Read `docs/catalog/BENCHMARK_CATALOG_2026_09_08.md` before changing the pinned benchmark slice.
7. Record significant architectural decisions in `docs/decisions/`.


## Storage checks

Run the usual format/analyze/unit tests, then the following on the connected physical iPhone (replace `DEVICE_ID`). Keep this order: the first test leaves three acknowledged fixture records, and the second verifies them in a new app process.

```sh
flutter test integration_test/practice_repository_test.dart -d DEVICE_ID --no-uninstall
flutter test integration_test/practice_restart_test.dart -d DEVICE_ID --no-uninstall
```

Always keep `--no-uninstall`: Flutter otherwise removes the app and its data. Tests use separate fixture database files and do not delete the production database. After testing, rebuild the regular app with `flutter run --release -d DEVICE_ID`.

The program preview now links to **Log workouts / history**. Manual sessions support persistent drafts, per-set actuals, explicit skips, separate warm-ups, single-arm left/right records, and audited corrections. Actuals require explicit setup and load convention; they never automatically become verified baselines or progression evidence. Storage lives separately from practice data. See ADR 0009 and `docs/TESTING.md` for persistence and physical-device verification boundaries.
