# Workout-to-next-workout release loop

Status: September 30, 2026. Release integration implemented locally; production
generation and progression activation remain incomplete.

## 1. Release branch

Use `codex/workout-release-loop`, integrating `codex/stitch-workout-redesign` and
`feature/adaptive-workout-ui-redesign` (which includes `origin/main`). Preserve the
Stitch shell and its committed summary/correction flow, manual previous-set copy,
optional manual setup labels, existing offline reference library and opt-in alerts.
No dependency or training rule is added. Existing untracked `ios/` is untouched.

Package checks and the generic iOS build pass. Physical UI tests cannot launch
because the free development profile has three installed apps and cannot install
the additional test runner. No app was uninstalled to bypass that limit. UI tests
use isolated fixture paths and do not reset normal Documents stores.

## 2. Production generation prerequisites

| Requirement | Observed state | Required completion |
| --- | --- | --- |
| Real catalog | Owner slice contains disabled synthetic placeholders; real benchmark slice also has pending reviews | Review the candidate source audit in `catalog/OWNER_PROGRAM_SOURCE_REVIEW_2026_09_30.md`; complete product/science/safety/equipment/license reviews and exact approved bindings |
| Equipment | General gym inventory is separate from verified training setups | Explicit physical setup, convention, available work/rehearsal settings, revision and confirmation |
| Starting targets | Manual observations cannot establish baselines | Explicit starting-load confirmation against the current verified setup and its available ladder |
| Safety/rehearsal | Durable provenance is incomplete | Persisted current assessments and applicable rehearsal attestations; unknown remains blocked |
| Atomic generate/save | Coordinated source deliberately throws unavailable | One consistency boundary for capture, all source revisions, freshness checks, saved prescription and idempotent receipt |
| App integration | Live adaptive controller remains unregistered | Wire generation and immutable saved-workout lifecycle only after preceding requirements pass |

These requirements come from ADRs 0003, 0006, 0012–0016 and the catalog contract.
Software implementation cannot supply missing review approvals. Broad wger
equipment categories are reference metadata, not verification of a physical machine.
Brand/model and displayed load alone do not establish equivalent resistance.

## 3. Progression prerequisites

The existing approved policy consumes complete generated history, including
intervening incomplete/incomparable exposures. Manual history must remain manual.
Preserve profile/slot/context isolation and corrections, plus the separate proposed
load and confirmed target boundary. A target change requires the fresh confirmation
transaction described in ADR 0014; a proposed load is not an executable target.

Long-absence/reset integration remains an unresolved product decision in ADR 0014.
Do not infer an absence threshold, automatic reduction, or equipment equivalence.
Once generation is eligible, app-level fixtures must cover increase, decrease,
hold, skipped/interrupted sets, missing RIR, insufficient history, changed setup,
corrections, missed sessions and restart/resume. Synthetic policy success does not
establish the real workout-to-next-workout loop.

## Phone inspection

Copied Documents read-only to a private local backup before device testing.
All four copied databases passed SQLite integrity checks. A second copy after the
device build/install attempt had identical rows in every table of the four stores;
workout payloads, revisions and receipts were preserved. No user data is included
in this repository report or in test fixtures. This is snapshot integrity evidence,
not acceptance of future logging, airplane mode or force-close behavior.
