import copy
import gzip
import json
import pathlib
import unittest
from import_wger_reference import project

ROOT = pathlib.Path(__file__).resolve().parents[1]


class WgerReferenceImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(gzip.decompress((ROOT / "native/ReferenceFixtures/wger/exerciseinfo_2026_09_25.json.gz").read_bytes()))

    def test_pinned_output_is_reproducible(self):
        result, rejected = project(self.source)
        expected = json.loads((ROOT / "native/AdaptiveWorkout/Resources/wger-reference.json").read_bytes())
        self.assertEqual(result, expected)
        self.assertEqual(len(rejected), 124)

    def test_missing_english_license_author_or_plain_name_is_excluded(self):
        base = copy.deepcopy(self.source["results"][0])
        english = next(t for t in base["translations"] if t["language"] == 2)
        base["translations"] = [english]
        for field, value in [("name", "<script>"), ("license", 5), ("license_author", ""), ("uuid", "bad"), ("language", 1)]:
            record = copy.deepcopy(base)
            record["translations"][0][field] = value
            result, rejected = project(dict(count=1, next=None, results=[record]))
            self.assertEqual(result["entries"], [])
            self.assertEqual(len(rejected), 1)

    def test_incomplete_source_is_rejected(self):
        with self.assertRaises(ValueError):
            project(dict(count=1, next=None, results=[]))
        with self.assertRaises(ValueError):
            project(dict(count=0, next="next-page", results=[]))


if __name__ == "__main__":
    unittest.main()
