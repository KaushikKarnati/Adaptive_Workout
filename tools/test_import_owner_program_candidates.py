import json
import unittest

from import_owner_program_candidates import ROOT, project


class OwnerCandidateImportTests(unittest.TestCase):
    def setUp(self):
        self.archive = (ROOT / "native/ReferenceFixtures/wger/exerciseinfo_2026_09_25.json.gz").read_bytes()
        self.dictionaries = json.loads((ROOT / "native/ReferenceFixtures/wger/benchmark_snapshot_2026_09_08.json").read_bytes())

    def test_pinned_projection_matches_bundled_resource(self):
        expected = (ROOT / "native/Packages/WorkoutCore/Sources/WorkoutPersistence/Resources/owner-program-source-candidates.json").read_bytes()
        self.assertEqual(project(self.archive, self.dictionaries), expected)
        records = json.loads(expected)["exercises"]
        leg_press = next(record for record in records if record["id"] == 371)
        self.assertEqual(leg_press["equipment"], [])
        self.assertNotIn("description_source", leg_press["translations"][0])
        self.assertNotIn("availability", leg_press)

    def test_changed_source_refused(self):
        with self.assertRaisesRegex(ValueError, "integrity mismatch"):
            project(self.archive + b"changed", self.dictionaries)


if __name__ == "__main__":
    unittest.main()
