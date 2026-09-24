import Foundation

public enum ProgressionGate: String, Codable, Sendable { case permitted, blocked, safetyStop }
public enum ProgressionLoadKind: String, Codable, Sendable { case external, bodyweight, assistance }
public enum SetSide: String, Codable, Sendable { case bilateral, left, right }
public enum ProgressionAction: String, Codable, Sendable { case blocked, hold, increase, decrease }

public struct ProgressionContext: Hashable, Codable, Sendable {
  public let profileId: String
  public let slotId: String
  public let exerciseId: String
  public let setupId: String
  public let loadConventionId: String
  public let setCount: Int
  public let minReps: Int
  public let maxReps: Int
  public let unilateral: Bool
  public let loadKind: ProgressionLoadKind
  public init(
    profileId: String, slotId: String, exerciseId: String, setupId: String,
    loadConventionId: String, setCount: Int, minReps: Int, maxReps: Int, unilateral: Bool,
    loadKind: ProgressionLoadKind
  ) {
    self.profileId = profileId
    self.slotId = slotId
    self.exerciseId = exerciseId
    self.setupId = setupId
    self.loadConventionId = loadConventionId
    self.setCount = setCount
    self.minReps = minReps
    self.maxReps = maxReps
    self.unilateral = unilateral
    self.loadKind = loadKind
  }
  var isValid: Bool {
    [profileId, slotId, exerciseId, setupId, loadConventionId].allSatisfy {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    } && setCount > 0 && minReps > 0 && maxReps >= minReps
  }
}
public struct VerifiedLoadBaseline: Equatable, Codable, Sendable {
  public let context: ProgressionContext
  public let microPounds: Int
  public init(context: ProgressionContext, microPounds: Int) {
    self.context = context
    self.microPounds = microPounds
  }
}
public struct ProgressionSet: Equatable, Codable, Sendable {
  public let index: Int
  public let side: SetSide
  public let microPounds: Int?
  public let reps: Int?
  public let rir: Int?
  public let valid: Bool?
  public let working: Bool
  public init(
    index: Int, side: SetSide, microPounds: Int?, reps: Int?, rir: Int?, valid: Bool?,
    working: Bool = true
  ) {
    self.index = index
    self.side = side
    self.microPounds = microPounds
    self.reps = reps
    self.rir = rir
    self.valid = valid
    self.working = working
  }
}
public struct ProgressionExposure: Equatable, Codable, Sendable {
  public let id: String
  public let sequence: Int
  /// Absolute instant; text adapters must require UTC before constructing a Date.
  public let occurredAt: Date
  public let context: ProgressionContext
  public let completed: Bool
  public let correctedOut: Bool
  public let sets: [ProgressionSet]
  public init(
    id: String, sequence: Int, occurredAt: Date, context: ProgressionContext, completed: Bool,
    correctedOut: Bool, sets: [ProgressionSet]
  ) {
    self.id = id
    self.sequence = sequence
    self.occurredAt = occurredAt
    self.context = context
    self.completed = completed
    self.correctedOut = correctedOut
    self.sets = sets
  }
}
public struct LoadProgressionInput: Sendable {
  public let context: ProgressionContext
  public let gate: ProgressionGate?
  public let baseline: VerifiedLoadBaseline?
  public let availableLoadsMicroPounds: [Int]?
  public let history: [ProgressionExposure]?
  public init(
    context: ProgressionContext, gate: ProgressionGate?, baseline: VerifiedLoadBaseline?,
    availableLoadsMicroPounds: [Int]?, history: [ProgressionExposure]?
  ) {
    self.context = context
    self.gate = gate
    self.baseline = baseline
    self.availableLoadsMicroPounds = availableLoadsMicroPounds
    self.history = history
  }
}
public struct LoadProgressionResult: Equatable, Sendable {
  public let ruleSetVersion = "owner-program-v1"
  public let action: ProgressionAction
  public let reasonCode: String
  public let candidateMicroPounds: Int?
  public let evidenceIds: [String]
}

/// Compare products exactly at full integer precision, without overflowing Int.
func engineProductLE(_ a: Int, _ b: Int, _ c: Int, _ d: Int) -> Bool {
  guard a >= 0, b >= 0, c >= 0, d >= 0 else { return false }
  let left = UInt64(a).multipliedFullWidth(by: UInt64(b))
  let right = UInt64(c).multipliedFullWidth(by: UInt64(d))
  return left.high < right.high || (left.high == right.high && left.low <= right.low)
}

