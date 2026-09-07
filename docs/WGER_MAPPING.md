# Wger Source Mapping Specification

Status: deterministic source-field and dictionary mappings approved from the live wger API observed on 2026-09-07. Individual exercise classifications remain subject to manual review.

## Source boundary

The importer reads a pinned response from the wger `exerciseinfo`, `exercisecategory`, `muscle`, `equipment`, `license`, and `language` endpoints. It never maps by display text alone. Every known source dictionary entry is identified by both numeric ID and expected name; a missing entry, unexpected duplicate, or ID/name mismatch fails the import for review.

Only exercise bases with exactly one selected English translation using language ID `2` and short name `en` proceed to mapping. The importer does not fall back to another language, machine translation, or a name from another record.

## Identity mapping

| Internal field | Wger source |
| --- | --- |
| `id` | `wger_` plus lowercase base UUID with hyphens removed |
| `wgerBaseId` | Exercise-base `id` |
| `wgerBaseUuid` | Exercise-base `uuid` |
| `wgerTranslationId` | Selected English translation `id` |
| `wgerTranslationUuid` | Selected English translation `uuid` |
| `wgerApiUrl` | `https://wger.de/api/v2/exerciseinfo/{wgerBaseId}/` |
| `wgerPageUrl` | `https://wger.de/en/exercise/{wgerTranslationId}/view` |
| `sourceModifiedAt` | Exercise-base `last_update_global`, or null only when absent in the pinned source |

Numeric IDs are provenance only. Workout history and internal relationships use the stable internal `id`.

## Presentation mapping

| Internal field | Wger source and rule |
| --- | --- |
| `name` | Selected English translation `name`, after allowed Unicode normalization and validation |
| `aliases` | Each selected English `aliases[].alias` value; every alias must satisfy the contract independently |
| `instructions` | Selected English `description_source` converted only by the approved plain-text converter; null when empty or not safely convertible |
| `language` | Literal `en` |

Rendered `description` HTML is never imported. Unknown markup, embedded URLs, unsupported formatting, or active content causes instructions to become pending for manual review; it is not silently stripped into approved text.

Translation `notes` are not imported in V1. They are community-authored coaching statements requiring separate scientific, safety, ordering, and presentation review and cannot be merged automatically into instructions.

## Muscle mapping

Primary and secondary source lists preserve their role while mapping IDs. These mappings are categorical normalization only and do not assign volume weights.

| Wger ID and expected name | Internal muscle ID |
| --- | --- |
| `1` Biceps brachii | `biceps` |
| `2` Anterior deltoid | `front_deltoids` |
| `4` Pectoralis major | `chest` |
| `5` Triceps brachii | `triceps` |
| `6` Rectus abdominis | `abdominals` |
| `7` Gastrocnemius | `calves` |
| `8` Gluteus maximus | `glutes` |
| `9` Trapezius | `trapezius` |
| `10` Quadriceps femoris | `quadriceps` |
| `11` Biceps femoris | `hamstrings` |
| `12` Latissimus dorsi | `lats` |
| `14` Obliquus externus abdominis | `obliques` |
| `15` Soleus | `calves` |

Wger muscle `3` Serratus anterior and `13` Brachialis have no approved minimal internal equivalent. Any exercise referencing either remains rejected from the bundled catalog until a taxonomy extension or explicit scientifically reviewed mapping is approved. The importer must not coerce them to chest, upper back, or biceps.

## Equipment mapping

Source equipment produces only an initial requirement candidate. Manual equipment review may add weight plates, racks, attachments, safety features, or a more specific machine, but may not remove a source requirement without a recorded evidence decision.

| Wger ID and expected name | Internal requirement candidate |
| --- | --- |
| `1` Barbell | `standard_barbell` |
| `2` SZ-Bar | `ez_curl_bar` |
| `3` Dumbbell | `dumbbells` |
| `4` Gym mat | `exercise_mat` |
| `5` Swiss Ball | `stability_ball` |
| `6` Pull-up bar | `pull_up_station` |
| `7` none (bodyweight exercise) | `bodyweight_space` |
| `8` Bench | `flat_bench`, pending confirmation for the individual exercise |
| `9` Incline bench | `adjustable_bench` with `adjustable_angle` |
| `10` Kettlebell | `kettlebells` |
| `11` Resistance band | `resistance_bands` |
| `12` Cable machine | `cable_station`; pulley and attachment capabilities remain pending |

An empty wger equipment list maps to no candidate and forces equipment review to remain pending. It does not mean bodyweight or no equipment.

## Category handling

Wger categories are retained only in the source audit record:

- `8` Arms
- `9` Legs
- `10` Abs
- `11` Chest
- `12` Back
- `13` Shoulders
- `14` Calves
- `15` Cardio

Categories never map to a movement pattern, muscle, tracking mode, or selection role. Those values require per-exercise review.

## License mapping

Base and selected-translation license data are mapped independently into `baseAttribution` and `translationAttribution`.

| Wger ID and expected short name | Internal license ID | Result |
| --- | --- | --- |
| `1` CC-BY-SA 3 | `cc-by-sa-3.0` | Allowed with attribution review |
| `2` CC-BY-SA 4 | `cc-by-sa-4.0` | Allowed with attribution review |
| `3` CC0 | `cc0-1.0` | Allowed with provenance retained |
| `4` CC-BY 4 | `cc-by-4.0` | Allowed with attribution review |
| `5` ODbL | none | Rejected in V1 |

The importer uses the contract's canonical license URLs, preserves supplied author and title fields, and records changes. Missing authorship on an attribution license remains pending; the importer does not invent an author.

## Fields requiring manual review

The following internal fields are never inferred from a wger name, description, category, image, or neighboring exercise:

- Movement-pattern IDs
- Functional capability IDs
- Limitation-conflict IDs
- Laterality
- Tracking mode
- Additional equipment and capability requirements
- Variation and substitution groups
- Benchmark identity
- Every product, science, safety, equipment, and license review decision
- Enabled or disabled availability

Until these fields and all required reviews are complete, the source exercise cannot appear in the bundled selectable catalog.

## Upstream change behavior

The pinned source snapshot includes the complete dictionaries used for mapping. A new or changed source ID, name, license, schema field, or English-translation cardinality produces a stable import error. Updating a mapping requires documentation review, test fixtures, a new importer version, and a new catalog version; it never occurs automatically at runtime.
