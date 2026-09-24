# ADR 0015: Preserve reported setup and durable rehearsal attestations

Status: bounded Day 4 storage/composition implementation. No new dependency or training rule; real catalog activation and cross-store input capture remain pending.

Training-setup payload schema 2 adds immutable `ReportedWorkingSetup` and `RehearsalConfirmation` collections to the existing per-profile aggregate. The SQLite database stays at schema 1: existing transactions, action receipts, expected revisions and prior aggregate payloads cover these fields without a table migration. Payload schema 1 retains its canonical encoding; unknown future versions reject without clearing data. Once upgraded, an aggregate cannot downgrade and discard evidence.

Reports describe usual working sets. Exact pounds, load convention, optional load scope (per hand, stack display, each stack, total added plates or bodyweight), reported rep/RIR ranges, per-arm reporting, increment, source reference and recording time remain distinct. Missing reps/RIR stay unknown. Recording time is not a fabricated workout time. Reports never create equipment records, confirmed starting loads or progression exposures and never override program prescriptions.

Rehearsal records retain explicit easy/controlled and symptom answers, separately reported assistance or working/rehearsal range references, and an optional exact equipment ID/revision. Missing equipment identity remains a draft. Linking requires a confirmed current setup and a recording time no earlier than its confirmation. Changed equipment revisions make old attestations unusable. Existing reports and attestations are append-only under aggregate transitions; corrections require a new record, preserving prior statements. Contradictory complete current attestations yield ambiguity instead of choosing one silently. Symptom reports stop new composition; a not-easy report requires preparation review. No reset/clearance policy is invented.

`TrainingSetupController.saveIntake` appends evidence through the repository's existing transaction/retry boundary. Preference and equipment changes preserve schema-2 evidence. There is no new UI entry/import screen in this slice. A standalone draft must be merged into the actual profile with an expected revision; it must not overwrite a live profile.

`SessionComposer` resolves saved complete rehearsal attestations only through the trusted exact catalog binding and matching confirmed equipment revision. The existing guarded eligibility evaluator and warm-up policies still decide whether a session is feasible. The composer does not read reports as baselines. Missing or stale links, missing feedback, unavailable assistance and range gaps stay blocked. The lower-level explicit rehearsal input remains available for preexisting synthetic tests/authoritative callers; persistent adverse reports cannot be bypassed with it.

## Private intake handling

Owner conversation data is consolidated outside the repository in a local application-support directory with owner-only permissions. It contains reported setup and unlinked rehearsal attestations, no fabricated catalog/equipment identities or confirmed working baselines. Personal values are absent from source and synthetic test fixtures. A readable companion distinguishes reported performance, approved prescriptions and outstanding verification. No phone database was overwritten or installed by this collection step.

The user's unilateral lateral raises differ from the current template's bilateral representation. That mapping/version issue stays explicit instead of silently changing historical prescriptions. Reported below-target reps also do not change approved rep ranges. Wednesday lateral-raise actual reps/RIR remain unknown rather than being copied from a target range.

## Remaining integration

This closes the missing *storage representation* for reported setup and rehearsal attestations and connects saved exact attestations to pure composition. Exact real equipment linking, catalog reviews/bindings, durable broader safety state, the atomic cross-store generation source, live UI/import, and physical offline acceptance remain incomplete. It is not completion of the Day 4 real-Monday exit gate.

## Validation

Formatting passed for 76 files with zero changes; static analysis reported no issues; all 315 unit/widget tests passed. Six native setup-repository SQLite tests passed on the authorized iPhone 17 Pro simulator, including schema-1/schema-2 coexistence, preserved prior payloads, duplicate receipts, invalid evidence removal, rollback and reopen. Composer fixtures cover saved attestations for all three bodyweight session types, missing/stale/ambiguous references and adverse evidence that cannot be overridden by injected rehearsals. Private intake was decoded and reopened: 28 reports, four unlinked attestations, zero equipment records and zero working baselines; owner-only filesystem permissions were verified. No phone installation, live profile import, or real-session acceptance is claimed.
