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

Catalog version `2026.09.08.1` is the first real source-backed slice and contains only the three approved benchmark identities. Its typed projection and pinned mapper fixture are offline and integrity tested. All entries remain disabled, and no application composition code loads the slice, until the pending review gates in `docs/catalog/BENCHMARK_CATALOG_2026_09_08.md` are complete.

The minimal internal entity and snapshot contract is defined in `EXERCISE_CATALOG.md`, its controlled IDs and bounds are defined in `EXERCISE_TAXONOMIES.md`, and the upstream mapping boundary is defined in `WGER_MAPPING.md`. The approved structural hard-filter and separate safety-gate boundary is defined in `EXERCISE_ELIGIBILITY.md`; exercise-specific mappings and clinical or training-science behavior remain gated by that document. Source DTOs, mapping-review records, import code, storage records, domain entities, and presentation models remain separate representations. Only the domain entity may cross into exercise selection.

The application-facing structural eligibility entry point is `ExerciseEligibilityEvaluator`. It receives the trusted, preconfigured catalog validator from the application composition boundary, revalidates the complete catalog and request envelope, recomputes the canonical constraint digest, invokes the private safety gate, and only then invokes the private eligibility filter. The filter receives an eligibility-only immutable projection, preventing presentation, provenance, muscle, benchmark, and relationship fields from becoming hidden inputs. Lower-level gate and filter types are library-private so callers cannot bypass validation. The implementation is tested with synthetic entries and is not connected to the sample workout UI or real recommendations.

## Week-one progression boundary

`LoadProgressionPolicy` implements the approved two-exposure external-load adjustment and bodyweight/assistance hold policy with explicit immutable inputs. It returns a candidate load, reason code, rule version and evidence IDs; it is not a complete workout recommendation. It is not connected to the sample UI. Future application orchestration must map a freshly evaluated safety/eligibility result into its explicit gate and supply verified baseline/equipment and complete history. Missing or blocked gates return no candidate load. See [ADR 0007](decisions/0007-approved-week-one-progression.md) for exact load representation and history requirements.

## Deferred decisions

- Exact package and feature boundaries
- Real-workout schema migrations beyond the approved practice SQLite schema
- Riverpod provider structure
- Backup/export format
- Analytics and crash-reporting policy
- Subscription entitlement behavior
- Exact exercise-catalog import and update tooling
- Exercise-to-taxonomy mappings and review evidence
- Exercise-eligibility mappings, clinical review, and verified equipment inputs
- Initial exercise-scoring factors and deterministic tie-breakers

Each material decision should be recorded in `docs/decisions/` before implementation.

## Warm-up target boundary

`WarmupPolicy` calculates approved rehearsal-set targets from a matching verified baseline, explicit current gate and available settings. Its historical v1 entry point keeps missing/infeasible or bodyweight/assisted inputs blocked. Approved v2 bodyweight targets now use `BodyweightWarmupPolicy`, with separate assistance and verified range references. `externalWarmupV2` preserves the v1 external calculation; `evaluateWarmupContinuation` checks explicit feedback, rest, interruption and current gate without reading a clock. These standalone policies remain unconnected to storage/UI; see [ADR 0011](decisions/0011-approved-warmup-v2.md). It does not control live exercise execution. The five-minute walking requirement is applied once by future session composition. See [ADR 0008](decisions/0008-approved-warmup-policy.md).


## Durable practice logging

Production composition opens `SqlitePracticeRepository` and injects its pure-Dart `PracticeRepository` interface into `PracticeController`. The screen invokes controller actions and acknowledges success only after the transaction and subsequent read succeed. The controller keeps a pending action for safe retry, blocks duplicate in-flight submissions, and does not log database errors or personal values. Record corrections preserve prior payloads while history reads the current set once. Explicit practice-only records never feed the workout engine. SQLite schema v1, limitations and device test isolation are documented in [ADR 0009](decisions/0009-local-workout-storage.md).

## Approved program preview

`owner_program.dart` is a constant, versioned transcription of the owner-approved prescriptions, with ordered blocks, paired supersets, P1 effort targets, P3 rests and P7 alternative preferences. These template IDs are not catalog identities and do not bypass catalog eligibility, setup verification or baseline checks. `ProgramPage` renders the templates read-only from the practice screen. No real-session database writes, automatic scheduling, load selection or optional finisher execution are enabled by this preview.

## Manual program logging

`ProgramLog` validates actual records and completion separately from constant prescriptions; it explicitly reports `recommendationEligible=false`. `ProgramLogController` owns pending actions and retry identity, and `SqliteProgramLogRepository` owns transactional persistence in a separate database. The program screen offers manual logging and history. Each stored session has a prescription snapshot; reads reject a mismatch with the pinned program version. No catalog entries are enabled and no manual actual automatically becomes a verified baseline. See ADR 0009 for the bounded storage extension.

## User-controlled calendar planning

### Local setup preparation

`TrainingSetupPage` delegates preferences, equipment drafts and explicit starting-load confirmations to `TrainingSetupController`, through the pure `TrainingSetupRepository` interface. `SqliteTrainingSetupRepository` stores versioned aggregates and atomic action receipts in a separate local database. Equipment revision changes make prior starting loads stale. Preparation variation keys are not approved catalog identities; these records do not enable recommendations. See [ADR 0012](decisions/0012-verified-training-setup-storage.md). The owner selected Monday–Friday and 60 minutes and will verify equipment gradually; these are owner preferences, not global defaults.

`SessionPlanningPolicy` independently maps an explicit ordered program, user-selected weekdays, scoped occurrence history and requested civil date to a next slot/date or resumable draft. Completed and explicitly ended-early occurrences advance; missed days do not. It does not determine exercise eligibility, recovery or load. `compareSessionDuration` reports an advisory comparison to a positive user preference, without enforcing a 45–60-minute limit or estimating durations. Both are standalone pure policies, not yet wired to storage or the app. [Day-one contracts](programs/DAY_ONE_CONTRACTS_2026_09_23.md) define the forthcoming immutable records, target-confirmation boundary and catalog review packet.

## Recommendation-linked storage and progression history

`RecommendationSnapshot` owns schema-1 self-contained ordered targets and immutable version/input/evidence references. Historical reads use that snapshot, never the current `ownerProgram` constant. `GeneratedOccurrence` validates actuals against exact saved targets and permits one audited set mutation or terminal transition at a time. `GeneratedHistory` validates a complete profile envelope and provides progression exposures without dropping incomplete or incomparable occurrences. Stable program IDs scope history across program versions; version changes break comparability.

`SqliteRecommendationHistoryRepository` implements the pure repository interface in a separate `recommendations.sqlite` store. Each mutation commits current state, prior revision, history revision and action receipt atomically. Reads validate relational identities, complete sequence and the audit chain. An older history revision invalidates unstarted recommendations while preserving active/historical prescriptions. Practice/manual data are never read by this adapter. There is no production composer/UI caller yet; storage does not approve a catalog or clear safety gates. Fresh cross-store input capture and eligibility checks belong to upcoming orchestration. See [ADR 0013](decisions/0013-recommendation-history-storage.md).
