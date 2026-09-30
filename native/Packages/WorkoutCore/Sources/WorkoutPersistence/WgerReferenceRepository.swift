import CryptoKit
import Foundation
import WorkoutDomain

/// Separately licensed bundled data, checked before presentation, with no network dependency.
public enum WgerReferenceRepository {
  public static let digest = "989e2bb1eb42b4103177380d3a5415e8dbb5b29407484224a48dfdc60c02ae8c"
  public static func load(_ url: URL) throws -> [WgerReference] {
    try decode(Data(contentsOf: url), expectedDigest: digest)
  }
  public static func decode(_ data: Data, expectedDigest: String) throws -> [WgerReference] {
    guard data.count <= 2_000_000,
      SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == expectedDigest
    else { throw LoggingException("invalid_reference_integrity") }
    let document = try JSONDecoder().decode(Document.self, from: data)
    guard document.version == "wger-reference-2026-09-25", !document.entries.isEmpty,
      document.entries.count <= 2000,
      Set(document.entries.map(\.id)).count == document.entries.count,
      Set(document.entries.map(\.baseID)).count == document.entries.count,
      Set(document.entries.map(\.translationID)).count == document.entries.count
    else { throw LoggingException("invalid_reference_manifest") }
    for entry in document.entries {
      guard UUID(uuidString: entry.id) != nil, UUID(uuidString: entry.translationUUID) != nil,
        entry.baseID > 0, entry.translationID > 0,
        validText(entry.name, required: true),
        validText(entry.baseAuthor, required: entry.baseLicense != "cc0-1.0"),
        validText(entry.translationAuthor, required: entry.translationLicense != "cc0-1.0"),
        WgerReference.licenseURL(entry.baseLicense) != nil,
        WgerReference.licenseURL(entry.translationLicense) != nil
      else { throw LoggingException("invalid_reference_entry") }
    }
    return document.entries.sorted {
      $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name
    }
  }
  private static func validText(_ text: String, required: Bool) -> Bool {
    (!required || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      && text.count <= 240 && text.rangeOfCharacter(from: .controlCharacters) == nil
      && !text.contains(where: { "<>[]{}".contains($0) })
  }
  private struct Document: Decodable {
    let version: String
    let entries: [WgerReference]
  }
}
