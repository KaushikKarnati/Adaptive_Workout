# Exercise Catalog Specification

Status: minimal V1 internal data contract approved; catalog contents, taxonomies, and selection rules remain subject to separate review.

## Purpose and boundary

This contract defines the smallest internal representation needed to ingest a pinned wger snapshot, review exercises, support future deterministic selection, and preserve licensing provenance. It does not approve any exercise, muscle or equipment claim, substitution, scoring factor, or workout rule.

Raw wger responses are untrusted source data. They must be mapped into this contract before storage or domain use. Source and presentation fields never become implicit engine inputs.

## Snapshot manifest

Every bundled catalog contains one immutable manifest:

| Field | Type | Requirement |
| --- | --- | --- |
| `schemaVersion` | string | Version of this contract; non-empty and supported by the app |
| `catalogVersion` | string | Unique immutable version assigned to the reviewed output snapshot |
| `provider` | enum | Exactly `wger` in V1 |
| `upstreamBaseUrl` | HTTPS URL | Canonical wger source endpoint |
| `retrievedAt` | UTC timestamp | Time the source snapshot was retrieved |
| `sourceRevision` | string or null | Upstream release or revision when available; null has explicit unknown meaning |
| `entryCount` | non-negative integer | Must equal the number of bundled entries |
| `contentSha256` | lowercase hex string | SHA-256 of the canonicalized entries payload |
| `importToolVersion` | string | Version of the deterministic importer |

Canonical serialization and hashing rules must be fixed before importer implementation. A manifest or digest mismatch invalidates the entire catalog; the app must not partially load it.

## Exercise entry

Every exercise entry contains the following groups.

### Identity and source

| Field | Type | Requirement |
| --- | --- | --- |
| `id` | string | Stable Adaptive Workout identifier; unique, non-empty, and never reused |
| `wgerUuid` | UUID | Required and unique within the catalog |
| `wgerSourceUrl` | HTTPS URL | Direct human-readable source reference |
| `sourceModifiedAt` | UTC timestamp or null | Upstream modification time when supplied |

The internal `id` is used by workout history. It must not change merely because a display name or upstream numeric identifier changes.

### Licensed presentation content

| Field | Type | Requirement |
| --- | --- | --- |
| `name` | plain-text string | Required, trimmed, and non-empty |
| `aliases` | set of plain-text strings | Optional; normalized, unique, and sorted canonically |
| `instructions` | plain-text string or null | Optional; null means no reviewed instructions |
| `language` | BCP 47 tag | Exactly `en` for the initial catalog |

HTML, scripts, embedded media, markup links, and control characters are forbidden. Presentation content must not affect selection unless the same concept is represented by a separately approved engine field.

### Engine classification

| Field | Type | Requirement |
| --- | --- | --- |
| `movementPatternIds` | non-empty set of IDs | References a separately versioned, approved movement-pattern taxonomy |
| `primaryMuscleIds` | non-empty set of IDs | References a separately versioned, approved muscle taxonomy |
| `secondaryMuscleIds` | set of IDs | May be empty; must not overlap primary muscles |
| `equipmentRequirements` | set of requirement objects | Explicit equipment ID, quantity, and approved capability IDs |
| `laterality` | enum | `bilateral`, `unilateral`, or `alternating` |
| `trackingMode` | enum | `load_reps`, `reps_only`, `duration`, `distance`, or `load_distance` |
| `capabilityIds` | set of IDs | User capabilities required to make the exercise eligible; may be empty |
| `exclusionTagIds` | set of IDs | Approved limitations that make the exercise ineligible; may be empty |

Taxonomy and equipment IDs are stable identifiers, not display labels. Unknown references invalidate the entry. Sets are compared without relying on source or iteration order.

### Relationships

| Field | Type | Requirement |
| --- | --- | --- |
| `variationGroupId` | string or null | Groups materially comparable variants; null means no approved group |
| `substitutionGroupIds` | set of strings | Candidate relationship only; does not itself authorize substitution |
| `benchmark` | enum or null | `barbell_back_squat`, `flat_barbell_bench_press`, `conventional_barbell_deadlift`, or null |

At most one exercise may claim each non-null benchmark within a catalog version. Relationships do not contain selection priority, equivalence, or progression behavior; those require separately approved rules.

### License and attribution

| Field | Type | Requirement |
| --- | --- | --- |
| `licenseId` | enum | `cc0-1.0`, `cc-by-4.0`, `cc-by-sa-3.0`, or `cc-by-sa-4.0` |
| `licenseUrl` | HTTPS URL | Must match the allowlisted canonical URL for `licenseId` |
| `licenseAuthor` | plain-text string or null | Required for attribution licenses; null permitted only when the license allows it |
| `licenseTitle` | plain-text string or null | Preserved when supplied or required |
| `attributionSourceUrl` | HTTPS URL | Required source link for attribution output |
| `wasModified` | boolean | True when imported content was changed beyond permitted technical normalization |
| `modificationNote` | plain-text string or null | Required when `wasModified` is true |

ODbL and any unrecognized, missing, non-commercial, or no-derivatives license are rejected in V1. Images and videos are outside this contract and forbidden in the V1 snapshot. License metadata is displayed but never interpreted as an engine signal.

### Review and availability

| Field | Type | Requirement |
| --- | --- | --- |
| `productReview` | review record | Required |
| `scienceReview` | review record | Required |
| `safetyReview` | review record | Required |
| `equipmentReview` | review record | Required |
| `licenseReview` | review record | Required |
| `availability` | enum | `enabled` or `disabled` |
| `disabledReason` | plain-text string or null | Required when disabled; null when enabled |

Each review record contains `status` (`pending`, `approved`, or `rejected`), a stable reviewer identifier, a UTC review timestamp, and a non-empty evidence or decision reference. A pending review may omit reviewer, timestamp, and reference; approved or rejected reviews may not.

An entry is selectable if and only if `availability` is `enabled` and all five reviews are `approved`. Selectability is derived during validation and is not stored as an independently editable flag.

## Validation and failure behavior

- Required text is trimmed, length-bounded, valid Unicode, and free of HTML and control characters.
- IDs, URLs, enums, timestamps, hashes, units, and cross-references use strict allowlists and canonical forms.
- Duplicate internal IDs, duplicate wger UUIDs, duplicate benchmark claims, dangling references, contradictory review records, and license inconsistencies invalidate the affected entry.
- An enabled invalid entry fails snapshot creation. A disabled invalid entry is omitted with an auditable import error; omission cannot change another entry's identity.
- Runtime manifest, schema, or integrity failure invalidates the complete catalog and produces an explicit unavailable or no-recommendation state.
- Import and validation output is deterministic for identical source bytes, importer version, taxonomy versions, and review inputs.

Exact length limits, canonical JSON rules, taxonomy contents, equipment identifiers, and unit representation must be approved before importer code is written.

## Explicitly excluded from the minimal contract

- Sets, repetitions, load, RIR, rest, tempo, frequency, volume, or progression rules
- Exercise ranking weights or goal scores
- Readiness or health data
- User preferences or workout history
- Images, video, audio, or remote media URLs
- Live wger availability or API response state
- Free-form fields that can alter selection behavior
