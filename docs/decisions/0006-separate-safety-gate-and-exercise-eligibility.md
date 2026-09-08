# ADR 0006: Separate the Safety Gate from Exercise Eligibility

## Status

Accepted for the structural product and engineering boundary on 2026-09-08. This ADR does not approve exercise-specific mappings, clinical rules or wording, or training-science behavior.

## Context

The engine needs a deterministic way to remove exercises that violate explicit hard constraints. Pain and concerning symptoms must follow a separate safety path rather than an ordinary substitution flow. Combining medical-adjacent event handling, hard feasibility filtering, ranking, and replacement in one service would weaken that boundary and make explanations difficult to audit.

## Decision

Adopt `docs/EXERCISE_ELIGIBILITY.md` as the approved structural contract and use two pure domain stages:

1. `SafetyGate` returns a blocking safety outcome or normalized hard constraints.
2. `ExerciseEligibilityFilter` partitions an explicit candidate set using only catalog selectability, exact exercise exclusions, exact limitation conflicts, explicitly assessed functional capabilities, exact equipment requirements, temporary equipment state, and applicable safety restrictions.

The filter returns canonically ordered IDs and stable structured reason codes. It never ranks candidates, chooses a substitute, relaxes a constraint, parses prose, or interprets medical information. Missing, invalid, unknown, duplicated, stale, or unversioned safety inputs fail closed.

The application exposes one guarded evaluator. The safety gate and hard filter are private implementation stages and cannot be invoked directly. The evaluator uses the trusted preconfigured catalog validator, recomputes the canonical digest of the actual explicit constraints, rejects a caller-supplied mismatch, and passes only the computed digest into exact safety-restriction matching.

The product owner approved the contract's explicit capability, equipment, exception-scope, limited safety-continuation, restriction, migration, reason, result, simplicity, and accessibility decisions on 2026-09-08. The remaining external-verification and qualified-review gates in `docs/EXERCISE_ELIGIBILITY.md` still apply before their affected behavior can ship.

## Consequences

- Pain and unresolved safety events cannot fall through to automatic replacement.
- Hard feasibility rules can be tested independently of workout science and UI.
- Later ranking and composition stages cannot reinstate an ineligible exercise.
- The application must preserve versioned constraint snapshots and safety restrictions without logging sensitive free-form health text.
- No real workout may be generated until exercise mappings and the remaining product, clinical, and training-science rules are approved.

## Alternatives considered

### One combined selection service

Rejected because filtering, medical-adjacent event handling, ranking, and replacement have different approval and failure boundaries.

### Treat pain as a limitation tag or preference exclusion

Rejected because the approved product and science documents require a separate safety path with no automatic substitution.

### Skip ineligible or malformed data and continue

Rejected because silent partial loading or constraint removal could create an unsafe recommendation and would violate deterministic fail-closed behavior.
