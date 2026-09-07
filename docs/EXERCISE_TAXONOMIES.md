# V1 Exercise Taxonomies and Validation Bounds

Status: taxonomy version `v2` approved for the minimal V1 catalog contract. Workout-selection meaning remains unapproved.

## Scope

These identifiers describe reviewable catalog facts. Their presence does not make an exercise safe, suitable, equivalent, or preferred. Selection rules may use an identifier only after the corresponding scientific and product behavior is separately approved and tested.

Taxonomy version `v1` was superseded before importer implementation after live-source inspection identified two missing equipment types. Taxonomy version `v2` adds `ez_curl_bar` and `stability_ball` and is immutable. Adding, removing, renaming, merging, or changing the meaning of an ID requires a new taxonomy version and catalog migration. Display labels may change without changing ID meaning.

## Movement-pattern IDs

- `squat`
- `hinge`
- `lunge`
- `horizontal_push`
- `vertical_push`
- `horizontal_pull`
- `vertical_pull`
- `loaded_carry`
- `elbow_flexion`
- `elbow_extension`
- `knee_flexion`
- `knee_extension`
- `hip_abduction`
- `hip_adduction`
- `shoulder_abduction`
- `shoulder_external_rotation`
- `calf_raise`
- `trunk_flexion`
- `trunk_extension`
- `trunk_rotation`
- `anti_extension`
- `anti_rotation`
- `anti_lateral_flexion`
- `mobility`

An exercise may have more than one pattern. No primary-pattern ranking is implied.

## Muscle IDs

- `chest`
- `lats`
- `upper_back`
- `trapezius`
- `front_deltoids`
- `side_deltoids`
- `rear_deltoids`
- `biceps`
- `triceps`
- `forearms_grip`
- `abdominals`
- `obliques`
- `spinal_erectors`
- `quadriceps`
- `hamstrings`
- `glutes`
- `hip_adductors`
- `hip_abductors`
- `calves`

Primary and secondary designations are categorical V1 claims, not contribution weights. The engine must not infer training volume fractions from them.

## Equipment IDs

- `bodyweight_space`
- `exercise_mat`
- `standard_barbell`
- `ez_curl_bar`
- `weight_plates`
- `power_rack`
- `flat_bench`
- `adjustable_bench`
- `dumbbells`
- `kettlebells`
- `stability_ball`
- `cable_station`
- `pull_up_station`
- `dip_station`
- `smith_machine`
- `leg_press_machine`
- `hack_squat_machine`
- `leg_extension_machine`
- `leg_curl_machine`
- `chest_press_machine`
- `shoulder_press_machine`
- `row_machine`
- `lat_pulldown_machine`
- `pec_fly_reverse_fly_machine`
- `hip_abduction_adduction_machine`
- `calf_raise_machine`
- `plate_loaded_machine`
- `resistance_bands`
- `cardio_machine`

Generic `plate_loaded_machine` cannot substitute for a specific machine ID. An exercise requiring a distinct machine must name that machine or remain disabled until a new ID is approved.

## Equipment-capability IDs

- `safety_arms`
- `adjustable_height`
- `adjustable_angle`
- `independent_arms`
- `dual_cable`
- `high_pulley`
- `low_pulley`
- `straight_bar_attachment`
- `rope_attachment`
- `single_handle_attachment`
- `ankle_strap_attachment`
- `weight_assistance`
- `incremental_loading`

Capabilities refine a required equipment item. They do not replace its equipment ID.

## Functional capability IDs

- `standing_supported`
- `standing_unsupported`
- `seated_supported`
- `supine_position`
- `prone_position`
- `floor_transfer`
- `overhead_arm_position`
- `front_rack_position`
- `bar_on_back_position`
- `single_leg_support`
- `deep_knee_flexion`
- `loaded_hip_hinge`
- `sustained_grip`

These describe actions or positions required by an exercise. They are not medical clearance or diagnoses.

