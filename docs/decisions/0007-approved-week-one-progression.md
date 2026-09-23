# ADR 0007: Implement approved week-one progression as a pure policy

Status: accepted September 23, 2026. The owner explicitly approved `programs/WEEK_ONE_RULES_PROPOSAL.md`.

## Decision

Implement P4–P6 and the P9 hold boundary in a standalone domain policy first. It consumes explicit immutable snapshots and returns a candidate adjustment with the rule version, evidence identifiers and reason. It is not a complete workout recommendation and is not connected to the sample UI. Current safety/eligibility approval must be supplied by the future application orchestration; unknown or blocked gates return no load. A safety-stop gate takes precedence over adjustment logic.

Use integer millionths of a pound for this policy's load boundary, with exact BigInt cross-multiplication for percentage ceilings. This is storage/calculation precision, not an equipment increment or display prescription. Input adapters must later reject unsupported precision and validate/normalize units. Actual machine resistance is not inferred from displayed weight.

History is scoped by profile and program slot, ordered by explicit unique sequence and UTC date, and checked against the exact current context. Inspect the latest two exposures; never remove incomplete or incomparable intervening records. Repository integration must supply the complete slot history, including interrupted/skipped records, and handle corrections before evaluation. Duplicate identities or sequences fail closed. A changed baseline context returns `baseline_required`; older incomparable evidence holds the current verified baseline.

## Consequences

No dependency, network, database, widget or wall-clock access is added. Synthetic unit tests cover the approved examples, percentage boundaries, missing/invalid data, unilateral evidence, history permutations, profile isolation and gate precedence. Catalog review, baseline capture, persistence, warm-up and full-session duration remain separate work. A software policy approval does not approve pending real catalog records.

## Alternatives

Floating-point percentage comparisons risk boundary drift. Inferring defaults or filtering away invalid history would violate the approved explicit-input rules. Wiring the policy directly to widgets would bypass the intended application and repository layers.
