import Foundation

/// Composition-only fixture routing. Production builds reject developer launch flags.
public struct StorageLaunchContext: Sendable {
  public let directory: URL
  public let preferencesDomain: String?
  public let resetFixture: Bool
  public init(
    documents: URL, arguments: [String], hostedTest: Bool, allowsTesting: Bool,
    hostedIdentity: String
  ) throws {
    let fixtureIndex = arguments.firstIndex(of: "--fixture-directory")
    let reset = arguments.contains("--reset-fixture")
    let hasDeveloperFlags =
      fixtureIndex != nil || reset || arguments.contains("--practice") || hostedTest
    guard allowsTesting || !hasDeveloperFlags else { throw StorageLaunchError.testingUnavailable }
    let name: String?
    if let fixtureIndex {
      guard arguments.count > fixtureIndex + 1 else { throw StorageLaunchError.invalidFixture }
      name = arguments[fixtureIndex + 1]
    } else if hostedTest {
      name = "hosted_" + hostedIdentity
    } else {
      name = nil
    }
    guard !reset || name != nil else { throw StorageLaunchError.invalidFixture }
    if let name {
      guard (1...128).contains(name.utf8.count),
        name.utf8.allSatisfy({
          (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95
            || $0 == 45
        })
      else { throw StorageLaunchError.invalidFixture }
      directory = documents.appendingPathComponent("UITestFixtures", isDirectory: true)
        .appendingPathComponent(name, isDirectory: true)
      preferencesDomain = "com.adaptiveworkout.native.fixtures." + name
      resetFixture = reset
    } else {
      directory = documents
      preferencesDomain = nil
      resetFixture = false
    }
  }
}
public enum StorageLaunchError: Error { case invalidFixture, testingUnavailable }
