# Seven-day backend completion plan

> September 23 follow-up: [Day-one contracts](programs/DAY_ONE_CONTRACTS_2026_09_23.md) resolve user-controlled scheduling, early-end advancement, target confirmation, Tuesday alternatives and advisory duration. Earlier hard time-budget requirements below are superseded. The pure calendar/duration policies are implemented; full integration and listed review gaps remain pending. The owner has deferred trainer involvement, so Day 2 review availability is no longer an assumed commitment.

Prepared September 23, 2026 after reviewing the repository and running its local checks. Schedule: September 23–29, matching the existing private-build target. If implementation starts later, move the dates together and retain the dependency order.

Status: proposed execution plan. The owner requested Fitbod and Gravl as design references. That direction does not supply the missing exercise reviews or approve new physiological formulas. Existing approved specifications remain authoritative.

## Target and feasibility

Finish the **offline backend for the owner's approved five-session program**: verified setup → next session → explained prescription → durable actuals → corrected history → next recommendation. “Backend” means Dart domain/application services and local SQLite repositories, as defined in [ARCHITECTURE.md](ARCHITECTURE.md). No hosted server or account is needed for this release.

Seven days is an aggressive, conditional target. It assumes seven focused implementation days, prompt owner decisions, and completed catalog/science/safety/equipment/licensing review evidence by Day 2. Independent review preparation can run alongside engineering. Implement one bounded code slice at a time and reserve Day 7 for acceptance and fixes.

Completion requires all five session types to work with reviewed, verified inputs, including their required warm-ups. Correct blocked responses are required tests, but blocked sessions alone do not satisfy full-program completion. If reviews or missing rules remain open, report the affected functionality as incomplete rather than claiming the entire backend is finished.

The broader engine in the architecture—arbitrary program generation, muscle recovery modeling, volume optimization, deloads and general ranking—is a later phase. The approved owner program supplies exercise order, sets, rep ranges and rests this week.

## What the files show now

| Area | Current evidence | Remaining work |
| --- | --- | --- |
| Safety and structural eligibility | Guarded [evaluator](../lib/domain/exercises/eligibility/exercise_eligibility_evaluator.dart) and deterministic tests exist. | Connect fresh verified inputs and reviewed real entries through the public evaluator. |
| Progression | [LoadProgressionPolicy](../lib/domain/progression/load_progression_policy.dart) implements approved P4–P6/P9 with reasons and evidence IDs. | Supply complete durable history and derive its gate from current eligibility. |
| Warm-ups | [WarmupPolicy](../lib/domain/workout/warmup_policy.dart) implements approved external-load targets. | Execute the safety checks, count full duration, resolve bodyweight/assisted rehearsal. |
| Program | [owner_program.dart](../lib/domain/workout/owner_program.dart) contains the five approved templates. | Bind template slots to reviewed catalog variations and verified setups. |
| Catalog | Only [three disabled barbell benchmarks](catalog/BENCHMARK_CATALOG_2026_09_08.md) are source-pinned. They do not cover this program. | Build and review the actual program catalog; publish a new immutable version. |
| Logging | [Practice](../lib/data/repositories/sqlite_practice_repository.dart) and [manual program](../lib/data/repositories/sqlite_program_log_repository.dart) repositories provide transactions, receipts, revisions, drafts and history. | Extend for recommendation-linked sessions; preserve existing databases and records. |
| Training evidence | [ProgramLog](../lib/domain/logging/program_log.dart) explicitly returns `recommendationEligible=false`. | Add a separate validated evidence path. Do not automatically promote manual or practice records. |
| Profile and baselines | Controllers use a local owner ID; manual setup labels are not verification records. | Persist versioned profile, equipment, capability, constraint and exact-setup baseline verification. |
| History compatibility | Readers require the current program version and prescription; schema upgrades currently refuse to open. | Historical readers and transactional forward migration fixtures before version changes. |
| Application | [main.dart](../lib/main.dart) opens the practice flow; the engine policies have no application callers. | Add application orchestration and a minimal real-session entry point. |
| Lifecycle/privacy | No complete scheduling, abandonment, export or local deletion service exists. | Resolve the contracts and implement them with recovery tests. |

The existing logging foundation should be extended, not rebuilt. Earlier tracker rows saying that storage or signing is still pending are historical; later entries record manual storage and physical installation results. README/current-status text also needs reconciliation.

## How Fitbod and Gravl shape this implementation

These are adaptations of publicly described behavior, not claims about access to either company's implementation. Competitor documentation establishes product behavior, not scientific validation for this user.

