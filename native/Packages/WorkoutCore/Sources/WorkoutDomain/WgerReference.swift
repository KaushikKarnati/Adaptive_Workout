import Foundation

/// Presentation-only source index. Never an ExerciseCatalog or an eligible exercise.
public struct WgerReference: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let baseID: Int
  public let translationID: Int
  public let translationUUID: String
  public let name: String
  public let baseAuthor: String
  public let translationAuthor: String
  public let baseLicense: String
  public let translationLicense: String
  public var sourceURL: URL { URL(string: "https://wger.de/en/exercise/\(translationID)/view")! }
  public static func licenseURL(_ license: String) -> URL? {
    let paths = [
      "cc-by-sa-3.0": "licenses/by-sa/3.0/", "cc-by-sa-4.0": "licenses/by-sa/4.0/",
      "cc-by-4.0": "licenses/by/4.0/", "cc0-1.0": "publicdomain/zero/1.0/",
    ]
    return paths[license].flatMap { URL(string: "https://creativecommons.org/" + $0) }
  }
}
