# ADR 0008: Approved warm-up target policy

> Historical v1 decision. [ADR 0011](0011-approved-warmup-v2.md) adds the owner-approved bodyweight/assistance and continuation policies while preserving this calculation.

Status: accepted September 23, 2026 following explicit owner approval of `programs/WARMUP_PROPOSAL.md`.

## Decision

Implement `WarmupPolicy` as a pure target calculation using the same millionths-of-a-pound representation as the progression policy. It returns complete rehearsal targets or an explicit blocked reason. Exact percentage comparisons use BigInt multiplication, settings are sorted independently of caller order, and outputs are immutable. A verified zero setting is allowed for an unloaded machine; it does not imply zero effective resistance. No machine resistance or availability is inferred from internet examples.

The first external-load movement receives 8 reps at up to 50% and 5 at up to 75%, rounded down to verified settings, with 60/90 seconds rest. Later external-load movements receive 5 reps at up to 50% and 60 seconds rest. Five minutes of walking is a once-per-session composition requirement. Warm-ups are marked non-working sets. Bodyweight/assisted setup is unresolved and blocked.

## Consequences

This module is not wired to the sample UI or a live recommendation. Application integration must use current guarded eligibility and must not auto-advance during a rehearsal that is not comfortably easy or on a symptom report. Session composition still needs execution/transition timing and bodyweight rehearsal definitions. Unit tests do not replace those integration requirements. No new dependencies.

## Alternatives

Guessing machine resistance, rounding upward or silently omitting infeasible rehearsal sets would violate the approved contract. Repeating walking per exercise would overcount session duration.
