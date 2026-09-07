# ADR 0002: Use Wger as the V1 Exercise-Catalog Seed

## Status

Accepted. The minimal internal catalog data contract is approved in ADR 0003 and `docs/EXERCISE_CATALOG.md`.

## Context

Deterministic exercise selection requires a versioned catalog with stable identifiers, structured equipment and muscle metadata, review state, and traceable content rights. Creating a broad catalog entirely from scratch would delay validation, while copying publicly available fitness content without a license would create unacceptable provenance and commercial-use risk.

Wger provides community-maintained exercise data through an open API. Its application code and exercise content have different licenses: the application is AGPL-licensed, while exercise records and media carry their own licenses. Most current exercise records use Creative Commons Attribution-ShareAlike licenses. Media also has per-asset metadata and requires separate review.

## Decision

Use a reviewed, version-pinned snapshot of wger exercise data as the upstream seed for the V1 catalog.

- Do not copy, link, or run wger application code.
- Import data into a separately identifiable offline content package; do not call the live wger service during core workout use.
- Preserve every imported record's wger UUID, source URL, author attribution, exact license and license URL, modification disclosure, review status, and snapshot version.
- Make the required attribution and license information available within the application.
- Keep wger-derived content and modifications under the applicable source-content license, subject to legal review before commercial release.
- Exclude every wger image and video from V1.
- Treat all upstream fields as untrusted input, render no imported HTML directly, and map only explicitly allowed values into the internal contract.
- Require product, scientific, safety, equipment, and licensing approval before an imported exercise becomes eligible for selection.
- Record a manifest and integrity digest so the same catalog version can be reproduced and audited.

## Consequences

- The initial catalog can draw from a broad open dataset without making workouts depend on a network service.
- The project must implement deterministic import, sanitization, validation, attribution, review, versioning, and integrity checks.
- Wger availability does not establish scientific correctness or safe programming behavior.
- ShareAlike obligations apply to the relevant derived content package and require legal review before commercial distribution.
- Exercise media remains unavailable until a separately approved source and rights process exists.
- Upstream updates are deliberate catalog migrations rather than automatic changes.

## Alternatives considered

### Entirely first-party catalog

Rejected for V1 because independently authoring a broad source catalog would delay validation, although original records may be added later with their own provenance.

### Live wger API dependency

Rejected because it would weaken offline operation and allow availability or upstream changes to affect the workout experience.

### Import wger application code

Rejected because the product needs exercise data rather than wger's application implementation and should not introduce an unnecessary AGPL software dependency.

### Import wger media with exercise data

Rejected for V1 because each asset requires separate license, attribution, content, privacy, and quality review.
