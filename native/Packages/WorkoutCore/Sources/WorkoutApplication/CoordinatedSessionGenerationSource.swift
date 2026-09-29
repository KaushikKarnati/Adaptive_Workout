import Foundation
import WorkoutDomain

public struct CoordinatedSessionGenerationSource: SessionGenerationSource, Sendable {
  public let profile: String
  public let setupRepository: any TrainingSetupRepository
  public let historyRepository: any RecommendationHistoryRepository
  public let catalog: [ExerciseCatalogEntry]
  public let catalogDigest: String
  public let candidateExerciseIds: [String]
  public let manifest: ExerciseCatalogManifest?
  public let preferredSessionId: String?
  public let now: @Sendable () -> Date

  public init(
    profile: String,
    setupRepository: any TrainingSetupRepository,
    historyRepository: any RecommendationHistoryRepository,
    catalog: [ExerciseCatalogEntry],
    catalogDigest: String,
    candidateExerciseIds: [String],
    manifest: ExerciseCatalogManifest? = nil,
    preferredSessionId: String? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.profile = profile
    self.setupRepository = setupRepository
    self.historyRepository = historyRepository
    self.catalog = catalog
    self.catalogDigest = catalogDigest
    self.candidateExerciseIds = candidateExerciseIds
    self.manifest = manifest
    self.preferredSessionId = preferredSessionId
    self.now = now
  }

  // Separate repository reads cannot establish the consistency boundary required
  // by ADR 0014. Fail before reading or writing until an atomic adapter and
  // authoritative safety/catalog inputs are implemented.
  public func capture(_ requestId: String) throws -> CapturedSessionInputs {
    throw SetupException("atomic_generation_source_unavailable")
  }

  public func saveIfCurrent(
    captured: CapturedSessionInputs,
    result: SessionCompositionResult,
    actionId: String
  ) throws {
    throw SetupException("atomic_generation_source_unavailable")
  }
}
