# Adaptive Workout

An offline-first mobile application that generates deterministic, evidence-informed workouts from a user's training history, equipment, goals, performance, and readiness.

## Current status

A physical-iPhone manual-program logger with local SQLite storage, plus standalone eligibility, progression, warm-up and calendar-planning domain policies. The app opens to the Training home, with direct access to workout logging, the program preview and training setup. System appearance is the default, with optional locally saved Light and Dark choices. Practice screens are hidden from normal navigation, with their existing data preserved. See [Interface design](docs/UI_DESIGN.md) for the shared design system.

The preserved practice flow saves practice sessions, distinct sets, skips, corrections and completion, resumes a saved draft, and displays history. Save confirmation follows a committed transaction; failed saves retain input for safe retry. Practice records never affect real recommendations. The original temporary sample flow remains available through explicit demo/test injection. Recommendation-linked backend storage and a progression-history adapter are implemented and tested separately; a deterministic composer now covers all five templates with synthetic inputs. Real reviewed catalog activation, atomic input acquisition and live app integration remain pending. See [Day 4 composition](docs/decisions/0014-session-composition.md).

The approved structural exercise-eligibility and safety gate is implemented with synthetic domain tests, but it is not connected to the sample UI or used to generate real workouts.

A real wger-backed catalog slice now pins the three approved benchmark identities and attribution under catalog version `2026.09.08.1`. The entries remain disabled pending science, safety, equipment, and licensing review and are not connected to workout generation.

User-selected training days and advisory session-duration preferences are defined in [the Day-one contracts](docs/programs/DAY_ONE_CONTRACTS_2026_09_23.md). Local setup preferences, equipment drafts and explicit starting-load confirmations are saved through the setup screen. Calendar planning remains independent; generated-session storage now has stable sequence and active/completed/ended-early states, while the composer now selects approved alternatives from eligible verified inputs. Live scheduling, proposed-load confirmation and application integration remain pending. The owner’s ChatGPT-created program is being tested personally; catalog review is not complete.

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

## Recommendation storage and history

[Day 3 storage](docs/decisions/0013-recommendation-history-storage.md) keeps immutable prescriptions separate from actuals, audits corrections and rejects stale future recommendations. Its progression adapter preserves incomplete/incomparable exposures and excludes practice/manual databases. It uses a separate `recommendations.sqlite` store and has no production generation/UI caller yet. Required catalog reviews remain pending.

Validation: 278 unit/widget tests and seven native SQLite tests passed on the authorized iPhone 17 Pro simulator, along with formatting and static analysis. Native tests use only `recommendation_history_fixture.sqlite` and must run with `--no-uninstall`. Simulator reopen and injected rollback checks do not establish physical-device power-loss recovery.
