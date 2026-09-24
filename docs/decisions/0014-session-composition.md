# ADR 0014: Deterministic owner-session composition

Follow-up: [ADR 0015](0015-reported-setup-and-rehearsal-storage.md) adds durable reported setup and rehearsal attestations consumed by the composer. Exact real setup links, safety-state persistence and the cross-store source remain pending.

Status: Day 4 backend infrastructure implemented; production activation and the full Day 4 exit gate remain incomplete. No new dependency, science rule or catalog review is introduced.

`SessionComposer` is pure Dart. It receives explicit timestamps/date, profile/setup revisions, a complete generated-history envelope, current guarded eligibility inputs, reviewed immutable program/catalog bindings and exact rehearsal verification records. It calls the public eligibility evaluator itself. Callers cannot supply a precomputed permitted gate. Bindings are trusted composition configuration tied to the exact catalog digest and review reference; there are deliberately no real enabled bindings in the app. Test reviews and catalog entries live only under test support.

Generated prescriptions use `owner-generated-v2`, with stable program ID `owner-program` and composition version `owner-session-v2`. The original manual `owner-program-v1` templates and stored history are unchanged. The new binding contract permits the approved Tuesday lying-curl alternative and supported knee-raise/kneeling-rollout identities without renaming historical exercises. Selection follows the approved preference order and needs both an eligible catalog entry and an exact current confirmed setup/baseline. Ambiguous multiple baselines require explicit setup selection. Missing coverage cannot silently skip the preferred alternative. Catalog laterality, tracking and equipment requirements must match the selected private setup.

The composer preserves all work sets, reps and working RIR. It emits five minutes of walking once, separately rehearses both superset members before round one, and alternates their working rounds. Rest is attached to the last member/side of each round. `executionOrder` exposes this ordering; storage retains ordered slots, block IDs and set indices. There is no optional finisher or time-based restructuring. No duration model has been approved, so estimates remain null with `duration_estimate_required`, even when the preference is shorter than walking alone. Existing advisory comparison remains available for a future explicit estimate model.

External warm-ups use a separate verified rehearsal ladder, including an explicitly verified zero setting, plus the confirmed working target. The progression ladder remains strictly positive. Friday's first external-load ramp is still its incline press. Bodyweight preparation uses the approved v2 policy, exact setup revisions, separately confirmed assistance and range references. An unassisted pull-up slot can contain a machine-assisted rehearsal with its own identity and quantity convention. Excluding that variation also excludes its rehearsal. A missing or stale required rehearsal blocks the whole session, with no partial executable targets. Mixed assisted/unassisted working sets remain unsupported.

Progression consumes only `GeneratedHistory`. Baseline references are deterministic SHA-256 references to the full explicit StartingLoad confirmation record, including exact setup revision/time; no load proposal mutates that record. Proposed loads, reasons and evidence revisions are stored separately from unchanged confirmed work and warm-up targets. Applying a proposal still requires the future fresh confirmation transaction. Persistent pain flags stop new generation; an active occurrence requests resumption. Neither the composer nor a corrected actual clears a restriction. Long-absence/reset policy and calendar lifecycle remain separate unresolved integration work.

## Snapshot compatibility

Recommendation payload schema 2 adds bounded generation references, per-slot reasons, proposed loads, nullable rehearsal RIR and optional per-rehearsal exercise/setup/revision/convention/verification identities. Numeric working RIR remains mandatory; working targets cannot override their slot identity. Both working and shorter rehearsal range references are retained. Actual validation resolves the exact prescribed rehearsal identity instead of mislabeling machine assistance as bodyweight.

Payload schema 1 preserves its prior canonical encoding and does not admit schema-2 target fields. Occurrence payloads and the SQLite database remain schema 1; no table migration or existing data rewrite is needed. Both recommendation payload versions coexist in the same repository. Older readers refuse new payloads instead of rewriting them. Unknown future schemas still reject. Version/reference validation accepts dotted catalog versions such as `2026.09.08.1`; opaque record IDs retain their stricter validation.

## Application boundary and remaining work

`SessionGenerationService` composes from a captured envelope and acknowledges a savable result only after `SessionGenerationSource.saveIfCurrent` succeeds. The source contract requires atomic freshness verification across every input revision, snapshot persistence and idempotent action receipts. Service fixtures cover success, blocked snapshots, retry/conflict, stale captures and storage failure.

**There is no production implementation of this source yet.** Current setup and history repositories use separate SQLite databases, and no durable safety/binding/rehearsal input source exists. A pair of independent reads, or a check followed by a separate write, is not an atomic snapshot. This change does not claim otherwise. A production adapter must establish that consistency boundary and durable verification provenance before it is registered. Native tests exercise composed snapshot persistence directly through the existing recommendation repository; they are not end-to-end live generation tests.

The real reviewed catalog/bindings, durable rehearsal verification, atomic current-input adapter, live UI/execution, target-confirmation transaction and physical offline acceptance remain pending. Consequently Monday has not passed the reviewed-real-catalog end-to-end exit criterion. Synthetic success is infrastructure evidence, not full-program activation.


## Validation

- `dart format --output=none --set-exit-if-changed .`: 72 files, zero changes.
- `flutter analyze`: no issues.
- `flutter test --reporter expanded`: 301 unit/widget tests passed.
- `flutter test integration_test/recommendation_history_repository_test.dart -d 11CA8B0D-1BBC-41FC-A1D5-865B6A47455B --no-uninstall --reporter expanded`: eight native SQLite tests passed on the authorized iPhone 17 Pro / iOS 27 simulator, using only the isolated fixture database. The expected unsupported-schema case prints a generic refusal.
- Final whitespace/diff review completed; no dependency, production UI, catalog activation or owner measurement change. Physical-device, process-termination and real-session acceptance were not run.
