# Owner-program source review candidates — September 30, 2026

Status: source audit only. No runtime bindings, catalog approvals or equipment
verification are created by this document. Candidate names are not equivalence
decisions. All five reviews remain pending.

Source: bundled September 25 wger exerciseinfo snapshot, 912 records.
Compressed SHA-256: `b5d2b042f8c859a9c7ce419932ee4d5c1b56d066fe5aa87c678625eb92ae0789`.
The live equipment endpoint was checked September 30 and returned the same 12
broad categories present in the snapshot. See [wger equipment API](https://wger.de/api/v2/equipment/?format=json).

The broad machine category is Cable machine. Numerous machine-named exercises
have an empty equipment array. Treat that as missing requirements, never as
approval to execute without equipment. Source taxonomy does not establish a
manufacturer, pulley ratio, machine instance, load convention or available ladder.

| Program variant | Source candidate | Source equipment | Review gap |
| --- | --- | --- | --- |
| `incline_dumbbell_press` | [Incline Bench Press - Dumbbell](https://wger.de/api/v2/exerciseinfo/537/), base ID 537, translation ID 210 | Dumbbell, Incline bench | Identity, classification, safety, requirements and license review pending. |
| `neutral_grip_lat_pulldown` | [Neutral Grip Lat Pulldown](https://wger.de/api/v2/exerciseinfo/1510/), base ID 1510, translation ID 2469 | Cable machine | Identity, classification, safety, requirements and license review pending. |
| `incline_machine_press` | No candidate selected | Unknown | Exact variant/source and requirements unresolved |
| `chest_supported_row` | No candidate selected | Unknown | Exact variant/source and requirements unresolved |
| `cable_lateral_raise` | [Cable Lateral Raises (Single Arm)](https://wger.de/api/v2/exerciseinfo/1378/), base ID 1378, translation ID 2345 | Cable machine | Source is single arm; approved manual slot is bilateral. Laterality review required. |
| `cable_chest_fly` | [Cable Fly Middle Chest](https://wger.de/api/v2/exerciseinfo/1689/), base ID 1689, translation ID 2808 | Cable machine | Identity, classification, safety, requirements and license review pending. |
| `leg_press` | [Leg Press](https://wger.de/api/v2/exerciseinfo/371/), base ID 371, translation ID 788 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `leg_extension` | [Leg Extension](https://wger.de/api/v2/exerciseinfo/369/), base ID 369, translation ID 804 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `seated_leg_curl` | [Leg Curls (sitting)](https://wger.de/api/v2/exerciseinfo/366/), base ID 366, translation ID 117 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `lying_leg_curl` | [Leg Curls (laying)](https://wger.de/api/v2/exerciseinfo/365/), base ID 365, translation ID 154 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `machine_calf_raise` | [Machine Seated Calf Raise](https://wger.de/api/v2/exerciseinfo/2628/), base ID 2628, translation ID 5056 | Empty source list; requirements unknown | Source is seated; program machine variant is not specified. |
| `cable_crunch` | No candidate selected | Unknown | Exact variant/source and requirements unresolved |
| `machine_shoulder_press` | [Shoulder Press, on Machine](https://wger.de/api/v2/exerciseinfo/543/), base ID 543, translation ID 152 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `dumbbell_shoulder_press` | [Shoulder Press, Dumbbells](https://wger.de/api/v2/exerciseinfo/567/), base ID 567, translation ID 123 | Dumbbell | Identity, classification, safety, requirements and license review pending. |
| `reverse_pec_deck` | [Pec deck rear delt fly](https://wger.de/api/v2/exerciseinfo/1775/), base ID 1775, translation ID 2909 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `cable_curl` | [Cable Curls](https://wger.de/api/v2/exerciseinfo/1531/), base ID 1531, translation ID 2489 | Cable machine | Identity, classification, safety, requirements and license review pending. |
| `overhead_cable_triceps_extension` | [Overhead Cable Tricep Extension](https://wger.de/api/v2/exerciseinfo/1513/), base ID 1513, translation ID 2472 | Cable machine | Identity, classification, safety, requirements and license review pending. |
| `supported_knee_raise` | No candidate selected | Unknown | Exact variant/source and requirements unresolved |
| `unassisted_pull_up` | [Pull-ups](https://wger.de/api/v2/exerciseinfo/475/), base ID 475, translation ID 107 | Pull-up bar | Grip and execution review required. |
| `assisted_machine_pull_up` | [Pull Ups on Machine](https://wger.de/api/v2/exerciseinfo/477/), base ID 477, translation ID 140 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `seated_cable_row` | [Seated Cable Row](https://wger.de/api/v2/exerciseinfo/1117/), base ID 1117, translation ID 2086 | Cable machine | Identity, classification, safety, requirements and license review pending. |
| `single_arm_cable_pulldown` | [Single-Arm Lat Pulldown](https://wger.de/api/v2/exerciseinfo/1972/), base ID 1972, translation ID 3127 | Cable machine | Identity, classification, safety, requirements and license review pending. |
| `machine_chest_fly` | [Machine chest fly](https://wger.de/api/v2/exerciseinfo/926/), base ID 926, translation ID 1205 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `hack_squat` | [Hack Squats](https://wger.de/api/v2/exerciseinfo/1414/), base ID 1414, translation ID 2383 | Empty source list; requirements unknown | Identity, classification, safety, requirements and license review pending. |
| `kneeling_ab_wheel` | [Ab wheel](https://wger.de/api/v2/exerciseinfo/1573/), base ID 1573, translation ID 2521 | none (bodyweight exercise) | Source does not establish the approved knee-supported setup or rehearsal requirements. |

## Required review output

For each selected source record retain the actual base/translation IDs and UUIDs,
independent licenses and authorship, source timestamps and evidence reference.
Then review controlled taxonomy mappings, laterality, tracking convention, exact
equipment requirements and capabilities. Only after all five explicit approvals
may availability become enabled and an exact catalog-digest binding be registered.

Unsupported matches above deliberately remain unresolved. In particular, do not
substitute a Smith/multi-press record for an incline machine press, a dumbbell row
for an unspecified chest-supported machine, hanging raises for supported knee
raises, or an unrelated crunch for cable crunch. Owner-reviewed source identity
and exact requirements must settle those cases.

Physical equipment confirmation remains separate even after catalog review.
Use a stable setup selected once per gym rather than arbitrary labels on each set.
Displayed load values are comparable only within a confirmed measurement/setup
context; this document does not add cross-machine conversion rules.
