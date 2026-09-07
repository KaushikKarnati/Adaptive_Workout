# ADR 0004: V1 Catalog Taxonomies and Validation Bounds

## Status

Superseded by ADR 0005 before importer implementation. Its validation and canonicalization decisions are retained; taxonomy version `v2` adds source equipment types omitted from `v1`.

## Context

The minimal exercise contract requires controlled identifiers and exact bounds before deterministic import can be implemented. Using upstream labels directly would allow spelling, translation, ordering, or schema changes to alter domain inputs.

## Decision

Adopt taxonomy version `v1`, validation bounds, URL allowlists, and canonical representation rules in `docs/EXERCISE_TAXONOMIES.md`.

Catalog entries and set-valued identifiers are sorted before RFC 8785 JSON canonicalization and SHA-256 hashing. Unknown mappings are never inferred. Functional capabilities and limitation conflicts describe explicit actions and constraints rather than medical conditions.

## Consequences

- Import behavior can be deterministic, bounded, and resistant to malformed upstream content.
- Wger labels require explicit reviewed mappings to internal IDs.
- Muscle IDs remain categorical and cannot be interpreted as volume weights.
- Equipment presence and capabilities must be verified for the initial facility rather than inferred from the phrase full-service gym.
- Changing an ID's meaning requires a new taxonomy version and migration.

## Alternatives considered

### Use wger numeric IDs directly

Rejected because they are upstream implementation details and do not establish approved internal meaning.

### Permit arbitrary tags

Rejected because free-form values would weaken validation, deterministic behavior, and reviewability.

### Hash ordinary serialized JSON

Rejected because object-property and set ordering could produce different digests for equivalent data. RFC 8785 provides a defined canonical JSON representation.
