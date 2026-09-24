import Foundation

public let sessionCompositionVersion = "owner-session-v2"
public let generatedProgramVersion = "owner-generated-v3"
public let generatedProgramId = "owner-program"

/// Trusted reviewed bindings; empty production bindings keep generation disabled.
public struct ProgramCatalogBindings: Sendable {
  public let version: String, reviewReference: String, catalogDigest: String
  public let exerciseIds: [String: String]
  public init(
    version: String, reviewReference: String, catalogDigest: String, exerciseIds: [String: String]
  ) throws {
    try validateSetupId(version)
    try validateSetupId(reviewReference)
    try requireSetup(engineMatches(catalogDigest, "^[a-f0-9]{64}$"), "invalid_digest")
    for (variation, id) in exerciseIds {
      try requireSetup(setupVariationNames[variation] != nil, "unknown_variation")
      try validateSetupId(id)
    }
    try requireSetup(Set(exerciseIds.values).count == exerciseIds.count, "ambiguous_binding")
    self.version = version
    self.reviewReference = reviewReference
    self.catalogDigest = catalogDigest
    self.exerciseIds = exerciseIds
  }
}
public struct SessionRehearsalVerification: Sendable {
  public let setupRevision: Int
  public let setup: VerifiedRehearsalSetup
  public init(setupRevision: Int, setup: VerifiedRehearsalSetup) {
    self.setupRevision = setupRevision
    self.setup = setup
  }
}
public struct SessionCompositionInput: Sendable {
  public let id: String, profile: String, sessionId: String, timezone: String
  public let createdAt: Date, requestedDate: Date
  public let setup: TrainingSetup?
  public let history: GeneratedHistory?
  public let eligibility: ExerciseEligibilityRequest
  public let inputRevisions: [String: Int]
  public let rehearsals: [SessionRehearsalVerification]
  public init(
    id: String, profile: String, sessionId: String, createdAt: Date, requestedDate: Date,
    timezone: String, setup: TrainingSetup?, history: GeneratedHistory?,
    eligibility: ExerciseEligibilityRequest, inputRevisions: [String: Int],
    rehearsals: [SessionRehearsalVerification]
  ) {
    self.id = id
    self.profile = profile
    self.sessionId = sessionId
    self.createdAt = createdAt
    self.requestedDate = requestedDate
    self.timezone = timezone
    self.setup = setup
    self.history = history
    self.eligibility = eligibility
    self.inputRevisions = inputRevisions
    self.rehearsals = rehearsals
  }
}
public struct SessionLoadProposal: Sendable {
  public let slotId: String, baselineReference: String
  public let result: LoadProgressionResult
  public init(slotId: String, baselineReference: String, result: LoadProgressionResult) {
    self.slotId = slotId
    self.baselineReference = baselineReference
    self.result = result
  }
}
public struct SessionExecutionTarget: Sendable {
  public let slotId: String
  public let target: SetTarget
}
public struct SessionCompositionResult: Sendable {
  public let reason: String
  public let snapshot: RecommendationSnapshot?
  public let proposals: [SessionLoadProposal]
  public let slotReasons: [String: String]
  init(
    _ reason: String, snapshot: RecommendationSnapshot? = nil,
    proposals: [SessionLoadProposal] = [], slotReasons: [String: String] = [:]
  ) {
    self.reason = reason
    self.snapshot = snapshot
    self.proposals = proposals
    self.slotReasons = slotReasons
  }
  public var isReady: Bool { snapshot?.status == .ready }
  public var durationFit: DurationFit { .estimateRequired }
  /// Both members rehearse before round one; paired working rounds alternate.
  public var executionOrder: [SessionExecutionTarget] {
    let slots = snapshot?.slots ?? []
    var blocks: [String] = []
    for slot in slots where !blocks.contains(slot.blockId) { blocks.append(slot.blockId) }
    var ordered: [SessionExecutionTarget] = []
    for block in blocks {
      let members = slots.filter { $0.blockId == block }
      for slot in members {
        ordered += slot.targets.filter(\.warmup).map { .init(slotId: slot.id, target: $0) }
      }
      var rounds: [Int] = []
      for target in members[0].targets where !target.warmup && !rounds.contains(target.index) {
        rounds.append(target.index)
      }
      for round in rounds {
        for slot in members {
          ordered += slot.targets.filter { !$0.warmup && $0.index == round }.map {
            .init(slotId: slot.id, target: $0)
          }
        }
      }
    }
    return ordered
  }
}
public struct SessionComposer: Sendable {
  public let evaluator: ExerciseEligibilityEvaluator
  public let bindings: ProgramCatalogBindings
  public init(evaluator: ExerciseEligibilityEvaluator, bindings: ProgramCatalogBindings) {
    self.evaluator = evaluator
    self.bindings = bindings
  }
  public func compose(_ input: SessionCompositionInput) -> SessionCompositionResult {
    do { return try composeValidated(input) } catch { return .init("invalid_input") }
  }
  private func composeValidated(_ input: SessionCompositionInput) throws -> SessionCompositionResult
  {
    guard let setup = input.setup, let history = input.history else {
      return .init("required_input_missing")
    }
    guard let session = ownerProgram.first(where: { $0.id == input.sessionId }),
      setup.profileId == input.profile, history.profile == input.profile,
      input.createdAt.timeIntervalSince1970.isFinite,
      input.requestedDate.timeIntervalSince1970.isFinite,
      input.createdAt >= setup.updatedAt,
      input.requestedDate.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400) == 0,
      setup.preferredMinutes != nil
    else { return .init("invalid_input") }
    if history.occurrences.contains(where: { $0.updatedAt > input.createdAt }) {
      return .init("invalid_history")
    }
    if history.occurrences.contains(where: { $0.status == .active }) {
      return .init("resume_session")
    }
    if history.occurrences.contains(where: { !$0.stoppedSlots.isEmpty })
      || setup.rehearsalConfirmations.contains(where: { $0.symptomsReported == true })
    {
      return .init("safety_stop")
    }
    if setup.rehearsalConfirmations.contains(where: {
      $0.sessionId == input.sessionId && $0.easyAndControlled == false
    }) {
      return .init("warmup_setup_review_required")
    }
    if ["profile", "equipment", "baseline", "constraints"].contains(where: {
      input.inputRevisions[$0] != setup.revision
    }) {
      return .init("stale_input")
    }
    let eligibility = evaluator.evaluate(input.eligibility)
    guard [.evaluated, .constrainedNoCandidate].contains(eligibility.status) else {
      return .init(eligibility.status.rawValue)
    }
    guard bindings.catalogDigest == input.eligibility.catalogContentSha256 else {
      return .init("binding_catalog_mismatch")
    }
    guard
      engineSame(
        input.eligibility.functionalCapabilityAssessment?.supportedIds, setup.supportedCapabilities),
      engineSame(
        input.eligibility.functionalCapabilityAssessment?.unsupportedIds,
        setup.unsupportedCapabilities),
      engineSame(input.eligibility.limitationAssessment?.ids, setup.limitations)
    else { return .init("constraint_setup_mismatch") }
    var slots: [RecommendedSlot] = []
    var proposals: [SessionLoadProposal] = []
    var reasons: [String: String] = [:]
    var evidence: [String: Int] = [:]
    var firstExternal = true
    for (blockIndex, block) in session.blocks.enumerated() {
      for (position, exercise) in block.exercises.enumerated() {
        let variants = setupVariantsFor(exercise)
        if variants.contains(where: {
          bindings.exerciseIds[$0] == nil
            || !(input.eligibility.candidateExerciseIds ?? []).contains(bindings.exerciseIds[$0]!)
        }) {
          reasons[exercise.id] = "catalog_binding_required"
          continue
        }
        var selection: (EquipmentSetup, StartingLoad, String)?
        for variant in variants {
          guard !setup.excludedVariations.contains(variant), let id = bindings.exerciseIds[variant],
            eligibility.eligibleExerciseIds.contains(id)
          else { continue }
          let baselines = setup.startingLoads.filter {
            $0.sessionId == session.id && $0.slotId == exercise.id && $0.variation == variant
              && setup.baselineIsCurrent($0)
          }
          if baselines.count > 1 { return .init("setup_selection_required") }
          guard let baseline = baselines.first,
            let equipment = setup.equipment.first(where: { $0.id == baseline.setupId })
          else { continue }
          selection = (equipment, baseline, id)
          break
        }
        guard let (equipment, baseline, selectedId) = selection else {
          reasons[exercise.id] = "eligible_setup_and_baseline_required"
          continue
        }
        guard let entry = input.eligibility.catalog!.first(where: { $0.id == selectedId }),
          (entry.laterality == .unilateral) == exercise.eachSide,
          entry.laterality != .alternating,
          engineMatchesEquipment(entry, equipment, input.eligibility)
        else {
          reasons[exercise.id] = "catalog_setup_mismatch"
          continue
        }
        let convention = engineConvention(equipment.convention)
        let sides: [LoggedSide] = exercise.eachSide ? [.left, .right] : [.both]
        var work: [SetTarget] = []
        for round in 1...exercise.sets {
          for side in sides {
            work.append(
              try .init(
                index: round, side: side, warmup: false, load: baseline.microPounds,
                minReps: exercise.minReps, maxReps: exercise.maxReps, minRir: exercise.minRir,
                maxRir: exercise.maxRir,
                restSeconds: position == block.exercises.count - 1 && side == sides.last
                  ? block.restSeconds : 0))
          }
        }
        func slot(_ targets: [SetTarget]) throws -> RecommendedSlot {
          try .init(
            id: exercise.id, exerciseId: selectedId, blockId: "block_\(blockIndex + 1)",
            setupId: equipment.id, setupRevision: equipment.revision,
            baselineReference: "baseline_" + sha256Hex(Data(baseline.canonicalJSON.utf8)),
            convention: convention, unilateral: exercise.eachSide, targets: targets)
        }
        let provisional = try slot(work)
        let context = progressionContext(input.profile, generatedProgramId, session.id, provisional)
        let verified = VerifiedLoadBaseline(
          context: context, microPounds: baseline.microPounds ?? 0)
        let progression = LoadProgressionPolicy().evaluate(
          .init(
            context: context, gate: .permitted, baseline: verified,
            availableLoadsMicroPounds: convention == .bodyweight ? [0] : equipment.workingLoads,
            history: history.progression(
              programId: generatedProgramId, programVersion: generatedProgramVersion,
              sessionTemplate: session.id, current: provisional)))
        if progression.action == .blocked {
          reasons[exercise.id] = progression.reasonCode
          continue
        }
        for id in progression.evidenceIds {
          evidence[id] = history.occurrences.first(where: { $0.id == id })!.revision
        }
        var warmups: [SetTarget] = []
        if context.loadKind == .external {
          let plan = externalWarmupV2(
            gate: .permitted, context: context, baseline: verified,
            availableLoadsMicroPounds: Array(
              Set(equipment.rehearsalLoads + [baseline.microPounds!])),
            firstExternalLoadExercise: firstExternal)
          firstExternal = false
          if plan.isBlocked {
            reasons[exercise.id] = plan.reasonCode
            continue
          }
          for (index, target) in plan.sets.enumerated() {
            for side in sides {
              warmups.append(
                try .init(
                  index: index + 1, side: side, warmup: true, load: target.microPounds,
                  minReps: target.reps, maxReps: target.reps, minRir: nil, maxRir: nil,
                  restSeconds: side == sides.last ? target.restAfterSeconds : 0))
            }
          }
        } else {
          guard
            let plan = bodyweight(input, equipment, exercise.id, eligibility.eligibleExerciseIds),
            !plan.isBlocked
          else {
            reasons[exercise.id] = "warmup_setup_required"
            continue
          }
          for (index, target) in plan.sets.enumerated() {
            let rehearsalEquipment = setup.equipment.first { $0.id == target.context.setupId }!
            warmups.append(
              try .init(
                index: index + 1, side: .both, warmup: true, load: target.assistanceMicroPounds,
                minReps: target.reps, maxReps: target.reps, minRir: nil, maxRir: nil,
                restSeconds: target.restAfterSeconds, rangeReference: target.rangeRef,
                rehearsalIdentity: .init(
                  exerciseId: target.context.exerciseId, setupId: rehearsalEquipment.id,
                  setupRevision: rehearsalEquipment.revision,
                  convention: engineConvention(rehearsalEquipment.convention),
                  verificationReference: target.verificationRef)))
          }
        }
        reasons[exercise.id] = progression.reasonCode
        if [.increase, .decrease].contains(progression.action) {
          proposals.append(
            .init(
              slotId: exercise.id, baselineReference: provisional.baselineReference,
              result: progression))
        }
        let range = rehearsals(input).first { v in
          v.setup.context.profileId == input.profile
            && v.setup.context.slotId == "\(input.sessionId)/\(exercise.id)"
            && v.setup.context.exerciseId == selectedId && v.setup.context.setupId == equipment.id
            && v.setupRevision == equipment.revision
        }?.setup.workingRangeRef
        if let range {
          work = try work.map {
            try SetTarget(
              index: $0.index, side: $0.side, warmup: false, load: $0.load, minReps: $0.minReps,
              maxReps: $0.maxReps, minRir: $0.minRir, maxRir: $0.maxRir,
              restSeconds: $0.restSeconds, rangeReference: range)
          }
        }
        slots.append(try slot(warmups + work))
      }
    }
    let ready = slots.count == session.blocks.flatMap(\.exercises).count
    var snapshotReasons = [
      ready ? "session_ready" : "session_setup_required", "duration_estimate_required",
    ]
    if ready && !proposals.isEmpty { snapshotReasons.append("load_change_confirmation_required") }
    let snapshot = try RecommendationSnapshot(
      schemaVersion: 2,
      generationReferences: [
        "bindings": bindings.version, "bindingReview": bindings.reviewReference,
        "warmup": warmupRuleVersion, "progression": "owner-program-v1",
        "catalogSchema": input.eligibility.schemaVersion!,
        "taxonomy": input.eligibility.taxonomyVersion!,
        "eligibility": input.eligibility.eligibilityRuleSetVersion!,
        "constraints": input.eligibility.constraintSnapshotSha256!,
      ], slotReasons: reasons,
      proposedLoads: ready
        ? Dictionary(
          uniqueKeysWithValues: proposals.map { ($0.slotId, $0.result.candidateMicroPounds!) })
        : [:], id: input.id, profile: input.profile, programId: generatedProgramId,
      programVersion: generatedProgramVersion, sessionTemplate: session.id,
      ruleVersion: sessionCompositionVersion, catalogVersion: input.eligibility.catalogVersion!,
      catalogDigest: bindings.catalogDigest, createdAt: input.createdAt,
      requestedDate: input.requestedDate, timezone: input.timezone,
      historyRevision: history.revision, inputRevisions: input.inputRevisions, evidence: evidence,
      status: ready ? .ready : .blocked, reasons: snapshotReasons, slots: ready ? slots : [],
      walkSeconds: ready ? WarmupPolicy.sessionWalkingSeconds : 0,
      preferredMinutes: setup.preferredMinutes!, estimatedSeconds: nil)
    return .init(
      ready ? "session_ready" : "session_setup_required", snapshot: snapshot,
      proposals: ready ? proposals : [], slotReasons: reasons)
  }
  private func rehearsals(_ input: SessionCompositionInput) -> [SessionRehearsalVerification] {
    var values = input.rehearsals
    for confirmation in input.setup!.rehearsalConfirmations {
      guard confirmation.hasCompleteAttestation,
        let id = bindings.exerciseIds[confirmation.variation],
        let equipment = input.setup!.equipment.first(where: {
          $0.id == confirmation.setupId && $0.confirmed && $0.revision == confirmation.setupRevision
            && confirmation.recordedAt >= $0.confirmedAt!
        })
      else { continue }
      let movement: RehearsalMovement
      switch confirmation.variation {
      case "assisted_machine_pull_up": movement = .assistedPullUp
      case "unassisted_pull_up": movement = .unassistedPullUp
      case "supported_knee_raise": movement = .supportedKneeRaise
      default: movement = .kneelingRollout
      }
      values.append(
        .init(
          setupRevision: confirmation.setupRevision!,
          setup: .init(
            context: .init(
              profileId: input.profile, slotId: "\(confirmation.sessionId)/\(confirmation.slotId)",
              exerciseId: id, setupId: confirmation.setupId!, movement: movement),
            verificationRef: confirmation.id, easyAndControlled: confirmation.easyAndControlled,
            assistanceMicroPounds: confirmation.assistance,
            availableAssistanceMicroPounds: confirmation.variation == "assisted_machine_pull_up"
              ? equipment.rehearsalLoads : nil, workingRangeRef: confirmation.workingRangeRef,
            rehearsalRangeRef: confirmation.rehearsalRangeRef,
            rehearsalWithinWorkingRange: confirmation.withinWorkingRange)))
    }
    return values
  }
  private func bodyweight(
    _ input: SessionCompositionInput, _ work: EquipmentSetup, _ slot: String, _ eligible: [String]
  ) -> RehearsalPlan? {
    let setup = input.setup!
    func verified(_ variant: String, _ movement: RehearsalMovement, exactSetup: String? = nil)
      -> VerifiedRehearsalSetup?
    {
      guard let id = bindings.exerciseIds[variant], eligible.contains(id),
        !setup.excludedVariations.contains(variant)
      else { return nil }
      let matches = rehearsals(input).filter { v in
        v.setup.context.profileId == input.profile
          && v.setup.context.slotId == "\(input.sessionId)/\(slot)"
          && v.setup.context.exerciseId == id && v.setup.context.movement == movement
          && (exactSetup == nil || v.setup.context.setupId == exactSetup)
      }
      guard matches.count == 1 else { return nil }
      let verification = matches[0]
      let rehearsal = verification.setup
      let equipment = setup.equipment.filter {
        $0.id == rehearsal.context.setupId && $0.variation == variant && $0.confirmed
          && verification.setupRevision == $0.revision
      }
      guard equipment.count == 1,
        let entry = input.eligibility.catalog!.first(where: { $0.id == id }),
        entry.laterality == .bilateral,
        engineMatchesEquipment(entry, equipment[0], input.eligibility)
      else { return nil }
      if movement == .assistedPullUp
        && (!engineSame(rehearsal.availableAssistanceMicroPounds, equipment[0].rehearsalLoads)
          || rehearsal.assistanceMicroPounds.map(equipment[0].rehearsalLoads.contains) != true)
      {
        return nil
      }
      return rehearsal
    }
    let policy = BodyweightWarmupPolicy()
    if ["unassisted_pull_up", "assisted_machine_pull_up"].contains(work.variation) {
      let unassisted = work.variation == "unassisted_pull_up"
      guard
        let assisted = verified(
          "assisted_machine_pull_up", .assistedPullUp, exactSetup: unassisted ? nil : work.id)
      else { return nil }
      let body =
        unassisted ? verified("unassisted_pull_up", .unassistedPullUp, exactSetup: work.id) : nil
      if unassisted && body == nil { return nil }
      return policy.pullUps(
        gate: .permitted, includesUnassistedWork: unassisted, assistedContext: assisted.context,
        assistedSetup: assisted, unassistedContext: body?.context, unassistedSetup: body)
    }
    let movement: RehearsalMovement
    switch work.variation {
    case "supported_knee_raise": movement = .supportedKneeRaise
    case "kneeling_ab_wheel": movement = .kneelingRollout
    default: return nil
    }
    guard let body = verified(work.variation, movement, exactSetup: work.id) else { return nil }
    return policy.core(gate: .permitted, context: body.context, setup: body)
  }
}
private func engineSame<T: Hashable>(_ lhs: [T]?, _ rhs: [T]?) -> Bool {
  guard let lhs, let rhs else { return false }
  return lhs.count == rhs.count && Set(lhs).isSuperset(of: rhs)
}
private func engineConvention(_ value: SetupLoadConvention) -> LoadConvention {
  value == .totalExternal ? .totalLoad : LoadConvention(rawValue: value.rawValue)!
}
private func engineMatchesEquipment(
  _ entry: ExerciseCatalogEntry, _ equipment: EquipmentSetup, _ request: ExerciseEligibilityRequest
) -> Bool {
  guard entry.trackingMode == (equipment.convention == .bodyweight ? .repsOnly : .loadReps) else {
    return false
  }
  guard let equipmentId = equipment.equipmentId else { return entry.equipmentRequirements.isEmpty }
  let requirements = entry.equipmentRequirements.filter { $0.equipmentId == equipmentId }
  return !requirements.isEmpty
    && requirements.allSatisfy {
      equipment.quantity >= $0.quantity
        && Set(equipment.capabilities).isSuperset(of: $0.capabilityIds)
    }
    && (request.equipmentInventory ?? []).contains {
      $0.equipmentId == equipmentId && $0.quantity >= equipment.quantity
        && Set($0.capabilityIds).isSuperset(of: equipment.capabilities)
    }
}
