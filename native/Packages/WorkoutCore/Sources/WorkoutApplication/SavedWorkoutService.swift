import Foundation
import WorkoutDomain

/// Immutable retry action, retained after uncertain commits.
public struct SavedWorkoutAction: Sendable {
  public let occurrence: GeneratedOccurrence
  public let historyRevision: Int
  public let actionId: String
  fileprivate init(occurrence: GeneratedOccurrence, historyRevision: Int, actionId: String) {
    self.occurrence = occurrence
    self.historyRevision = historyRevision
    self.actionId = actionId
  }
}
public struct SavedWorkout: Sendable {
  public let occurrence: GeneratedOccurrence
  public let prescription: RecommendationSnapshot
}
/// Durable lifecycle only; this service does not authorize generation or exercise execution.
public struct SavedWorkoutService: Sendable {
  public let repository: any RecommendationHistoryRepository
  public init(_ repository: any RecommendationHistoryRepository) { self.repository = repository }
  public func resume(_ profile: String) throws -> SavedWorkout? {
    let history = try repository.load(profile)
    let active = history.occurrences.filter { $0.status == .active }
    guard !active.isEmpty else { return nil }
    guard active.count == 1 else { throw SavedWorkoutError.invalidActiveHistory }
    return try saved(history, id: active[0].id)
  }
  private func saved(_ history: GeneratedHistory, id: String) throws -> SavedWorkout {
    let matches = history.occurrences.filter { $0.id == id }
    guard matches.count == 1,
      let prescription = history.recommendations.first(where: {
        $0.id == matches[0].recommendationId
      })
    else { throw SavedWorkoutError.missingOccurrence }
    return SavedWorkout(occurrence: matches[0], prescription: prescription)
  }
  public func prepareSet(
    profile: String, occurrenceId: String, set: ProgramSet, at: Date, actionId: String
  ) throws -> SavedWorkoutAction {
    let history = try repository.load(profile)
    let item = try saved(history, id: occurrenceId)
    return try SavedWorkoutAction(
      occurrence: item.occurrence.record(set, at: at, prescription: item.prescription),
      historyRevision: history.revision, actionId: actionId)
  }
  public func prepareFinish(
    profile: String, occurrenceId: String, endEarly: Bool, at: Date, actionId: String
  ) throws -> SavedWorkoutAction {
    let history = try repository.load(profile)
    let item = try saved(history, id: occurrenceId)
    return try SavedWorkoutAction(
      occurrence: item.occurrence.finish(
        at: at, status: endEarly ? .endedEarly : .completed, prescription: item.prescription),
      historyRevision: history.revision, actionId: actionId)
  }
  public func commit(_ action: SavedWorkoutAction) throws -> SavedWorkout {
    try repository.saveOccurrence(
      action.occurrence, expectedRevision: action.occurrence.revision - 1,
      expectedHistoryRevision: action.historyRevision, actionId: action.actionId)
    return try saved(repository.load(action.occurrence.profile), id: action.occurrence.id)
  }
  public func nextSession(
    profile: String, programId: String, orderedSessionIds: [String], trainingWeekdays: [Int],
    requestedDate: Date, civilDateOfEnd: (Date) -> Date
  ) throws -> SessionPlanningResult {
    let history = try repository.load(profile)
    let all = history.occurrences.sorted { $0.sequence < $1.sequence }
    if let last = all.last, last.status == .active {
      let active = try saved(history, id: last.id)
      if active.prescription.programId != programId {
        return SessionPlanningResult("other_program_active")
      }
    }
    let scoped = try all.filter {
      try saved(history, id: $0.id).prescription.programId == programId
    }
    var earliest = requestedDate
    let validation = SessionPlanningPolicy().evaluate(
      SessionPlanningInput(
        orderedSessionIds: orderedSessionIds, trainingWeekdays: trainingWeekdays, history: [],
        requestedDate: earliest))
    if validation.reasonCode == "invalid_input" { return validation }
    if let endedAt = all.last?.endedAt {
      let endDate = civilDateOfEnd(endedAt)
      let timestamp = ManualTimestamp(endDate)
      let earliestCivil = try ManualTimestamp(parsing: "0001-01-01T00:00:00.000Z")
      let latestCivil = try ManualTimestamp(parsing: "9999-01-01T00:00:00.000Z")
      guard timestamp.isValid, timestamp >= earliestCivil, timestamp < latestCivil,
        timestamp.microsecondsSince1970 % 86_400_000_000 == 0
      else { throw SavedWorkoutError.invalidCivilDate }
      if earliest <= endDate { earliest = endDate.addingTimeInterval(86400) }
    }
    let sequence = try scoped.enumerated().map { index, occurrence in
      SessionSequenceEntry(
        id: occurrence.id, sequence: index,
        sessionId: try saved(history, id: occurrence.id).prescription.sessionTemplate,
        state: occurrence.status == .active
          ? .active : occurrence.status == .completed ? .completed : .endedEarly)
    }
    return SessionPlanningPolicy().evaluate(
      SessionPlanningInput(
        orderedSessionIds: orderedSessionIds, trainingWeekdays: trainingWeekdays, history: sequence,
        requestedDate: earliest))
  }
}
public enum SavedWorkoutError: Error {
  case missingOccurrence, invalidActiveHistory, invalidCivilDate
}
