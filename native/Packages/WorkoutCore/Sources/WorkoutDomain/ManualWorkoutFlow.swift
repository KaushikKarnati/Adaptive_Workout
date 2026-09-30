import Foundation

/// Load semantics shared by manual entry and storage validation.
public func manualLoadConventions(variant: String) -> [LoadConvention] {
  if ["unassisted_pull_up", "hanging_knee_raise", "ab_wheel_rollout"].contains(variant) {
    return [.bodyweight]
  }
  if ["incline_dumbbell_press", "dumbbell_shoulder_press"].contains(variant) {
    return [.perDumbbell]
  }
  if variant == "assisted_machine_pull_up" { return [.assistance] }
  return [.machineSetting, .platesOnly, .totalLoad]
}

public struct ManualSetTarget: Equatable, Sendable, Identifiable {
  public let exercise: ProgramExercise
  public let index: Int
  public let side: LoggedSide
  public var id: String { "set_\(exercise.id)_\(index)_\(side.rawValue)_false" }
}

extension ProgramLog {
  /// Explicit block order, paired rounds, then both sides before moving on.
  public var workingTargets: [ManualSetTarget] {
    plan.blocks.flatMap { block in
      (1...(block.exercises.map(\.sets).max() ?? 1)).flatMap { index in
        block.exercises.filter { index <= $0.sets }.flatMap { exercise in
          (exercise.eachSide ? [LoggedSide.left, .right] : [.both]).map { side in
            ManualSetTarget(exercise: exercise, index: index, side: side)
          }
        }
      }
    }
  }
  public var currentTarget: ManualSetTarget? {
    guard !completed else { return nil }
    return workingTargets.first { target in
      !sets.contains {
        !$0.warmup && $0.slot == target.exercise.id && $0.index == target.index
          && $0.side == target.side
      }
    }
  }
  /// Never copy another exercise, side, warm-up category, future set or skip.
  public func previousSet(slot: String, index: Int, side: LoggedSide, warmup: Bool) -> ProgramSet? {
    sets.filter {
      $0.slot == slot && $0.index < index && $0.side == side && $0.warmup == warmup && !$0.skipped
    }.max { $0.index < $1.index }
  }
}
