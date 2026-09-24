# Local gym equipment profiles

Authorized September 24, 2026. This slice adds an offline location inventory under
Training setup → My gym, using the existing SQLite dependency.

Select CLUB4 Homewood or add a named location. Selection reloads that location's
saved availability checklist. Switching or clearing selection preserves every
location's observations. The checklist covers the existing equipment taxonomy;
absence of an observation means unknown, never available. Users explicitly mark
items available, unavailable, or not checked, with optional machine, attachment
and settings notes. Each explicit status stores its UTC confirmation time.

The Homewood preset includes only the name/address from the official location
page, reviewed September 24, 2026:
https://www.club4fitness.com/location/homewood-birmingham-al/
It contains **no verified machine inventory**. The general checklist is clearly
labeled as such, not presented as equipment found at Homewood. No chain-wide
weight range, inferred machine, network lookup, account or GPS permission is used.
Other locations begin empty too. This is a local inventory, not a shared database.

## Boundaries

`GymProfiles`, `GymProfile` and `GymEquipment` are immutable pure-Dart records.
`availableCategories` returns only explicitly confirmed available categories in
stable order. Presence is separate from exact setups, starting loads, catalog
approval and safety clearance. Existing training setup and workout records are
untouched. This slice does not connect inventories to the still-gated production
session generator or automatically transfer starting loads between gyms.
Exact settings and starting loads remain in the existing verification screen;
free-text inventory notes are never parsed into a prescription.

`GymProfileController` coordinates saves and validated reloads. Pending writes
lock further changes, retain retry data after failure, and expose an explicit
reload action to recover from another screen's edits. Reload discards pending
intent, not previously committed storage. Success requires exact readback.
`SqliteGymProfileRepository` stores one schema-1 aggregate in the separate
`gym_profiles.sqlite`. Transactional compare-and-save rejects stale overwrites;
identical payload retries are idempotent. Corrupt/unsupported payloads fail closed.
No historical workout or existing database migration is performed.

Bounds: 50 unique location IDs, 120-character names, 240-character addresses,
one observation per supported equipment category, 500-character notes. Text is
trimmed and rejects control/bidi characters and markup delimiters. All SQL values
use parameterized APIs. Only the existing local-owner context is supported.

## Validation

Unit/widget coverage includes unknown/available/unavailable distinctions,
location switching, reload, correction, invalid and boundary inputs, cancelled
forms, read/write failure, uncertain acknowledgement retry, conflict recovery,
and large text in light/dark appearance. A native integration test uses an
isolated database to verify SQLite reopen, idempotence, conflict rollback and
corruption rejection. Physical-device test status belongs in the completion
report; test presence alone does not establish device acceptance.

Future curated profiles require branch-specific evidence before prepopulation.
Live gym search, shared inventories, photo recognition, and machine-specific
progression integration are outside this bounded slice.
