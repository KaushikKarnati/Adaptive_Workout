import Foundation

public struct WarmupSetTarget: Equatable, Sendable {
  public let microPounds: Int
  public let reps: Int
  public let restAfterSeconds: Int
  public var isWorkingSet: Bool { false }
}
public struct WarmupResult: Equatable, Sendable {
  public let ruleSetVersion = "owner-warmup-v1"
  public let reasonCode: String
  public let sets: [WarmupSetTarget]
  public var isBlocked: Bool { sets.isEmpty }
}
/// Targets only; never automatically advances a live exercise.
public struct WarmupPolicy: Sendable {
  public init() {}
  public static let sessionWalkingSeconds = 300
  public func evaluate(
    gate: ProgressionGate?, context: ProgressionContext, baseline: VerifiedLoadBaseline?,
    availableLoadsMicroPounds: [Int]?, firstExternalLoadExercise: Bool
  ) -> WarmupResult {
    func blocked(_ reason: String) -> WarmupResult { .init(reasonCode: reason, sets: []) }
    if let issue = engineGateIssue(gate) { return blocked(issue) }
    guard context.isValid, context.loadKind == .external, let baseline, baseline.context == context,
      baseline.microPounds > 0,
      let loads = availableLoadsMicroPounds, !loads.isEmpty, loads.allSatisfy({ $0 >= 0 }),
      loads.contains(baseline.microPounds)
    else { return blocked("warmup_setup_required") }
    let ordered = Set(loads).sorted()
    var targets: [WarmupSetTarget] = []
    for (index, percentage) in (firstExternalLoadExercise ? [50, 75] : [50]).enumerated() {
      guard
        let feasible = ordered.last(where: {
          engineProductLE($0, 100, baseline.microPounds, percentage)
        })
      else { return blocked("warmup_setup_required") }
      targets.append(
        .init(
          microPounds: feasible, reps: firstExternalLoadExercise && index == 0 ? 8 : 5,
          restAfterSeconds: firstExternalLoadExercise && index == 1 ? 90 : 60))
    }
    return .init(reasonCode: "warmup_targets_ready", sets: targets)
  }
}
public let warmupRuleVersion = "owner-warmup-v2"
public enum RehearsalMovement: String, Codable, Sendable {
  case assistedPullUp, unassistedPullUp, supportedKneeRaise, kneelingRollout
}
public struct RehearsalContext: Equatable, Codable, Sendable {
  public let profileId: String
  public let slotId: String
  public let exerciseId: String
  public let setupId: String
  public let movement: RehearsalMovement
  public init(
    profileId: String, slotId: String, exerciseId: String, setupId: String,
    movement: RehearsalMovement
  ) {
    self.profileId = profileId
    self.slotId = slotId
    self.exerciseId = exerciseId
    self.setupId = setupId
    self.movement = movement
  }
}
public struct VerifiedRehearsalSetup: Equatable, Sendable {
  public let context: RehearsalContext
  public let verificationRef: String
  public let easyAndControlled: Bool?
  public let assistanceMicroPounds: Int?
  public let availableAssistanceMicroPounds: [Int]?
  public let workingRangeRef: String?
  public let rehearsalRangeRef: String?
  public let rehearsalWithinWorkingRange: Bool?
  public init(
    context: RehearsalContext, verificationRef: String, easyAndControlled: Bool?,
    assistanceMicroPounds: Int? = nil, availableAssistanceMicroPounds: [Int]? = nil,
    workingRangeRef: String? = nil, rehearsalRangeRef: String? = nil,
    rehearsalWithinWorkingRange: Bool? = nil
  ) {
    self.context = context
    self.verificationRef = verificationRef
    self.easyAndControlled = easyAndControlled
    self.assistanceMicroPounds = assistanceMicroPounds
    self.availableAssistanceMicroPounds = availableAssistanceMicroPounds
    self.workingRangeRef = workingRangeRef
    self.rehearsalRangeRef = rehearsalRangeRef
    self.rehearsalWithinWorkingRange = rehearsalWithinWorkingRange
  }
}
public struct RehearsalTarget: Equatable, Sendable {
  public let context: RehearsalContext
  public let verificationRef: String
  public let reps: Int
  public let restAfterSeconds: Int
  public let assistanceMicroPounds: Int?
  public let rangeRef: String?
  public var isWorkingSet: Bool { false }
}
public struct RehearsalPlan: Equatable, Sendable {
  public let ruleSetVersion = warmupRuleVersion
  public let reasonCode: String
  public let sets: [RehearsalTarget]
  public var isBlocked: Bool { sets.isEmpty }
}
public struct BodyweightWarmupPolicy: Sendable {
  public init() {}
  public func pullUps(
    gate: ProgressionGate?, includesUnassistedWork: Bool?, assistedContext: RehearsalContext,
    assistedSetup: VerifiedRehearsalSetup?, unassistedContext: RehearsalContext?,
    unassistedSetup: VerifiedRehearsalSetup?
  ) -> RehearsalPlan {
    if let issue = engineGateIssue(gate) { return blocked(issue) }
    guard let includesUnassistedWork, assistedContext.movement == .assistedPullUp,
      validSetup(assistedContext, assistedSetup)
    else { return blocked("warmup_setup_required") }
    if includesUnassistedWork {
      guard let unassistedContext, unassistedContext.movement == .unassistedPullUp,
        unassistedContext.profileId == assistedContext.profileId,
        unassistedContext.slotId == assistedContext.slotId,
        validSetup(unassistedContext, unassistedSetup)
      else { return blocked("warmup_setup_required") }
    } else if unassistedContext != nil || unassistedSetup != nil {
      return blocked("invalid_input")
    }
    var targets = [target(assistedSetup!, reps: 5, rest: includesUnassistedWork ? 60 : 120)]
    if includesUnassistedWork { targets.append(target(unassistedSetup!, reps: 2, rest: 120)) }
    return .init(reasonCode: "warmup_targets_ready", sets: targets)
  }
  public func core(
    gate: ProgressionGate?, context: RehearsalContext, setup: VerifiedRehearsalSetup?
  ) -> RehearsalPlan {
    if let issue = engineGateIssue(gate) { return blocked(issue) }
    guard [.supportedKneeRaise, .kneelingRollout].contains(context.movement),
      validSetup(context, setup)
    else { return blocked("warmup_setup_required") }
    return .init(
      reasonCode: "warmup_targets_ready",
      sets: [target(setup!, reps: context.movement == .supportedKneeRaise ? 5 : 3, rest: 60)])
  }
  private func target(_ setup: VerifiedRehearsalSetup, reps: Int, rest: Int) -> RehearsalTarget {
    .init(
      context: setup.context, verificationRef: setup.verificationRef, reps: reps,
      restAfterSeconds: rest, assistanceMicroPounds: setup.assistanceMicroPounds,
      rangeRef: setup.rehearsalRangeRef)
  }
  private func blocked(_ reason: String) -> RehearsalPlan { .init(reasonCode: reason, sets: []) }
  private func validSetup(_ context: RehearsalContext, _ setup: VerifiedRehearsalSetup?) -> Bool {
    guard
      [context.profileId, context.slotId, context.exerciseId, context.setupId].allSatisfy({
        engineValidRef($0)
      }),
      let setup, setup.context == context, engineValidRef(setup.verificationRef),
      setup.easyAndControlled == true
    else { return false }
    if context.movement == .assistedPullUp {
      guard let assistance = setup.assistanceMicroPounds, assistance > 0,
        let settings = setup.availableAssistanceMicroPounds,
        !settings.isEmpty, settings.allSatisfy({ $0 > 0 }), Set(settings).count == settings.count,
        settings.contains(assistance)
      else { return false }
      return setup.workingRangeRef == nil && setup.rehearsalRangeRef == nil
        && setup.rehearsalWithinWorkingRange == nil
    }
    guard setup.assistanceMicroPounds == nil, setup.availableAssistanceMicroPounds == nil else {
      return false
    }
    if context.movement == .unassistedPullUp {
      return setup.workingRangeRef == nil && setup.rehearsalRangeRef == nil
        && setup.rehearsalWithinWorkingRange == nil
    }
    return engineValidRef(setup.workingRangeRef) && engineValidRef(setup.rehearsalRangeRef)
      && setup.rehearsalWithinWorkingRange == true
      && (context.movement != .supportedKneeRaise
        || setup.workingRangeRef == setup.rehearsalRangeRef)
  }
}
func engineValidRef(_ value: String?) -> Bool {
  guard let value, !value.isEmpty, value.utf8.count <= 128 else { return false }
  return value.utf8.allSatisfy { $0 >= 0x21 && $0 <= 0x7e }
}
func engineGateIssue(_ gate: ProgressionGate?) -> String? {
  switch gate {
  case .safetyStop: return "safety_stop"
  case .permitted: return nil
  default: return "current_checks_required"
  }
}
public enum RehearsalFeedback: String, Codable, Sendable {
  case easyAndControlled, notEasyOrNotControlled, unknown
}
public func evaluateWarmupContinuation(
  gate: ProgressionGate?, interrupted: Bool?, targetCompleted: Bool?, feedback: RehearsalFeedback?,
  elapsedRestSeconds: Int?, prescribedRestSeconds: Int, userContinues: Bool?
) -> String {
  if let issue = engineGateIssue(gate) { return issue }
  guard prescribedRestSeconds > 0, elapsedRestSeconds == nil || elapsedRestSeconds! >= 0 else {
    return "invalid_input"
  }
  guard interrupted == false else { return "preparation_review_required" }
  guard targetCompleted == true else { return "rehearsal_completion_required" }
  if feedback == .notEasyOrNotControlled { return "warmup_setup_review_required" }
  guard feedback == .easyAndControlled else { return "warmup_feedback_required" }
  guard let elapsedRestSeconds else { return "rest_time_required" }
  guard elapsedRestSeconds >= prescribedRestSeconds else { return "rest_incomplete" }
  guard userContinues == true else { return "continuation_required" }
  return "next_planned_action_permitted"
}
public struct ExternalWarmupPlanV2: Equatable, Sendable {
  public let reasonCode: String
  public let sets: [WarmupSetTarget]
  public var ruleSetVersion: String { warmupRuleVersion }
  public var isBlocked: Bool { sets.isEmpty }
}
public func externalWarmupV2(
  gate: ProgressionGate?, context: ProgressionContext, baseline: VerifiedLoadBaseline?,
  availableLoadsMicroPounds: [Int]?, firstExternalLoadExercise: Bool
) -> ExternalWarmupPlanV2 {
  let result = WarmupPolicy().evaluate(
    gate: gate, context: context, baseline: baseline,
    availableLoadsMicroPounds: availableLoadsMicroPounds,
    firstExternalLoadExercise: firstExternalLoadExercise)
  return .init(reasonCode: result.reasonCode, sets: result.sets)
}