/// Candidate-load policy only. Current safety and eligibility must be supplied explicitly.
public struct LoadProgressionPolicy: Sendable {
  public init() {}
  public func evaluate(_ input: LoadProgressionInput) -> LoadProgressionResult {
    func blocked(_ reason: String) -> LoadProgressionResult {
      .init(action: .blocked, reasonCode: reason, candidateMicroPounds: nil, evidenceIds: [])
    }
    if input.gate == .safetyStop { return blocked("safety_stop") }
    guard input.gate == .permitted else { return blocked("current_checks_required") }
    let context = input.context
    guard context.isValid else { return blocked("invalid_input") }
    guard let baseline = input.baseline, baseline.context == context else {
      return blocked("baseline_required")
    }
    let current = baseline.microPounds
    guard current >= 0, context.loadKind != .external || current > 0 else {
      return blocked("invalid_baseline")
    }
    guard let loads = input.availableLoadsMicroPounds, !loads.isEmpty else {
      return blocked("verified_loads_required")
    }
    guard loads.allSatisfy({ $0 >= 0 }), context.loadKind != .external || !loads.contains(0) else {
      return blocked("invalid_available_loads")
    }
    guard loads.contains(current) else { return blocked("baseline_load_unavailable") }
    var evidenceIds: [String] = []
    func hold(_ reason: String) -> LoadProgressionResult {
      .init(
        action: .hold, reasonCode: reason, candidateMicroPounds: current, evidenceIds: evidenceIds)
    }
    guard context.loadKind == .external else { return hold("bodyweight_or_assistance_hold") }
    guard let history = input.history else { return hold("insufficient_evidence") }
    let scoped = history.filter {
      $0.context.profileId == context.profileId && $0.context.slotId == context.slotId
    }.sorted { $0.sequence < $1.sequence }
    var ids: Set<String> = []
    var sequences: Set<Int> = []
    for entry in scoped {
      guard !entry.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, entry.sequence >= 0,
        entry.occurredAt.timeIntervalSince1970.isFinite, ids.insert(entry.id).inserted,
        sequences.insert(entry.sequence).inserted
      else { return blocked("invalid_history") }
    }
    for (previous, current) in zip(scoped, scoped.dropFirst())
    where current.occurredAt < previous.occurredAt { return blocked("invalid_history") }
    let latest = scoped.suffix(2)
    evidenceIds = latest.map(\.id)
    var setsByExposure: [[ProgressionSet]] = []
    for entry in latest {
      guard entry.context == context, entry.completed, !entry.correctedOut else {
        return hold("insufficient_evidence")
      }
      let working = entry.sets.filter(\.working)
      let sides: Set<SetSide> = context.unilateral ? [.left, .right] : [.bilateral]
      // Division avoids overflow for hostile setCount values.
      guard working.count / sides.count == context.setCount, working.count % sides.count == 0 else {
        return hold("insufficient_evidence")
      }
      var seen: Set<String> = []
      for set in working {
        guard set.valid == true, set.microPounds == current, let reps = set.reps, reps >= 0,
          let rir = set.rir, rir >= 0, set.index >= 1, set.index <= context.setCount,
          sides.contains(set.side), seen.insert("\(set.index):\(set.side.rawValue)").inserted
        else { return hold("insufficient_evidence") }
      }
      setsByExposure.append(working)
    }
    guard setsByExposure.count == 2 else { return hold("insufficient_progression_streak") }
    let orderedLoads = Set(loads).sorted()
    if setsByExposure.allSatisfy({ $0.allSatisfy { $0.reps! >= context.maxReps && $0.rir! >= 2 } })
    {
      guard let next = orderedLoads.first(where: { $0 > current }) else {
        return hold("no_higher_load")
      }
      guard engineProductLE(next - current, 100, current, 5) else {
        return hold("increment_above_five_percent")
      }
      return .init(
        action: .increase, reasonCode: "progress_two_qualifying_exposures",
        candidateMicroPounds: next, evidenceIds: evidenceIds)
    }
    if setsByExposure.allSatisfy({ $0.contains { $0.reps! < context.minReps || $0.rir! < 2 } }) {
      guard let lower = orderedLoads.last(where: { $0 < current }),
        engineProductLE(current - lower, 100, current, 10)
      else {
        return .init(
          action: .blocked, reasonCode: "baseline_review_required", candidateMicroPounds: nil,
          evidenceIds: evidenceIds)
      }
      return .init(
        action: .decrease, reasonCode: "reduce_two_underperforming_exposures",
        candidateMicroPounds: lower, evidenceIds: evidenceIds)
    }
    return hold(
      setsByExposure.contains { $0.contains { $0.reps! < context.maxReps } }
        ? "rep_ceiling_not_met" : "effort_target_not_met")
  }
}
