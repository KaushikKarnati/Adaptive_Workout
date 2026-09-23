# Benchmark Catalog Slice 2026.09.08.1

Status: source-pinned and structurally valid; all three entries are disabled pending science, safety, equipment, and licensing review.

## Scope

This slice contains exactly the three product-approved strength benchmarks:

1. Barbell back squat
2. Flat barbell bench press
3. Conventional barbell deadlift

It does not add workout selection, ranking, prescription, progression, substitution, or user-interface behavior. A real upstream record is not automatically an approved recommendation.

## Snapshot identity

- Catalog version: `2026.09.08.1`
- Schema version: `1.0.0`
- Taxonomy version: `v2`
- Import tool version: `1.0.0`
- Retrieved at: `2026-09-08T23:14:03Z`
- Upstream revision: unavailable; recorded as `null`
- Upstream endpoint: `https://wger.de/api/v2/`
- Pinned importer fixture: `test/fixtures/wger/benchmark_snapshot_2026_09_08.json`
- Pinned fixture SHA-256: `ddd51de5e62e43fb768085840173b77c6f392ba28459d02a4a5f481fd8aa5721`
- Canonical reviewed-entry SHA-256: `4bda4d4b43bba409c66585acb76d88c871cda97d9b13ca0fe732595488578eb4`

The fixture retains the source fields required by the deterministic mapper and intentionally excludes media, rendered HTML, and community notes. It is a pinned import fixture rather than an archival copy of every field returned by the API.

## Source records and attribution

| Approved benchmark label | Wger base | English translation | Source label | Author | License |
| --- | ---: | ---: | --- | --- | --- |
| Barbell Back Squat | [615](https://wger.de/api/v2/exerciseinfo/615/) | [111](https://wger.de/en/exercise/111/view) | Squats | wger.de | CC-BY-SA 3.0 |
| Flat Barbell Bench Press | [73](https://wger.de/api/v2/exerciseinfo/73/) | [192](https://wger.de/en/exercise/192/view) | Bench Press | sistab2 | CC-BY-SA 3.0 |
| Conventional Barbell Deadlift | [184](https://wger.de/api/v2/exerciseinfo/184/) | [105](https://wger.de/en/exercise/105/view) | Deadlifts | wger.de | CC-BY-SA 3.0 |

The base and English translation attribution are stored separately on every entry. The canonical license URL is `https://creativecommons.org/licenses/by-sa/3.0/`.

## Modifications

Each record is marked modified because:

- The display name is normalized to the exact product-approved benchmark label.
- The original source name is retained as an alias.
- Upstream instructions are omitted until editorial, science, and safety review is complete.
- Wger offset timestamps with fractional seconds are converted to UTC and truncated to the catalog contract's required second precision.

Images, videos, rendered HTML, and community notes are not imported.

## Proposed inactive classifications

The typed entries contain proposed movement, capability, limitation-conflict, and enriched equipment fields so reviewers have a concrete artifact to evaluate. These values are inactive because the corresponding reviews remain pending.

| Benchmark | Pattern | Wger muscle roles preserved | Proposed equipment enrichment |
| --- | --- | --- | --- |
| Barbell Back Squat | `squat` | primary `quadriceps`; secondary `glutes` | barbell, plates, power rack with adjustable height and safety arms |
| Flat Barbell Bench Press | `horizontal_push` | primary `chest`; secondary `front_deltoids`, `triceps` | barbell, plates, flat bench, power rack with adjustable height and safety arms |
| Conventional Barbell Deadlift | `hinge` | primary `lats`; secondary `glutes` | barbell and plates |

The deadlift muscle roles look incomplete for product use, but they deliberately preserve the upstream categorical roles rather than silently inventing a correction. Science review must approve any revised classification in a new immutable catalog version.

## Review state

| Review | State | Reason |
| --- | --- | --- |
| Product | Approved | `docs/SCIENCE.md` already identifies these exact three benchmark variations. |
| Science | Pending | Movement, muscle, capability, and limitation mappings need evidence review. |
| Safety | Pending | Technique assumptions, safety constraints, and user-facing instructions are not approved. |
| Equipment | Pending | Rack capabilities, plate quantity semantics, and the initial gym inventory require verification. |
| License | Pending | Attribution is structurally present, but commercial distribution and ShareAlike handling still require the planned licensing review. |

Because four required reviews are pending, every entry is `disabled` and `isSelectable == false`. The sample workout UI and eligibility engine do not load this slice.

## Re-enablement rule

Do not change these records to enabled in place. Complete the four pending reviews, preserve their evidence references and timestamps, update any proposed mapping through explicit review, assign a new immutable catalog version, recompute both integrity digests, and rerun the complete catalog and eligibility test suites.
