# Week-one rules — approved owner policy

> Follow-up decisions: [Day-one contracts](DAY_ONE_CONTRACTS_2026_09_23.md) approve user-selected schedule/duration, early-end advancement, explicit target confirmation and Tuesday's lying-curl alternative. The program was created with ChatGPT and adopted by the owner; no independent trainer review is recorded. Historical v1 prescriptions remain unchanged until versioned readers and bindings are implemented.

Status: APPROVED by the owner on September 23, 2026: “the rules look good and I approve these.” Rule version: `owner-program-v1`. Rules P1–P10 and the logging conventions may be implemented. Unresolved warm-up, timing, equipment and review prerequisites listed below remain unresolved; approval does not enable the real catalog or complete session generation.

## Evidence boundary

The [2026 ACSM position stand](https://www.fisiologiadelejercicio.com/wp-content/uploads/2026/03/Resistance-Training-Prescription-for-Muscl.pdf) synthesizes 137 systematic reviews of resistance training in healthy adults. Its practical discussion supports a target of 2–3 repetitions in reserve (RIR); training to failure is not necessary. This is population-level evidence, not validation of this individual's program, exact superset timing, or the algorithm below. The publisher link was inaccessible to the research tool; the linked copy is the published primary paper, DOI `10.1249/MSS.0000000000003897`.

The [official ACSM summary](https://www.acsm.org/wp-content/uploads/2026/03/Resistance-Training-Position-Stand-infographic.pdf) emphasizes consistent participation and gradual development. Neither source establishes the exact two-exposure, five-percent, regression, or rest-selection policies proposed here. Those are explicit product choices approved by the owner and requiring implementation tests.

## Already approved by the owner

- Use the supplied five-session program for week one; defer the old barbell benchmark goals.
- Monday and Friday final supersets have three paired rounds, including three fly sets.
- One initial tester; pounds; iOS support starts at iOS 17 under the native migration (ADR 0018).

## Approved rules

| ID | Rule | Basis |
| --- | --- | --- |
| P1 Effort | Target 2–3 RIR on working sets; never prescribe intentional failure. RIR is reported by the user, not inferred from repetitions. | Evidence-informed target; reporting policy |
| P2 Starting load | Require an explicitly verified working-load baseline for the exact exercise, machine/setup and load convention. No guessed starting load, body-weight formula, or maximum test. Missing baseline returns `baseline_required`; reviewed manual baseline entry remains available. | Product policy |
| P3 Rest | Use the upper end of each supplied rest range. Where absent: 120 seconds for leg press, shoulder press, pull-ups and hack squat; 90 seconds for single-arm pulldown after both sides; 60 seconds for hanging knee raises. Superset rest starts after the second exercise; allow actual setup/transition time without urging the user to rush. | Proposed defaults, not proven optimal |
| P4 Increase | For external-load exercises, require the last two consecutive comparable completed exposures to meet the top of the rep range on every prescribed working set with RIR ≥2. Use the smallest verified equipment increment only if the increase is ≤5%. Keep set counts and rep range unchanged. Otherwise hold with an explanation. | Product policy |
| P5 Reduce | If both of the last two comparable completed exposures contain any working set below the rep minimum or RIR 0–1, propose the nearest available lower load, only if its reduction is ≤10%. If no such load exists, request baseline review rather than guessing. Do not increase volume to compensate. | Product policy |
| P6 Hold / unknown | One strong or weak exposure alone holds the verified load. Incomplete, skipped, invalid, missing-RIR, noncomparable or corrected-out evidence cannot authorize an increase or reduction. Keep the last verified target only if the current safety/equipment/baseline checks pass; show `insufficient_evidence`. | Product policy |
| P7 Alternatives | Prefer machine shoulder press, then dumbbells; seated leg curl, then lying. A candidate must have a reviewed catalog record, current eligibility and its own verified baseline. For pull-ups, use a verified unassisted baseline if present; otherwise a verified assisted-machine baseline. No baseline transfer across machines or variations. | Product policy |
| P8 Unsupported replacement | For other movements, an unavailable exercise blocks the complete session until a reviewed replacement and its prescription exist. Do not invent substitutions from similar names or muscle labels. Supersets require both stations to be usable; occupied stations do not silently change the program. | Product policy |
| P9 Bodyweight / assistance | Hold the reviewed baseline for pull-up assistance, knee raises and ab-wheel work this week. No automatic reduction in assistance, added weight, leverage or range-of-motion progression. Preserve actual reps for later review. | Bounded scope proposal |
| P10 Safety | Existing safety gate takes precedence over every rule. Pain/concerning symptoms stop the affected exercise, preserve the report and prohibit automatic replacement or increases. Invalid or missing required safety inputs block recommendations. | Existing approved contract |

A comparable exposure means the same profile, program session slot, exercise variation, equipment/setup, load convention, set count and rep range, with all prescribed working sets complete at the same verified load. Use stable session sequence and explicit dates; do not skip an intervening incomplete exposure to manufacture a two-session streak. Historical corrections invalidate affected evidence and force future recalculation without rewriting old recommendations.

Loads entered for dumbbell exercises are pounds per dumbbell; machine/cable values are the displayed setting tied to the exact machine, not a claim about effective resistance. Plate-loaded machines require an explicit plates-only versus total-load convention. Unilateral sets need left/right results; both sides must qualify. Assistance is a separate quantity with inverse difficulty semantics, never ordinary external load. These logging conventions were included in the owner approval.

## Worked examples for tests

These are synthetic software fixtures, not instructions to lift these weights. Assume current safety, eligibility and baseline checks pass unless stated otherwise.

| Input | Expected output / reason |
| --- | --- |
| 3 × 8–12; 50 lb; last two exposures each 12/12/12 reps, all RIR 2; available next load 52.5 | 52.5 lb; `progress_two_qualifying_exposures` |
| Same evidence; next load 55 | Hold 50; `increment_above_five_percent` |
| Only one qualifying exposure | Hold 50; `insufficient_progression_streak` |
| Last exposure 12/11/12 at RIR 2 | Hold 50; `rep_ceiling_not_met` |
| Two complete exposures each include 7 reps or RIR 1; next lower load 47.5 | 47.5; `reduce_two_underperforming_exposures` |
| Same reduction evidence; next lower load 40 | No new load; `baseline_review_required` |
| Missing RIR, warm-up only, skipped set or incomplete session | No automatic adjustment; `insufficient_evidence` |
| Negative load, nonfinite number, fractional reps, unknown units | Reject entered action; preserve prior durable record |
| Machine changed, setup changed or baseline absent | No transferred load; `baseline_required` |
| Reported pain despite progression evidence | Safety stop; no replacement/increase |
| Monday fly and lateral raise blocks | Exactly 3 paired rounds, 6 working sets total |
| Same complete explicit input with reordered catalog | Identical result and explanation |

## Still required before full session generation

The approved rules do not complete warm-up or time-feasibility contracts. Obtain a reviewed warm-up protocol and actual setup/transition expectations before promising 45–60 minutes. Never shorten rest or drop working sets invisibly to fit a timer. The five-minute optional finisher should remain off by default until its selection/intensity and duration accounting are approved.

Proposed scheduling policy for later review: preserve session order after misses, no catch-up volume, resume an interrupted draft, and require an explicit choice before abandoning a partial workout. A long absence needs an approved baseline-reconfirmation rule; do not invent a detraining percentage.

The earlier skip list remains excluded from proposed alternatives. Exact machine identities, increments, equipment capability, age/experience and current safety inputs remain to be verified. Owner approval of software policy does not complete exercise science, safety, equipment or licensing reviews automatically.