| Publicly documented pattern | Adaptation for this project | Delivery |
| --- | --- | --- |
| Fitbod separates exercise selection from load/set/rep recommendation. [Fitbod algorithm](https://fitbod.me/blog/fitbod-algorithm/) | Keep the session composer separate from eligibility, progression and warm-up policies. Use the approved program as the selection framework. | Day 4 |
| Gravl's Fixed Structure mode retains exercises, order and set counts while allowing progression. [Gravl custom programs](https://gravl.ai/help/design-your-own-program) | Use this as the closest reference mode: retain the supplied program and its rep ranges, with adaptive loads governed by P4–P6. This does not add a user program builder. | Days 4–5 |
| Both use training configuration and available equipment. [Fitbod profile](https://help.fitbod.me/hc/en-us/sections/360012732693-App-Features), [Gravl equipment](https://gravl.ai/help/gravl-gym-set-up-profiles-and-available-equipment) | Persist equipment capabilities and actual load settings; keep temporary unavailability separate from permanent exclusions. No gym address is needed. | Days 2, 5 |
| Fitbod uses logged performance and RIR; Gravl uses actual performance and effort feedback. [Fitbod prescriptions](https://help.fitbod.me/hc/en-us/articles/43489869175063-How-does-Fitbod-decide-my-sets-reps-and-weight), [Gravl algorithm](https://gravl.ai/blog/how-gravl-algorithm-works) | Feed exact comparable history into approved two-exposure increase/hold/reduce rules. Preserve missing RIR as unknown. Keep prescribed sets and rep ranges unchanged. | Days 3–5 |
| Gravl snaps suggested weights to available equipment settings. [Gravl algorithm](https://gravl.ai/blog/how-gravl-algorithm-works) | Use verified settings and the existing approved increase/reduction limits; retain machine identity, per-dumbbell values and assistance semantics. | Days 2, 4 |
| Both offer replacement controls; Gravl distinguishes replacement from persistent exclusion. [Fitbod editing](https://help.fitbod.me/hc/en-us/articles/360006335593-Editing-Workouts-in-Fitbod), [Gravl replacement](https://gravl.ai/help/replace-an-exercise-in-your-workout) | Implement P7 alternatives in their approved preference order, with separate baselines. P8 blocks unsupported substitutions; pain follows P10. | Day 5 |
| Both account for session duration. [Fitbod profile](https://help.fitbod.me/hc/en-us/sections/360012732693-App-Features), [Gravl algorithm](https://gravl.ai/blog/how-gravl-algorithm-works) | Count walking, rehearsals, both sides, work, rest and transitions. Report an infeasible session rather than silently removing prescribed work. | Days 1, 4 |
| Gravl provides an explanation of the inputs behind a suggested load. [Gravl insights](https://gravl.ai/help/gravl-science-understand-your-recommended-weights) | Store stable reason codes, evidence IDs and versions; render a concise explanation from those exact values. | Days 3–5 |
| Fitbod exposes estimated muscle recovery; Gravl describes strength estimates and transfer between movements. [Fitbod recovery](https://help.fitbod.me/hc/en-us/articles/43492170863895-How-does-Fitbod-know-my-muscles-are-still-recovering), [Gravl algorithm](https://gravl.ai/blog/how-gravl-algorithm-works) | Schedule a later reviewed modeling phase. Week one may show factual history, but must not present an invented readiness percentage or transfer a baseline across variations. | After week one |

Additional later candidates: generalized goals/splits, approved double progression beyond current P4–P6, recovery-aware selection, deload rules and broader substitutions. Fitbod's max-effort features and Gravl's guessed starting strength, variable prescriptions and stochastic selection do not replace this project's verified-baseline, fixed-program and deterministic contracts.

## Decisions that control the deadline

Prepare concrete worked examples on Day 1. Record owner policy decisions and the required reviewer evidence separately; the development agent must not approve its own scientific assumptions.

| Decision/input | Needed by | Completion evidence |
| --- | --- | --- |
| Exact program exercise identities, alternatives, taxonomy coverage and all required reviews | Day 2 | Reviewed slot-to-catalog matrix, provenance/license records, review references, new manifest/digests. Do not match names approximately. |
| P7 leg-curl alternative scope | Day 1 | Resolve whether Tuesday can use lying curls: its current template fixes seated curls, while Saturday lists both and P7 describes a seated-then-lying preference. Do not treat the code as resolving this ambiguity. |
| Verified capabilities, machine/setup identities, units, actual load settings and baselines | Day 2 | Private local verification records for enabled variations; provisional internet examples remain unverified. |
| Rehearsal for pull-ups/assistance, hanging knee raises and ab wheel | Day 1 decision; Day 4 implementation | Approved rule examples. Without them Wednesday, Friday and Saturday cannot pass full-session acceptance. |
| Duration estimates and infeasible-time response | Day 1 | Reviewed work/transition assumptions, unilateral and superset accounting, exact-budget and over-budget examples. |
| Baseline lifecycle after an accepted increase/reduction, and warm-up basis for that target | Day 1 | Explicit distinction between verified baseline and candidate load; rule for later comparable exposures and reconfirmation. |
| Partial-session abandonment, skipped completion, repeated misses, long absence and recovery-day/calendar behavior | Day 1 | Approved state-transition examples preserving single-miss carry-forward. No inferred Sunday workout or detraining percentage. |
| Safety report persistence, review/reset conditions and wording | Day 1 contract; Day 2 evidence | Approved stop/review flow. A corrected symptom entry must not silently clear a restriction. |
| Storage extension, historical reads, export format and deletion scope | Day 1 | Engineering decision with schema/version examples and acceptance tests; separate approval for any new dependency. |

Use existing packages where feasible. Do not add a state-management framework, backend service, analytics SDK or export package merely to match a competitor's feature list.

## Seven-day execution schedule

### Day 1 — September 23: contracts and review packet

- Freeze the scope above and reconcile the tracker/README with the current code.
- Specify immutable recommendation inputs/results, verified baseline lifecycle, generated-session history eligibility and session transitions. Include rule versions, requested date, input revisions and reason codes.
- Prepare the missing policy examples and a catalog coverage checklist for every program slot and P7 alternative. Begin review immediately while engineering continues.
- Define a storage extension that preserves both existing databases; select transactional boundaries for session actions, history revisions and recommendation invalidation.

**Exit:** decisions have named owners and deadlines; approved branches have normal/boundary/invalid/missing-data examples. Open decisions are explicit blockers. Today's repository audit and local baseline are complete; the remaining Day 1 work is not yet implemented.

### Day 2 — September 24: verified inputs and program catalog

- Implement domain models and repository interfaces for the local training profile, explicit constraints, equipment setups/load settings, verification records and baselines.
- Add SQLite persistence, validation and the migration tests required by the selected schema. Test cross-profile references, invalid units, duplicates and interrupted transactions.
- Bundle the reviewed owner-program catalog and stable template bindings. Reuse the mapper/validators; version any required taxonomy extension instead of forcing unsupported records into existing categories.
- Provide a minimal entry path for private verification data; persist no actual owner measurements in source-controlled fixtures.

**Exit:** verified inputs survive reopen; unavailable or unverified equipment and missing baselines cannot produce a load; every enabled catalog record passes integrity and review gates. If review coverage is still missing, continue infrastructure work but mark full-program activation at risk.

### Day 3 — September 25: recommendation-linked storage and history

Implementation update: the backend slice below is implemented and tested under [ADR 0013](decisions/0013-recommendation-history-storage.md): 278 unit/widget tests and seven native simulator storage tests passed. This supplies storage/history infrastructure to Day 4; it does not activate the pending reviewed catalog or connect a production composer/UI. Owner approved the current setup UI and requested backend-first work. Simulator use is now explicitly authorized, superseding the earlier simulator restriction in this plan.

- Add immutable recommendation snapshots: ordered exercises, sets, reps, RIR, loads/rests, warm-ups, selected setup, rule/program/catalog versions, explicit input references, status, reasons and evidence IDs.
- Persist actuals separately with stable sequence, sides, validity/skips, drafts/completion, receipts and audited corrections. Reuse the existing transaction/retry approach.
- Build the progression history adapter: exact profile/slot/variation/setup/load convention; retain intervening incomplete exposures; exclude warm-ups and ineligible practice/manual history; count each current corrected record once.
- Support historical program/prescription versions without rewriting old recommendations. Corrections invalidate affected future calculations.

**Exit:** storage/reopen, retry, revision conflict, unsupported-schema preservation and historical-read fixtures pass; a corrected or interrupted exposure changes the next calculation appropriately without altering its original recommendation.

### Day 4 — September 26: complete deterministic session generation

- Add a pure Dart session composer and an application service that loads a consistent input snapshot, calls guarded eligibility, applies approved alternatives, calls progression/warm-up, checks feasibility, and saves the result.
- Preserve exercise order, paired rounds, set/rep prescriptions and rest. Apply five-minute walking once. Keep the optional finisher off.
- Implement the approved duration contract and bodyweight rehearsal rules only after their decisions are recorded. Return actionable missing-setup, safety-stop or infeasible-session results where necessary.
- Keep working-load settings separate from rehearsal settings: warm-ups may use a verified zero machine setting, while the current external-load progression policy rejects zero in its ladder.

**Exit:** Monday runs end to end with reviewed real catalog bindings; deterministic fixtures cover all five templates and approved alternatives. Same explicit input and versions produce identical results despite catalog/history input ordering. Candidate progression loads are never relabeled as verified baselines implicitly.

### Day 5 — September 27: adaptation, exceptions and next-session lifecycle

- Wire generated sessions into the existing logging flow and minimal application entry point; make the next recommendation consume saved results.
- Implement P7/P8 equipment exceptions and permanent exclusions. Re-evaluate current safety/eligibility after relevant setup or constraint changes, including changes after preview.
- Persist symptom reports and rehearsal stop conditions. Stop the affected exercise and block automatic replacement and load/volume increases. After acknowledging a safety stop, permit ending the session or continuing only already-planned unaffected exercises, as specified in [the safety contract](EXERCISE_ELIGIBILITY.md); this does not authorize a new recommendation or clear the restriction.
- Implement the approved scheduling/partial-session contract. An explicit requested date and stable history determine the next session; a single missed workout retains its place.
- Render factual explanations from stored reasons and evidence. Keep an active prescription stable except through an explicit supported action; preserve its history when future recommendations change.
- Expose factual history summaries for completed working sets and comparable load/repetition changes. Keep warm-ups, correction revisions and incomparable machine/assistance conventions separate; inferred effective volume and recovery remain later work.

**Exit:** integration fixtures prove first recommendation → logging → next recommendation, two-exposure increase/hold/reduce, unknown RIR, both sides, unavailable superset station, interruption/resume and correction-driven recalculation. Safety fixtures verify both the affected-exercise block and the limited unaffected-exercise continuation. Device checks must not require the owner to perform extra workouts just to manufacture a progression streak; use isolated synthetic fixtures.

### Day 6 — September 28: data ownership and hardening

- Implement the agreed bounded export and local deletion services across practice, manual, verified profile/setup, recommendation, correction and action-receipt stores. Make multi-store deletion recoverable after interruption; verify it cannot resurrect old records.
- Validate export schema, bounds, units and versions. Test exported completeness and failure handling. Arbitrary import/restore is outside this week unless explicitly added to the contract.
- Add corruption/migration fixtures, including relational identity/revision mismatches versus stored payloads. Verify old data survives app/schema upgrades and failed migrations.
- Review dependency notices, permissions, sensitive logging, iOS file protection and backup behavior. Normalize and inspect effective iOS deployment targets; record unsupported/unavailable compatibility coverage honestly.
- Run deterministic multi-session simulations as separate test tooling with seeded or fixed inputs. Preserve failing cases; do not use simulation results to invent new production rules.

**Exit:** export/delete and upgrade/recovery tests pass; no unresolved critical/high defect remains. All five session types and supported alternatives have acceptance fixtures. Feature work stops here.

### Day 7 — September 29: physical offline acceptance and delivery

- Run formatting, static analysis, the complete local suite and native SQLite integration suites on the physical iPhone using isolated databases and `--no-uninstall`.
- In airplane mode, exercise verified setup → generate → log → interrupt/reopen → complete → next recommendation → correction → export/deletion on test data.
- Verify committed-write restart recovery and process termination around an in-flight transaction separately. A rollback injection or committed-write probe is not proof of physical power-loss behavior.
- Check safety/missing-data messages, VoiceOver and enlarged text on the minimal connected flow; restore the normal app after probes. Do not download or launch simulators, following the owner's recorded preference.
- Inspect the final diff and security/privacy behavior. Record review evidence, tested device/OS, commands, unresolved compatibility gaps and release decision.

**Exit:** all required gates pass and the owner can use the complete five-session loop offline. Otherwise deliver the tested subset with a precise incomplete-items list; do not label blocked generation or manual logging as a finished adaptive backend.

## Dependency order and fallback

The critical path is approved contracts + reviewed catalog + verified inputs → durable recommendation/history → composer → execution/adaptation → offline acceptance. Export and privacy work can be prepared independently once the schema is fixed. Catalog review is the largest external dependency and starts on Day 1, not after the engine is written.

If a deadline slips, reduce optional polish first: extended dashboards, more alternatives than P7, generalized split generation, automatic CI setup and convenience export formats. Retain durability, safety, deterministic replay, correction integrity and local deletion. Do not silently shrink the approved five-session acceptance target. Broader iOS compatibility remains a separate release obligation if physical-device coverage is unavailable.

Do not add recovery percentages, cross-exercise strength transfer, guessed starting loads, health-platform inputs, cloud synchronization, subscriptions, AI workout generation, exercise media or a new workout program to this sprint. Those need separate scoped specifications and review.

## Verification performed for this plan

- `dart format --output=none --set-exit-if-changed .`: passed, 47 files, zero changes.
- `flutter analyze`: passed, no issues.
- `flutter test --reporter compact`: passed, **227 tests**. This supersedes the older 222-test count in the tracker for the current checkout.
- Dependency resolution reported four newer versions outside current constraints; no packages were upgraded. This is not a completed dependency-security audit.
- Physical integration tests, signing/install, restart probes, airplane mode and accessibility were **not rerun during this planning audit**. Existing documents record earlier physical-device results; they are historical evidence, not new passes for an integrated engine.
- This change adds planning documentation only. No production behavior, schema or dependency changed, and no commit was created.
