import Foundation
import WorkoutDomain

/// Real source provenance for review. This is not a selectable exercise catalog
/// or an approved mapping from program variants to exercises.
public enum OwnerProgramSourceCandidates {
  public static let contentSha256 =
    "332b4bda6581ab253e75aaa45a4cfb2f4e83331163b07dda9e655202335eb79b"
  public static let sourceArchiveSha256 =
    "b5d2b042f8c859a9c7ce419932ee4d5c1b56d066fe5aa87c678625eb92ae0789"
  public static let sourceBaseIds: Set<Int> = [
    537, 1510, 1378, 1689, 371, 369, 366, 365, 2628, 543, 567,
    1775, 1531, 1513, 475, 477, 1117, 1972, 926, 1414, 1573, 2632, 1283, 173, 378,
  ]

  public static func load() throws -> [WgerImportResult] {
    guard
      let url = Bundle.module.url(
        forResource: "owner-program-source-candidates", withExtension: "json")
    else { throw WgerSnapshotValidationException("missing_source_resource", "root") }
    let bytes = try Data(contentsOf: url)
    guard sha256Hex(bytes) == contentSha256 else {
      throw WgerSnapshotValidationException("source_integrity_mismatch", "root")
    }
    let results = try WgerSourceMapper().mapPinnedSnapshot(String(decoding: bytes, as: UTF8.self))
    guard results.count == sourceBaseIds.count,
      Set(results.compactMap(\.sourceBaseId)) == sourceBaseIds
    else { throw WgerSnapshotValidationException("source_identity_mismatch", "exercises") }
    return results
  }
}
