import Foundation

public enum PlannedSessionState: String, Codable, Sendable { case active, completed, endedEarly }
public struct SessionSequenceEntry: Equatable, Sendable {
  public let id: String
  public let sequence: Int
  public let sessionId: String
  public let state: PlannedSessionState
  public init(id: String, sequence: Int, sessionId: String, state: PlannedSessionState) {
    self.id = id
    self.sequence = sequence
    self.sessionId = sessionId
    self.state = state
  }
}
public struct SessionPlanningInput: Sendable {
  public let orderedSessionIds: [String]?
  public let trainingWeekdays: [Int]?
  public let history: [SessionSequenceEntry]?
  /// Civil date encoded at UTC midnight, never a local instant converted to UTC.
  public let requestedDate: Date?
  public init(
    orderedSessionIds: [String]?, trainingWeekdays: [Int]?, history: [SessionSequenceEntry]?,
    requestedDate: Date?
  ) {
    self.orderedSessionIds = orderedSessionIds
    self.trainingWeekdays = trainingWeekdays
    self.history = history
    self.requestedDate = requestedDate
  }
}
public struct SessionPlanningResult: Equatable, Sendable {
  public let ruleVersion = "session-planning-v1"
  public let reasonCode: String
  public let sessionId: String?
  public let date: Date?
  public init(_ reasonCode: String, sessionId: String? = nil, date: Date? = nil) {
    self.reasonCode = reasonCode
    self.sessionId = sessionId
    self.date = date
  }
}
/// Calendar planning only; does not authorize exercises or training loads.
public struct SessionPlanningPolicy: Sendable {
  public init() {}
  public func evaluate(_ input: SessionPlanningInput) -> SessionPlanningResult {
    guard let sessions = input.orderedSessionIds, let weekdays = input.trainingWeekdays,
      let history = input.history, let date = input.requestedDate
    else { return .init("required_input_missing") }
    guard date.timeIntervalSince1970.isFinite else { return .init("invalid_input") }
    let seconds = date.timeIntervalSince1970
    guard !sessions.isEmpty,
      sessions.allSatisfy({
        !$0.isEmpty && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }),
      Set(sessions).count == sessions.count, weekdays.allSatisfy({ (1...7).contains($0) }),
      Set(weekdays).count == weekdays.count,
      seconds >= -62_135_596_800, seconds < 253_370_764_800,
      seconds.truncatingRemainder(dividingBy: 86_400) == 0
    else { return .init("invalid_input") }
    let ordered = history.sorted { $0.sequence < $1.sequence }
    var ids: Set<String> = []
    for (index, entry) in ordered.enumerated() {
      guard !entry.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        ids.insert(entry.id).inserted,
        entry.sequence == index, entry.sessionId == sessions[index % sessions.count],
        entry.state != .active || index == ordered.count - 1
      else { return .init("invalid_history") }
    }
    if let last = ordered.last, last.state == .active {
      return .init("resume_session", sessionId: last.sessionId)
    }
    let nextId = sessions[ordered.count % sessions.count]
    guard !weekdays.isEmpty else { return .init("schedule_required", sessionId: nextId) }
    for offset in 0..<7 {
      let nextDate = date.addingTimeInterval(Double(offset * 86400))
      let days = Int(nextDate.timeIntervalSince1970 / 86_400)
      let isoWeekday = ((days + 3) % 7 + 7) % 7 + 1
      if weekdays.contains(isoWeekday) {
        return .init("next_session", sessionId: nextId, date: nextDate)
      }
    }
    return .init("invalid_input")
  }
}
public enum DurationFit: String, Sendable {
  case withinPreference, exceedsPreference, estimateRequired, invalidInput
}
public func compareSessionDuration(preferredMinutes: Int?, estimatedSeconds: Int?) -> DurationFit {
  guard let preferredMinutes, preferredMinutes > 0,
    estimatedSeconds == nil || estimatedSeconds! >= 0
  else { return .invalidInput }
  guard let estimatedSeconds else { return .estimateRequired }
  return engineProductLE(estimatedSeconds, 1, preferredMinutes, 60)
    ? .withinPreference : .exceedsPreference
}
