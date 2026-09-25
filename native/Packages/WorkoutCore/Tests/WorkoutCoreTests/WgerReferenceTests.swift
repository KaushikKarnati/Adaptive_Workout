import CryptoKit
import Foundation
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class WgerReferenceTests: XCTestCase {
  private var source: URL {
    if let bundled = Bundle.main.url(forResource: "wger-reference", withExtension: "json") {
      return bundled
    }
    return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("AdaptiveWorkout/Resources/wger-reference.json")
  }
  func testPinnedOfflineIndexHasAttributionAndNoInstructionOrMediaFields() throws {
    let entries = try WgerReferenceRepository.load(source)
    XCTAssertEqual(entries.count, 788)
    XCTAssertTrue(entries.allSatisfy { $0.sourceURL.host == "wger.de" })
    XCTAssertTrue(entries.allSatisfy { WgerReference.licenseURL($0.baseLicense) != nil })
    XCTAssertTrue(entries.contains { $0.name.lowercased().contains("dumbbell") })
    let text = try String(contentsOf: source, encoding: .utf8)
    for forbidden in ["description", "images", "videos", "instructions"] {
      XCTAssertFalse(text.contains("\"\(forbidden)\":"))
    }
  }
  func testCorruptionMissingDataUnsupportedLicensesAndMarkupAreRejected() throws {
    let data = try Data(contentsOf: source)
    XCTAssertThrowsError(
      try WgerReferenceRepository.decode(
        data + Data([0]), expectedDigest: WgerReferenceRepository.digest))
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
    func reject(_ object: [String: Any]) throws {
      let bytes = try JSONSerialization.data(withJSONObject: object)
      let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
      XCTAssertThrowsError(try WgerReferenceRepository.decode(bytes, expectedDigest: digest))
    }
    try reject(["version": "future", "entries": entries])
    try reject(["version": "wger-reference-2026-09-25", "entries": []])
    try reject(["version": "wger-reference-2026-09-25", "entries": [entries[0], entries[0]]])
    for (key, value) in [
      ("name", "<script>"), ("baseLicense", "unknown"), ("translationAuthor", ""), ("id", "bad"),
    ] {
      var entry = entries[0]
      entry[key] = value
      // Make attribution mandatory regardless of the first entry's source license.
      if key == "translationAuthor" { entry["translationLicense"] = "cc-by-sa-4.0" }
      try reject(["version": "wger-reference-2026-09-25", "entries": [entry]])
    }
  }
}
