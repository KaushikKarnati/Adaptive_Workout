# Recovery policy review packet

Status: required policy definition; no scientific thresholds or activation approved.

The owner requested optional Health observations and recovery-aware adaptive
programs. This expands the earlier private-build input scope. Collection alone
never makes a sample an appropriate decision input.

| Category | Current representation | Review required before prescription influence |
| --- | --- | --- |
| App sets | Existing manual/generated histories remain distinct | Complete comparable eligible exposure definition; manual observations are not verified baselines |
| Outside workouts | Source UUID and start/end interval | Semantic duplicate handling, activity-to-fatigue mapping, overlap with app activity, intensity limitations |
| Sleep | Raw stage and interval per source | Source reconciliation, stage exclusions, sleep-day boundaries, minimum coverage and missing data |
| HRV | SDNN milliseconds | Personal baseline/coverage, source comparability, confounding and defensible response rules |
| Resting heart rate | Beats/minute | Personal baseline, freshness, confounding, missing data and defensible response rules |
| Steps/active energy | Raw source samples | Avoid duplicate device sources and double-counting workout energy; determine whether a metric is useful |
| Weight/body fat/lean mass | kg and fractional body fat | Descriptive trends initially; no recovery or nutrition inference |

Required policy output: reviewed evidence references and reviewer roles; supported
population; explicit source validity/coverage/freshness; optional-input fallback;
fatigue/recovery interpretation; allowable changes to sets/exercises/order;
progression interaction; lock conflicts; absence/reset behavior; stable reason
codes; deterministic model version; normal/boundary/invalid/missing-data cases.
No implementer may invent percentages, cutoffs, decay curves or automatic load
reductions to make the generator appear complete.

Activation sequence: validated collection, approved policy, isolated replay,
shadow-only comparison, owner review of differences, then explicit per-metric
activation. Missing mandatory safety/equipment/baseline evidence always blocks,
regardless of Health data availability. Body measurements remain descriptive.
