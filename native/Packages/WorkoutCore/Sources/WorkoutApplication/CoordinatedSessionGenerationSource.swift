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

  public func capture(_ requestId: String) throws -> CapturedSessionInputs {
    let currentNow = now()
    let setup = try setupRepository.load(profile)
    let history = try historyRepository.load(profile)

    let targetSessionId: String
    if let preferred = preferredSessionId {
      targetSessionId = preferred
    } else {
      let entries = history.occurrences.enumerated().map { index, occurrence in
        SessionSequenceEntry(
          id: occurrence.id,
          sequence: index,
          sessionId: history.recommendations.first(where: { $0.id == occurrence.recommendationId })?
            .sessionTemplate ?? "monday",
          state: occurrence.status == .active
            ? .active : occurrence.status == .completed ? .completed : .endedEarly
        )
      }
      let weekdays =
        (setup?.trainingDays.isEmpty == false) ? setup!.trainingDays : [1, 2, 3, 5, 6]
      let planningInput = SessionPlanningInput(
        orderedSessionIds: ownerProgram.map(\.id),
        trainingWeekdays: weekdays,
        history: entries,
        requestedDate: civilMidnightUtc(currentNow)
      )
      let planResult = SessionPlanningPolicy().evaluate(planningInput)
      targetSessionId = planResult.sessionId ?? "monday"
    }

    let requestedDate = civilMidnightUtc(currentNow)

    let functionalAssessment = FunctionalCapabilityAssessment(
      supportedIds: setup?.supportedCapabilities ?? [],
      unsupportedIds: setup?.unsupportedCapabilities ?? [])
    let limitationAssessment = LimitationAssessment(ids: setup?.limitations ?? [])
    let persistentExclusions = setup?.excludedVariations ?? []
    let digest = eligibilityConstraintSnapshotSha256(
      equipmentInventory: [],
      temporarilyUnavailableEquipmentIds: [],
      functionalCapabilityAssessment: functionalAssessment,
      limitationAssessment: limitationAssessment,
      persistentExerciseExclusionIds: persistentExclusions,
      requestExerciseExclusionIds: [])

    let eligibility = ExerciseEligibilityRequest(
      eligibilityRuleSetVersion: "1.0.0",
      schemaVersion: "1.0.0",
      catalogVersion: "2026.09.29.1",
      taxonomyVersion: "v2",
      catalogContentSha256: catalogDigest,
      constraintSnapshotSha256: digest,
      manifest: manifest,
      catalog: catalog,
      candidateExerciseIds: candidateExerciseIds,
      equipmentInventory: [],
      temporarilyUnavailableEquipmentIds: [],
      functionalCapabilityAssessment: functionalAssessment,
      limitationAssessment: limitationAssessment,
      persistentExerciseExclusionIds: persistentExclusions,
      requestExerciseExclusionIds: [],
      safetyState: .init(version: "1.0.0", kind: .clear)
    )

    let inputRevisions: [String: Int] = [
      "profile": setup?.revision ?? 0,
      "equipment": setup?.revision ?? 0,
      "baseline": setup?.revision ?? 0,
      "constraints": setup?.revision ?? 0,
      "safety": 0,
      "catalogSchema": 0,
      "taxonomy": 0,
    ]

    let token = "setup:\(setup?.revision ?? -1);history:\(history.revision)"

    let input = SessionCompositionInput(
      id: requestId,
      profile: profile,
      sessionId: targetSessionId,
      createdAt: currentNow,
      requestedDate: requestedDate,
      timezone: TimeZone.current.identifier,
      setup: setup,
      history: history,
      eligibility: eligibility,
      inputRevisions: inputRevisions,
      rehearsals: []
    )

    return CapturedSessionInputs(revisionToken: token, input: input)
  }

  public func saveIfCurrent(
    captured: CapturedSessionInputs,
    result: SessionCompositionResult,
    actionId: String
  ) throws {
    guard let snapshot = result.snapshot else { return }
    let latestSetup = try setupRepository.load(profile)
    let latestHistory = try historyRepository.load(profile)
    let latestToken = "setup:\(latestSetup?.revision ?? -1);history:\(latestHistory.revision)"
    guard latestToken == captured.revisionToken else {
      throw SetupException("stale_input")
    }
    try historyRepository.saveRecommendation(snapshot, actionId: actionId)
  }
}

public func civilMidnightUtc(_ date: Date) -> Date {
  let seconds = floor(date.timeIntervalSince1970 / 86400) * 86400
  return Date(timeIntervalSince1970: seconds)
}
