"""Build a presentation-only, pinned wger index. No instructions, media or engine mappings."""
import gzip
import hashlib
import json
import pathlib
import sys
import unicodedata
import uuid

LICENSES = {1: "cc-by-sa-3.0", 2: "cc-by-sa-4.0", 3: "cc0-1.0", 4: "cc-by-4.0"}


def plain(value, maximum=240):
    if not isinstance(value, str):
        raise ValueError("missing text")
    value = unicodedata.normalize("NFC", value).strip()
    if not value or len(value) > maximum or any(unicodedata.category(c).startswith("C") for c in value):
        raise ValueError("invalid text")
    if any(c in value for c in "<>[]{}"):
        raise ValueError("markup")
    return value


def positive(value):
    if type(value) is not int or value <= 0:
        raise ValueError("invalid identity")
    return value


def project(source):
    if source.get("next") is not None or source["count"] != len(source["results"]):
        raise ValueError("incomplete source")
    entries, rejected, identities = [], [], set()
    for base in source["results"]:
        try:
            translations = [t for t in base["translations"] if t["language"] == 2]
            if len(translations) != 1:
                raise ValueError("English translation cardinality")
            trans = translations[0]
            base_license = LICENSES[base["license"]["id"]]
            translation_license = LICENSES[trans["license"]]
            base_id, translation_id = positive(base["id"]), positive(trans["id"])
            base_uuid, translation_uuid = str(uuid.UUID(base["uuid"])), str(uuid.UUID(trans["uuid"]))
            if base_uuid in identities:
                raise ValueError("duplicate UUID")
            entry = dict(id=base_uuid, baseID=base_id, translationID=translation_id,
                translationUUID=translation_uuid, name=plain(trans["name"]),
                baseAuthor=plain(base["license_author"]) if base_license != "cc0-1.0" else base.get("license_author", ""),
                translationAuthor=plain(trans["license_author"]) if translation_license != "cc0-1.0" else trans.get("license_author", ""),
                baseLicense=base_license, translationLicense=translation_license)
            identities.add(base_uuid)
            entries.append(entry)
        except (KeyError, ValueError, TypeError) as error:
            rejected.append({"baseID": base.get("id"), "reason": str(error)})
    entries.sort(key=lambda e: e["id"])
    return dict(version="wger-reference-2026-09-25", entries=entries), rejected


if __name__ == "__main__":
    source_path, output_path = map(pathlib.Path, sys.argv[1:3])
    source_bytes = gzip.decompress(source_path.read_bytes())
    projected, rejected = project(json.loads(source_bytes))
    output = (json.dumps(projected, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()
    output_path.write_bytes(output)
    print(json.dumps(dict(count=len(projected["entries"]), rejected=len(rejected),
        sourceSha256=hashlib.sha256(source_bytes).hexdigest(), contentSha256=hashlib.sha256(output).hexdigest()), indent=2))
