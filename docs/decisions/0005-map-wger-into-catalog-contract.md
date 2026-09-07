# ADR 0005: Map Wger into the Internal Catalog Contract

## Status

Accepted.

## Context

Live wger inspection showed that exercise bases and English translations have separate identifiers and licenses. It also showed source equipment types not represented by taxonomy version `v1`. Direct or name-only mapping would lose provenance and could silently change behavior when upstream dictionaries change.

## Decision

Adopt `docs/WGER_MAPPING.md` as the deterministic upstream mapping specification and taxonomy version `v2` from `docs/EXERCISE_TAXONOMIES.md`.

Preserve base and English-translation IDs, UUIDs, URLs, and attribution separately. Match controlled source dictionaries by both ID and expected name. Map only explicitly approved muscle and equipment values. Never infer movement patterns, capabilities, limitations, tracking, relationships, benchmarks, reviews, or availability from source prose or categories.

Taxonomy `v2` adds `ez_curl_bar` and `stability_ball`. Version `v1` is superseded before importer implementation and no data migration is required.

## Consequences

- Mapping failures are visible and stable instead of silently coerced.
- Exercises referencing unsupported Serratus anterior or Brachialis mappings cannot enter the bundled catalog yet.
- Wger equipment remains a candidate requiring per-exercise review and enrichment.
- Base data and translated text can satisfy their separate attribution obligations.
- The importer can be implemented against pinned fixtures without giving raw upstream fields domain authority.

## Alternatives considered

### Match dictionaries by display name

Rejected because translated or edited labels could silently change mappings.

### Infer missing fields from exercise names or descriptions

Rejected because prose parsing would introduce unreviewed, unstable behavior.

### Collapse base and translation attribution

Rejected because the two source objects have independent identifiers, authorship fields, and licenses.
