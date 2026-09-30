import Foundation
import WorkoutPersistence
import XCTest

final class OwnerProgramSourceTests: XCTestCase {
  func testPinnedRealSourcesRemainReviewCandidates() throws {
    let results = try OwnerProgramSourceCandidates.load()
    XCTAssertEqual(results.count, 25)
    XCTAssertEqual(results, try OwnerProgramSourceCandidates.load())
    XCTAssertFalse(results.contains { $0.outcome == .acceptedEnabled })
    XCTAssertEqual(results.filter { $0.outcome == .acceptedDisabled }.count, 22)
    XCTAssertEqual(
      Set(results.filter { $0.outcome == .rejected }.compactMap(\.sourceBaseId)), [378, 1573, 1972])
    XCTAssertEqual(
      results.first { $0.sourceBaseId == 1573 }?.reasonCodes, ["unsupported_muscle_3"])
    XCTAssertEqual(
      results.first { $0.sourceBaseId == 1972 }?.reasonCodes, ["unsupported_muscle_13"])
    for result in results where result.candidate != nil {
      XCTAssertEqual(result.outcome, .acceptedDisabled)
      XCTAssertTrue(result.reasonCodes.contains("manual_classification_required"))
      XCTAssertTrue(result.reasonCodes.contains("manual_reviews_required"))
    }
    let legPress = try XCTUnwrap(results.first { $0.sourceBaseId == 371 }?.candidate)
    XCTAssertEqual(legPress.wgerBaseUuid, "66a42396-c207-44da-bc75-758a89d32404")
    XCTAssertEqual(legPress.wgerTranslationId, 788)
    XCTAssertEqual(legPress.name, "Leg Press")
    XCTAssertTrue(legPress.equipmentCandidates.isEmpty)
    XCTAssertTrue(
      try XCTUnwrap(results.first { $0.sourceBaseId == 371 }).reasonCodes.contains(
        "equipment_review_empty_source"))
    XCTAssertEqual(legPress.baseAttribution.licenseId, "cc0-1.0")
    XCTAssertEqual(legPress.translationAttribution.licenseAuthor, "BFad07")
    XCTAssertNil(legPress.instructions)
  }

  func testSourceEquipmentPreservedWithoutInferringMachineRequirements() throws {
    let results = try OwnerProgramSourceCandidates.load()
    let inclinePress = try XCTUnwrap(results.first { $0.sourceBaseId == 537 }?.candidate)
    XCTAssertEqual(
      Set(inclinePress.equipmentCandidates.map(\.equipmentId)), ["dumbbells", "adjustable_bench"])
    let machinePress = try XCTUnwrap(results.first { $0.sourceBaseId == 543 }?.candidate)
    XCTAssertEqual(machinePress.name, "Shoulder Press, on Machine")
    XCTAssertTrue(machinePress.equipmentCandidates.isEmpty)
  }

  func testRawLicenseShortNameMismatchRejectsRecord() throws {
    var snapshot = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(WgerGoldenFixtures.pinned.utf8)) as? [String: Any])
    var records = try XCTUnwrap(snapshot["exercises"] as? [[String: Any]])
    records[0]["license"] = ["id": 2, "short_name": "CC0"]
    snapshot["exercises"] = records
    let bytes = try JSONSerialization.data(withJSONObject: snapshot, options: .sortedKeys)
    let result = try XCTUnwrap(
      WgerSourceMapper().mapPinnedSnapshot(String(decoding: bytes, as: UTF8.self)).first {
        $0.sourceBaseId == 101
      })
    XCTAssertEqual(result.outcome, .rejected)
    XCTAssertEqual(result.reasonCodes, ["license_name_mismatch"])
    XCTAssertNil(result.candidate)
  }
}
