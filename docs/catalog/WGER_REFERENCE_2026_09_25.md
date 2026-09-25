# Offline wger name reference — September 25, 2026

Owner request: get exercise data from wger. This bounded slice provides an offline,
searchable name/attribution reference in Settings, separate from the selectable
exercise catalog. It never supplies recommendations, instructions or program-slot
bindings. Product, science, safety, equipment and commercial licensing gates for
the selection catalog remain unchanged.

Source: `https://wger.de/api/v2/exerciseinfo/?limit=1000&language=2`, retrieved
September 25, 2026 (912 source records; complete response with no next page).
Source revision is unknown. The immutable original response is retained compressed
in `native/ReferenceFixtures/wger/exerciseinfo_2026_09_25.json.gz` for audit only;
it is not bundled into the app. Raw SHA-256:
`aafd638556d3db6379a98022885cd40e88e707de3357bab7f7f26d3840e13bb4`.

Importer v1: `tools/import_wger_reference.py`, Python standard library only.
Run it with the pinned gzip source path and
`native/AdaptiveWorkout/Resources/wger-reference.json` as output. The projected
index has 788 entries; 124 were excluded for unsupported licenses, missing
attribution, invalid identity/text or lack of exactly one English translation.
This source-name projection deliberately does not map equipment, muscles,
tracking modes, eligibility, safety, variations or instructions.

Index version: `wger-reference-2026-09-25`. Output SHA-256:
`989e2bb1eb42b4103177380d3a5415e8dbb5b29407484224a48dfdc60c02ae8c`.
The repository checks the complete byte digest, manifest, unique identities,
plain-text bounds and supported license identifiers before exposing any entries.
A failed load displays unavailable content; it never affects saved workouts.

Base and English translation retain separate source IDs/UUIDs, author attributions
and licenses. The source page and each applicable Creative Commons license are
linked in the app. Derived names remain under their applicable CC BY-SA 3.0,
CC BY-SA 4.0, CC BY 4.0 or CC0 1.0 terms, separate from application code. Changes
are disclosed: English selection, trimmed/NFC-normalized text and field omission.
The original source snapshot preserves full upstream attribution metadata.
No images, videos, rendered HTML or wger application code is bundled.

This is a source reference index, not the approved catalog contract or a claim
that the community exercise names are safe instructions. No exercise is enabled
for selection by this change. Further instructions/media or reviewed program
bindings require a separate content review.
