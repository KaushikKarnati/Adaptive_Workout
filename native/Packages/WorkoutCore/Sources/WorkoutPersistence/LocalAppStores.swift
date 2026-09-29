import Foundation

/// Open independent stores without making appearance availability a prerequisite for logging.
public struct LocalAppStores: Sendable {
  public struct LoadedAppearance: Sendable {
    public let repository: SqliteAppearanceRepository
    public let preference: AppAppearance
  }
  public let programLogs: SqliteProgramLogRepository
  public let appearance: Result<LoadedAppearance, Error>
  public let trainingSetup: SqliteTrainingSetupRepository
  public let recommendationHistory: SqliteRecommendationHistoryRepository
  public let gymProfiles: SqliteGymProfileRepository

  public init(directory: URL) throws {
    programLogs = try SqliteProgramLogRepository(
      path: directory.appendingPathComponent("program_logging.sqlite").path)
    appearance = Self.loadAppearance(directory: directory)
    trainingSetup = try SqliteTrainingSetupRepository(
      path: directory.appendingPathComponent("training_setup.sqlite").path)
    recommendationHistory = try SqliteRecommendationHistoryRepository(
      path: directory.appendingPathComponent("recommendations.sqlite").path)
    gymProfiles = try SqliteGymProfileRepository(
      path: directory.appendingPathComponent("gym_profiles.sqlite").path)
  }

  public static func loadAppearance(directory: URL) -> Result<LoadedAppearance, Error> {
    Result {
      let repository = try SqliteAppearanceRepository(
        path: directory.appendingPathComponent("appearance.sqlite").path)
      return LoadedAppearance(repository: repository, preference: try repository.load())
    }
  }
}
