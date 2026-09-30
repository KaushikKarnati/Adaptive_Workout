"""Extract a pinned review slice; never grant catalog approvals or infer equipment."""
import gzip
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ARCHIVE_DIGEST = "b5d2b042f8c859a9c7ce419932ee4d5c1b56d066fe5aa87c678625eb92ae0789"
BASE_IDS = {537, 1510, 1378, 1689, 371, 369, 366, 365, 2628, 543, 567,
            1775, 1531, 1513, 475, 477, 1117, 1972, 926, 1414, 1573, 2632, 1283, 173, 378}
BASE_FIELDS = ["id", "uuid", "category", "muscles", "muscles_secondary", "equipment",
               "license", "license_author", "license_title", "last_update_global"]
TRANSLATION_FIELDS = ["id", "uuid", "language", "name", "aliases", "license",
                      "license_author", "license_title"]


def project(archive, dictionaries):
    if hashlib.sha256(archive).hexdigest() != ARCHIVE_DIGEST:
        raise ValueError("source archive integrity mismatch")
    source = json.loads(gzip.decompress(archive))
    if source.get("next") is not None or source["count"] != len(source["results"]):
        raise ValueError("incomplete source")
    result = {key: dictionaries[key] for key in
              ["categories", "muscles", "equipment", "licenses", "languages"]}
    result["exercises"] = []
    for base in source["results"]:
        if base["id"] not in BASE_IDS:
            continue
        record = {key: base[key] for key in BASE_FIELDS if key in base}
        record["translations"] = [
            {key: trans[key] for key in TRANSLATION_FIELDS if key in trans}
            for trans in base["translations"] if trans["language"] == 2]
        result["exercises"].append(record)
    if (len(result["exercises"]) != len(BASE_IDS)
            or {record["id"] for record in result["exercises"]} != BASE_IDS):
        raise ValueError("missing or duplicated source identities")
    result["exercises"].sort(key=lambda record: record["id"])
    return (json.dumps(result, ensure_ascii=False, sort_keys=True,
                       separators=(",", ":")) + "\n").encode()


if __name__ == "__main__":
    archive = (ROOT / "native/ReferenceFixtures/wger/exerciseinfo_2026_09_25.json.gz").read_bytes()
    dictionaries = json.loads((ROOT / "native/ReferenceFixtures/wger/benchmark_snapshot_2026_09_08.json").read_bytes())
    payload = project(archive, dictionaries)
    target = ROOT / "native/Packages/WorkoutCore/Sources/WorkoutPersistence/Resources/owner-program-source-candidates.json"
    if "--check" in sys.argv:
        if target.read_bytes() != payload:
            raise SystemExit("candidate resource differs from pinned source")
    else:
        target.write_bytes(payload)
    print(hashlib.sha256(payload).hexdigest())
