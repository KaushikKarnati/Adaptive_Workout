import Foundation

/// Descriptive manual log views only. No estimated strength, volume or inferred bodyweight.
public func filterWorkoutHistory(
  _ logs: [ProgramLog], profile: String, query: String = "", since: Date? = nil
) -> [ProgramLog] {
  let words = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
  return logs.filter { log in
    let text =
      ([log.plan.day, log.plan.title] + log.exercises.map(\.name)
      + log.sets.map { "\($0.variant) \($0.setup)" }).joined(separator: " ").lowercased()
    return log.profile == profile && log.completed && (since == nil || log.startedAt >= since!)
      && words.allSatisfy { text.contains($0) }
  }.sorted { a, b in
    a.startedTimestamp == b.startedTimestamp
      ? a.id < b.id
      : a.startedTimestamp.microsecondsSince1970 > b.startedTimestamp.microsecondsSince1970
  }
}
public struct ExerciseSeriesKey: Hashable, Sendable {
  public static func == (lhs: ExerciseSeriesKey, rhs: ExerciseSeriesKey) -> Bool {
    lhs.version == rhs.version && lhs.program == rhs.program && lhs.slot == rhs.slot
      && lhs.variant == rhs.variant
      && ManualJSON.bytesEqual(lhs.setup, rhs.setup) && lhs.convention == rhs.convention
      && lhs.side == rhs.side && lhs.unknownSetupSession == rhs.unknownSetupSession
  }
  public func hash(into hasher: inout Hasher) {
    hasher.combine(version)
    hasher.combine(program)
    hasher.combine(slot)
    hasher.combine(variant)
    for byte in setup.utf8 { hasher.combine(byte) }
    hasher.combine(convention)
    hasher.combine(side)
    hasher.combine(unknownSetupSession)
  }
  public let version: String
  public let program: String
  public let slot: String
  public let variant: String
  public let setup: String
  public let convention: LoadConvention
  public let side: LoggedSide
  public let unknownSetupSession: String?
}
public struct HistoryPoint: Equatable, Sendable, Identifiable {
  public let log: ProgramLog
  public let set: ProgramSet
  public var id: String { log.id + "_" + set.key }
}
public struct ExerciseHistorySeries: Equatable, Sendable, Identifiable {
  public let key: ExerciseSeriesKey
  public let name: String
  public var points: [HistoryPoint]
  public var id: ExerciseSeriesKey { key }
}
public func exerciseHistory(_ logs: [ProgramLog]) -> [ExerciseHistorySeries] {
  var groups: [ExerciseSeriesKey: ExerciseHistorySeries] = [:]
  var order: [ExerciseSeriesKey] = []
  let ordered = logs.filter(\.completed).sorted { a, b in
    a.startedTimestamp == b.startedTimestamp
      ? a.id < b.id
      : a.startedTimestamp.microsecondsSince1970 < b.startedTimestamp.microsecondsSince1970
  }
  for log in ordered {
    for set in log.sets.enumerated().sorted(by: { a, b in
      a.element.index == b.element.index ? a.offset < b.offset : a.element.index < b.element.index
    }).map(\.element) {
      guard !set.warmup, !set.skipped, set.validity == .valid, let reps = set.reps, reps > 0,
        set.convention == .bodyweight || set.load != nil,
        let exercise = log.exercises.first(where: { $0.id == set.slot })
      else { continue }
      let key = ExerciseSeriesKey(
        version: log.programVersion, program: log.programId, slot: set.slot,
        variant: set.variant, setup: set.setup, convention: set.convention, side: set.side,
        unknownSetupSession: set.setup.isEmpty ? log.id : nil)
      if groups[key] == nil {
        groups[key] = ExerciseHistorySeries(key: key, name: exercise.name, points: [])
        order.append(key)
      }
      groups[key]?.points.append(HistoryPoint(log: log, set: set))
    }
  }
  return order.compactMap { groups[$0] }.enumerated().sorted { a, b in
    a.element.name == b.element.name ? a.offset < b.offset : a.element.name < b.element.name
  }.map(\.element)
}

/// The most recent earlier finished workout's valid working sets for one exercise side.
/// Descriptive only: it is the user's own record, never a target, suggestion or baseline.
public struct LastPerformance: Equatable, Sendable {
  public let log: ProgramLog
  public let sets: [ProgramSet]
  /// True when the sets were matched to a set already recorded in the current workout.
  public let matchesCurrentSetup: Bool
}
/// Uses the same comparability as `exerciseHistory`: profile, program version and session,
/// slot, side, variant, setup and load convention. An empty setup is not comparable. Before
/// today's setup is recorded, the earlier workout's first valid working set picks the setup.
public func lastPerformance(
  _ logs: [ProgramLog], current: ProgramLog, slot: String, side: LoggedSide
) -> LastPerformance? {
  func working(_ log: ProgramLog) -> [ProgramSet] {
    log.sets.filter {
      $0.slot == slot && $0.side == side && !$0.warmup && !$0.skipped && $0.validity == .valid
        && !$0.setup.isEmpty && ($0.reps ?? 0) > 0
        && ($0.convention == .bodyweight || $0.load != nil)
    }.sorted { $0.index < $1.index }
  }
  func sameSetup(_ a: ProgramSet, _ b: ProgramSet) -> Bool {
    a.variant == b.variant && ManualJSON.bytesEqual(a.setup, b.setup)
      && a.convention == b.convention
  }
  let reference = working(current).first
  let earlier = logs.filter {
    $0.id != current.id && $0.completed && $0.profile == current.profile
      && $0.programId == current.programId && $0.programVersion == current.programVersion
      && $0.startedTimestamp.microsecondsSince1970 < current.startedTimestamp.microsecondsSince1970
  }.sorted { a, b in
    a.startedTimestamp == b.startedTimestamp
      ? a.id > b.id
      : a.startedTimestamp.microsecondsSince1970 > b.startedTimestamp.microsecondsSince1970
  }
  for log in earlier {
    let sets = working(log)
    guard let anchor = reference ?? sets.first else { continue }
    let matched = sets.filter { sameSetup($0, anchor) }
    if !matched.isEmpty {
      return LastPerformance(log: log, sets: matched, matchesCurrentSetup: reference != nil)
    }
  }
  return nil
}
