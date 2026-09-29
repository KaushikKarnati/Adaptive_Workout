import Foundation

/// Show labeled historical contexts before a current setup is known, without inferring a target.
public func previousExerciseHistory(
  for exercise: ProgramExercise, in current: ProgramLog, history: [ProgramLog]
) -> [ExerciseHistorySeries] {
  exerciseHistory(
    history.filter {
      $0.profile == current.profile && $0.id != current.id
        && $0.startedTimestamp.microsecondsSince1970
          < current.startedTimestamp.microsecondsSince1970
        && $0.programVersion == current.programVersion && $0.programId == current.programId
    }
  ).filter { $0.key.slot == exercise.id }
}

/// The same measurement contract used by validation and the manual entry picker.
public func manualLoadConventions(for exercise: ProgramExercise, variant: String)
  -> [LoadConvention]
{
  guard
    exercise.alternatives.isEmpty ? variant == exercise.id : exercise.alternatives.contains(variant)
  else { return [] }
  if ["unassisted_pull_up", "hanging_knee_raise", "ab_wheel_rollout"].contains(variant) {
    return [.bodyweight]
  }
  if ["incline_dumbbell_press", "dumbbell_shoulder_press"].contains(variant) {
    return [.perDumbbell]
  }
  if variant == "assisted_machine_pull_up" { return [.assistance] }
  return [.machineSetting, .totalLoad, .platesOnly]
}

public struct ManualSetSlot: Equatable, Sendable, Identifiable {
  public let exercise: ProgramExercise
  public let index: Int
  public let side: LoggedSide
  public var id: String { "\(exercise.id)_\(index)_\(side.rawValue)" }
  public func record(in log: ProgramLog) -> ProgramSet? {
    log.sets.first {
      $0.slot == exercise.id && $0.index == index && $0.side == side && !$0.warmup
    }
  }
}

/// Preserve prescribed block, paired-round and side order; never infer completion from validity.
public func manualWorkingSlots(_ log: ProgramLog) -> [ManualSetSlot] {
  log.plan.blocks.flatMap { block in
    (1...(block.exercises.map(\.sets).max() ?? 1)).flatMap { index in
      block.exercises.flatMap { exercise -> [ManualSetSlot] in
        guard index <= exercise.sets else { return [] }
        return (exercise.eachSide ? [LoggedSide.left, .right] : [.both]).map {
          ManualSetSlot(exercise: exercise, index: index, side: $0)
        }
      }
    }
  }
}

/// A manual plan-order shortcut, not a generated recommendation or calendar schedule.
/// A draft wins; only explicitly finished sessions advance the displayed plan order.
public func nextManualPlan(_ logs: [ProgramLog], profile: String) -> ProgramSession {
  let scoped = logs.filter { $0.profile == profile }
  if let draft = scoped.filter({ !$0.completed }).sorted(by: { $0.id < $1.id }).first {
    return draft.plan
  }
  let last = scoped.filter(\.completed).sorted {
    let a = ($0.completedTimestamp ?? $0.startedTimestamp).microsecondsSince1970
    let b = ($1.completedTimestamp ?? $1.startedTimestamp).microsecondsSince1970
    return a == b ? $0.id < $1.id : a > b
  }.first
  guard let last, let index = ownerProgram.firstIndex(where: { $0.id == last.programId }) else {
    return ownerProgram[0]
  }
  return ownerProgram[(index + 1) % ownerProgram.count]
}

/// No guessed setup: only compare a set's exact context with a prior finished workout.
public func previousMatchingSets(
  for set: ProgramSet, in current: ProgramLog, history: [ProgramLog]
) -> [HistoryPoint] {
  let series = exerciseHistory(
    history.filter {
      $0.profile == current.profile && $0.id != current.id
        && $0.startedTimestamp.microsecondsSince1970
          < current.startedTimestamp.microsecondsSince1970
    }
  ).first {
    $0.key.version == current.programVersion && $0.key.program == current.programId
      && $0.key.slot == set.slot && $0.key.variant == set.variant
      && ManualJSON.bytesEqual($0.key.setup, set.setup)
      && $0.key.convention == set.convention && $0.key.side == set.side
  }
  guard let series, let last = series.points.last else { return [] }
  return series.points.filter { $0.log.id == last.log.id }
}

public struct LastTrainedArea: Identifiable, Equatable, Sendable {
  public let id: String
  public let days: Int
  public let log: ProgramLog
}

/// Call only with reviewed variation-to-area mappings. An empty map produces no invented anatomy.
public func lastTrainedAreas(
  _ logs: [ProgramLog], profile: String, reviewedAreas: [String: [String]],
  now: Date, calendar: Calendar
) -> [LastTrainedArea] {
  var result: [String: LastTrainedArea] = [:]
  for log in filterWorkoutHistory(logs, profile: profile) {
    guard let timestamp = log.completedTimestamp,
      timestamp.microsecondsSince1970 <= ManualTimestamp(now).microsecondsSince1970
    else { continue }
    let ended = timestamp.date
    let days =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: ended), to: calendar.startOfDay(for: now)
      ).day ?? 0
    for set in log.sets where !set.warmup && !set.skipped && (set.reps ?? 0) > 0 {
      for area in reviewedAreas[set.variant] ?? [] {
        if result[area] == nil
          || timestamp.microsecondsSince1970
            > result[area]!.log.completedTimestamp!.microsecondsSince1970
        {
          result[area] = LastTrainedArea(id: area, days: max(0, days), log: log)
        }
      }
    }
  }
  return result.values.sorted { $0.id < $1.id }
}
