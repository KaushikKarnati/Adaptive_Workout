# ADR 0010: Separate calendar preferences from ordered workout prescriptions

Status: accepted owner policy September 23, 2026; standalone domain implementation only.

## Decision

Use the user's explicit training weekdays and duration preference instead of universal owner weekday labels or a hard 45–60-minute limit. Retain the ordered program queue across misses. Completed and explicitly ended-early sessions advance once; interrupted active sessions resume. Use explicit civil dates, immutable input snapshots and stable reason codes. Duration excess is advisory. No inference about recovery or permission to train is made by calendar planning.

The pure policy has no dependencies on widgets, storage, clocks or network. Durable receipts and queue transitions remain application/repository work. Existing v1 manual prescriptions must not be mutated to add alternatives; a new version needs historical readers first. The adaptive store will use existing SQLite in a separate database, preserving practice/manual data.

## Consequences

The owner program can run against different user calendars without changing its prescriptions. An early-ended occurrence remains incomplete progression evidence even though it advances the calendar. The result is a calendar plan, not a workout recommendation. User configuration, UI, storage and review gates remain necessary before real recommendation integration.

## Alternatives

Hardcoded weekdays would mistake one person's program for a universal schedule. Advancing on elapsed days would discard missed workouts. Implicit duration-based cuts would change approved volume and rests. Mutating the existing program constant would break historical snapshot validation.

See [Day-one contracts](../programs/DAY_ONE_CONTRACTS_2026_09_23.md) for research, input/output details, worked cases and unresolved dependencies.
