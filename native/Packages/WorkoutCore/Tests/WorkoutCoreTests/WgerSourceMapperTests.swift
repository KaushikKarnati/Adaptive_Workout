import WorkoutDomain
import WorkoutPersistence
import XCTest

final class WgerSourceMapperTests: XCTestCase {
  let mapper = WgerSourceMapper()
  func snapshot() throws -> [String: Any] {
    try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(WgerGoldenFixtures.pinned.utf8)) as? [String: Any])
  }
  func encoded(_ value: [String: Any]) throws -> String {
    String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
  func modifyRecord(_ change: (inout [String: Any]) -> Void) throws -> WgerImportResult {
    var root = try snapshot()
    var exercises = root["exercises"] as! [[String: Any]]
    change(&exercises[0])
    root["exercises"] = exercises
    return try mapper.mapPinnedSnapshot(encoded(root)).first { $0.sourceBaseId == 101 }
      ?? mapper.mapPinnedSnapshot(encoded(root))[0]
  }
  func modifyTranslation(_ change: (inout [String: Any]) -> Void) throws -> WgerImportResult {
    try modifyRecord { record in
      var translations = record["translations"] as! [[String: Any]]
      change(&translations[0])
      record["translations"] = translations
    }
  }
  func testPinnedMappingMatchesLegacyFieldsReasonsAndDisabledBoundary() throws {
    let values = try mapper.mapPinnedSnapshot(WgerGoldenFixtures.pinned)
    XCTAssertEqual(values, try mapper.mapPinnedSnapshot(WgerGoldenFixtures.pinned))
    let first = values[0]
    let candidate = try XCTUnwrap(first.candidate)
    XCTAssertEqual(first.outcome, .acceptedDisabled)
    XCTAssertEqual(
      first.reasonCodes,
      [
        "bench_requirement_confirmation_required", "manual_classification_required",
        "manual_reviews_required",
      ])
    XCTAssertEqual(candidate.id, "wger_123e4567e89b42d3a456426614174000")
    XCTAssertEqual(candidate.wgerBaseId, 101)
    XCTAssertEqual(candidate.wgerTranslationId, 201)
    XCTAssertEqual(candidate.name, "Fixture bench press")
    XCTAssertEqual(candidate.aliases, ["Fixture press"])
    XCTAssertEqual(candidate.instructions, "Lower the bar under control.")
    XCTAssertEqual(candidate.primaryMuscleIds, ["chest"])
    XCTAssertEqual(candidate.secondaryMuscleIds, ["triceps"])
    XCTAssertEqual(
      candidate.equipmentCandidates.map(\.equipmentId), ["flat_bench", "standard_barbell"])
    XCTAssertEqual(candidate.sourceCategoryId, 11)
    XCTAssertEqual(candidate.baseAttribution.licenseId, "cc-by-sa-4.0")
    XCTAssertEqual(candidate.translationAttribution.licenseId, "cc-by-sa-4.0")
    XCTAssertEqual(values[1].sourceBaseId, 102)
    XCTAssertEqual(values[1].outcome, .rejected)
    XCTAssertEqual(values[1].reasonCodes, ["unsupported_muscle_3"])
    XCTAssertNil(values[1].candidate)
  }
  func testRealPinnedBenchmarkIdentityAndAttributionStayDisabled() throws {
    let values = try mapper.mapPinnedSnapshot(WgerGoldenFixtures.benchmark)
    XCTAssertEqual(values.map(\.sourceBaseId), [73, 184, 615])
    XCTAssertTrue(values.allSatisfy { $0.outcome == .acceptedDisabled })
    for entry in BenchmarkCatalogSlice.entries {
      let source = try XCTUnwrap(values.first { $0.sourceBaseId == entry.wgerBaseId }?.candidate)
      XCTAssertEqual(source.id, entry.id)
      XCTAssertEqual(source.wgerBaseUuid, entry.wgerBaseUuid)
      XCTAssertEqual(source.wgerTranslationId, entry.wgerTranslationId)
      XCTAssertEqual(source.wgerTranslationUuid, entry.wgerTranslationUuid)
      XCTAssertEqual(source.sourceModifiedAt, entry.sourceModifiedAt)
      XCTAssertEqual(source.baseAttribution.licenseId, entry.baseAttribution.licenseId)
      XCTAssertEqual(source.baseAttribution.licenseAuthor, entry.baseAttribution.licenseAuthor)
      XCTAssertEqual(
        source.translationAttribution.licenseId, entry.translationAttribution.licenseId)
      XCTAssertEqual(
        source.translationAttribution.licenseAuthor, entry.translationAttribution.licenseAuthor)
    }
  }
  func testSnapshotMalformedDictionaryAndLanguageFailures() throws {
    for (payload, code) in [
      ("{", "invalid_json"), ("[]", "invalid_snapshot_root"), ("null", "invalid_snapshot_root"),
    ] {
      XCTAssertThrowsError(try mapper.mapPinnedSnapshot(payload)) {
        XCTAssertEqual(($0 as? WgerSnapshotValidationException)?.code, code)
      }
    }
    var root = try snapshot()
    var muscles = root["muscles"] as! [[String: Any]]
    muscles[0]["name"] = "Changed upstream name"
    root["muscles"] = muscles
    XCTAssertThrowsError(try mapper.mapPinnedSnapshot(encoded(root))) {
      XCTAssertEqual(
        $0 as? WgerSnapshotValidationException,
        WgerSnapshotValidationException("dictionary_mismatch", "muscles"))
    }
    root = try snapshot()
    var languages = root["languages"] as! [[String: Any]]
    languages.append(["id": 99, "short_name": "en"])
    root["languages"] = languages
    XCTAssertThrowsError(try mapper.mapPinnedSnapshot(encoded(root))) {
      XCTAssertEqual(
        $0 as? WgerSnapshotValidationException,
        WgerSnapshotValidationException("duplicate_dictionary_name", "languages"))
    }
    root = try snapshot()
    var equipment = root["equipment"] as! [[String: Any]]
    equipment.append(equipment[0])
    root["equipment"] = equipment
    XCTAssertThrowsError(try mapper.mapPinnedSnapshot(encoded(root))) {
      XCTAssertEqual(
        $0 as? WgerSnapshotValidationException,
        WgerSnapshotValidationException("duplicate_dictionary_id", "equipment"))
    }
  }
  func testTranslationAndIndependentLicensingGates() throws {
    XCTAssertEqual(
      try modifyRecord { $0["translations"] = [] }.reasonCodes, ["english_translation_cardinality"])
    XCTAssertEqual(
      try modifyTranslation { $0["language"] = ["id": 2, "short_name": "fr"] }.reasonCodes,
      ["language_name_mismatch"])
    XCTAssertEqual(
      try modifyRecord { $0["license"] = ["id": 5, "name": "ODbL"] }.reasonCodes,
      ["unsupported_license_5"])
    XCTAssertEqual(
      try modifyTranslation { $0["license"] = ["id": 5, "name": "ODbL"] }.reasonCodes,
      ["unsupported_license_5"])
    let missingAuthor = try modifyTranslation { $0["license_author"] = NSNull() }
    XCTAssertEqual(missingAuthor.outcome, .acceptedDisabled)
    XCTAssertTrue(missingAuthor.reasonCodes.contains("license_author_review_required"))
    XCTAssertEqual(
      try modifyRecord { $0["equipment"] = [1, 1] }.reasonCodes, ["duplicate_equipment"])
    XCTAssertEqual(
      try modifyTranslation { $0["aliases"] = [["alias": "repeat"], ["alias": "repeat"]] }
        .reasonCodes, ["duplicate_alias"])
    XCTAssertEqual(try modifyRecord { $0["id"] = true }.reasonCodes, ["invalid_id"])
    XCTAssertEqual(
      try modifyRecord { $0["category"] = ["id": 11, "name": "Back"] }.reasonCodes,
      ["category_name_mismatch"])
  }
  func testInstructionsAndEquipmentNeverInferApprovalOrBodyweight() throws {
    for raw in ["<p>Unsafe</p>", "https://example.test", " padded", "\u{202e}", 4] as [Any] {
      let result = try modifyTranslation { $0["description_source"] = raw }
      XCTAssertNil(result.candidate?.instructions)
      XCTAssertTrue(result.reasonCodes.contains("instructions_manual_review_required"))
    }
    let empty = try modifyRecord { $0["equipment"] = [] }
    XCTAssertEqual(empty.outcome, .acceptedDisabled)
    XCTAssertEqual(empty.candidate?.equipmentCandidates.count, 0)
    XCTAssertTrue(empty.reasonCodes.contains("equipment_review_empty_source"))
    let cable = try modifyRecord { $0["equipment"] = [12, 9] }
    XCTAssertTrue(cable.reasonCodes.contains("cable_capabilities_review_required"))
    XCTAssertEqual(cable.candidate?.equipmentCandidates[0].capabilityIds, ["adjustable_angle"])
    let unicode = try modifyTranslation { $0["aliases"] = [["alias": "é"], ["alias": "e\u{301}"]] }
    XCTAssertEqual(unicode.outcome, .acceptedDisabled)
    XCTAssertEqual(unicode.candidate?.aliases.count, 2)
  }
  func testValidTimestampOffsetsLeapDaysAndFractionTruncation() throws {
    let cases = [
      "2026-06-19T18:46:21.803261+02:00": "2026-06-19T16:46:21.000Z",
      "2000-02-29T00:00:00Z": "2000-02-29T00:00:00.000Z",
      "2026-01-01T00:00:00+23:59": "2025-12-31T00:01:00.000Z",
      "2024-02-29T23:59:59.999999Z": "2024-02-29T23:59:59.000Z",
      "2026-01-01T00:15:00+01:00": "2025-12-31T23:15:00.000Z",
      "2026-12-31T23:45:00-01:00": "2027-01-01T00:45:00.000Z",
      "2026-06-19T18:46:21+05:30": "2026-06-19T13:16:21.000Z",
    ]
    for (input, expected) in cases {
      let result = try modifyRecord { $0["last_update_global"] = input }
      XCTAssertEqual(result.outcome, .acceptedDisabled, input)
      XCTAssertEqual(result.candidate?.sourceModifiedAt, try dartDate(expected), input)
    }
  }
  func testMalformedTimestampNeverNormalizesAndMissingStaysUnknown() throws {
    let invalid: [Any] = [
      "", 123, "1900-02-29T12:00:00Z", "2026-02-29T12:00:00Z", "2026-04-31T12:00:00Z",
      "2026-00-01T12:00:00Z", "2026-13-01T12:00:00Z", "2026-01-00T12:00:00Z",
      "2026-01-01T24:00:00Z", "2026-01-01T12:60:00Z", "2026-01-01T12:00:60Z",
      "2026-01-01T12:00:00+24:00", "2026-01-01T12:00:00+01:60", "2026-01-01T12:00:00", "2026-01-01",
      "2026-01-01T12:00:00Z trailing", "2026-01-01T12:00:00Z\n",
    ]
    for input in invalid {
      let result = try modifyRecord { $0["last_update_global"] = input }
      XCTAssertEqual(result.reasonCodes, ["invalid_last_update_global"], String(describing: input))
      XCTAssertNil(result.candidate)
    }
    for explicitNull in [false, true] {
      let result = try modifyRecord {
        if explicitNull {
          $0["last_update_global"] = NSNull()
        } else {
          $0.removeValue(forKey: "last_update_global")
        }
      }
      XCTAssertEqual(result.outcome, .acceptedDisabled)
      XCTAssertNil(result.candidate?.sourceModifiedAt)
    }
  }
}