## Limitation-conflict IDs

- `avoid_overhead_arm_position`
- `avoid_front_rack_position`
- `avoid_bar_on_back_position`
- `avoid_floor_transfer`
- `avoid_prone_position`
- `avoid_single_leg_support`
- `avoid_deep_knee_flexion`
- `avoid_loaded_hip_hinge`
- `avoid_sustained_grip`

These tags represent explicit user constraints. The app must not infer one from a diagnosis, pain report, health record, or another tag. Pain follows the separate safety path.

## Exact validation bounds

| Value | Bound or form |
| --- | --- |
| Catalog entries | 1 to 5,000 |
| Decompressed entries payload | At most 16 MiB |
| `schemaVersion` | Semantic version `MAJOR.MINOR.PATCH`, each component 0 to 999 |
| `catalogVersion` | `YYYY.MM.DD.N`, where `N` is 1 to 999 |
| `importToolVersion` | Same form as `schemaVersion` |
| Stable IDs and taxonomy IDs | `^[a-z][a-z0-9_]{1,63}$` |
| `sourceRevision` | Null or 1 to 128 printable ASCII characters |
| Name | 1 to 80 Unicode scalar values after trimming |
| Alias | 1 to 80 Unicode scalar values; at most 20 aliases |
| Instructions | Null or 1 to 4,000 Unicode scalar values after trimming |
| Author and license title | Null or 1 to 200 Unicode scalar values |
| Modification note | Null unless required; then 1 to 500 Unicode scalar values |
| Disabled reason | Null when enabled; otherwise 1 to 500 Unicode scalar values |
| Review evidence reference | 1 to 500 Unicode scalar values |
| Sets of IDs | At most 32 entries unless a narrower bound is stated |
| Movement patterns | 1 to 4 |
| Primary muscles | 1 to 8 |
| Secondary muscles | 0 to 12 |
| Equipment requirements | 0 to 8 |
| Capabilities per equipment requirement | 0 to 8 |
| Equipment quantity | Integer 1 to 8 |
| Substitution groups | 0 to 8 |
| URL | HTTPS, at most 2,048 ASCII characters, no credentials or fragment |
| Timestamp | RFC 3339 UTC using a trailing `Z`, second precision, no future value at import time |
| SHA-256 | Exactly 64 lowercase hexadecimal characters |

All user-visible and attribution strings must be valid Unicode, normalized to NFC before contract validation, and must contain no C0/C1 control characters except a line feed in `instructions` and review evidence text. Tabs, carriage returns, null bytes, bidi overrides, and unpaired surrogates are forbidden.

## URL allowlists

- Wger source records: host exactly `wger.de`.
- Creative Commons licenses: host exactly `creativecommons.org`, with a path matching the declared allowlisted license.
- Review evidence: repository-relative `docs/` reference or HTTPS URL from an explicitly configured evidence-source allowlist.

Redirect targets are validated again. Imported URL text is never rendered as HTML.

## Canonical representation

- JSON input conforms to I-JSON and contains no duplicate property names, non-finite numbers, or integers outside the exactly representable range.
- Entries are sorted by internal `id` before serialization.
- Every set-valued array is deduplicated and sorted by canonical ID; aliases are sorted by Unicode scalar value after normalization.
- Ordered arrays are permitted only where order is part of the contract; none exist in the minimal exercise entry.
- The entries array is serialized with RFC 8785 JCS, encoded as UTF-8, and hashed with SHA-256.
- The manifest is stored separately and is not included in its own content digest.

## Import outcomes

Every upstream record produces exactly one auditable outcome: `accepted_enabled`, `accepted_disabled`, or `rejected`. A rejected or disabled record includes stable reason codes. Import summaries include counts by outcome and reason; free-form log text must not contain imported HTML.

The importer must never guess an unknown taxonomy mapping. Missing or disputed mappings remain pending and therefore unselectable.
