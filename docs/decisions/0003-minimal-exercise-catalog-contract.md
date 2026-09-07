# ADR 0003: Minimal Internal Exercise-Catalog Contract

## Status

Accepted.

## Context

The approved wger source contains community-authored, versioned, and individually licensed data. The deterministic engine cannot safely consume raw upstream objects or infer behavior from display text. A minimal internal boundary is required before implementing import or selection.

## Decision

Adopt `docs/EXERCISE_CATALOG.md` as the V1 internal exercise-catalog contract.

The contract separates immutable snapshot provenance, stable identity, licensed presentation content, approved engine classification, non-operative relationships, license and attribution metadata, and explicit review state. Selectability is derived only when an entry is enabled and its product, science, safety, equipment, and license reviews are all approved.

Raw source models, import models, persistence models, domain entities, and presentation models remain separate. The domain never receives unvalidated wger data, HTML, media, attribution text as behavior, or live API state.

## Consequences

- Catalog ingestion and validation can be deterministic and tested before exercise selection exists.
- Upstream wording and metadata cannot silently become workout logic.
- Review and licensing gaps produce disabled, omitted, or no-recommendation states rather than guesses.
- Taxonomies, equipment identifiers, canonical serialization, and exact bounds remain bounded follow-up decisions.
- Adding a field that can influence selection requires specification review, deterministic tests, and a contract-version change.

## Alternatives considered

### Use raw wger API objects as domain entities

Rejected because upstream schema changes, untrusted fields, and source iteration order would cross the deterministic and security boundaries.

### Store one generic metadata map

Rejected because unknown free-form keys could become unreviewed behavior and cannot provide exhaustive validation.

### Include workout prescriptions in exercise records

Rejected because sets, repetitions, load, rest, and progression belong to separately approved engine rules rather than source catalog content.
