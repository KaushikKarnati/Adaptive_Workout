import Foundation
import WorkoutDomain

/// Tracks progress toward completing the required manual workout logs to unlock the adaptive engine.
public struct CalibrationProgress: Equatable, Sendable {
  public let loggedCount: Int
  public let requiredCount: Int

  public init(loggedCount: Int, requiredCount: Int = 7) {
    self.loggedCount = loggedCount
    self.requiredCount = requiredCount
  }

  public var remainingCount: Int {
    max(0, requiredCount - loggedCount)
  }

  public var isUnlocked: Bool {
    loggedCount >= requiredCount
  }

  public var fraction: Double {
    guard requiredCount > 0 else { return 1.0 }
    return min(1.0, max(0.0, Double(loggedCount) / Double(requiredCount)))
  }

  public var percentage: Int {
    Int((fraction * 100).rounded())
  }
}

/// Deterministically seeds and calibrates verified training setups and starting loads
/// from the user's manual log history, unlocking the adaptive generation engine.
public struct BaselineCalibrationService: Sendable {
  public let programLogsRepository: any ProgramLogRepository
  public let setupRepository: any TrainingSetupRepository
  public let profileId: String
  public let now: @Sendable () -> Date

  public init(
    programLogsRepository: any ProgramLogRepository,
    setupRepository: any TrainingSetupRepository,
    profileId: String = "local_owner",
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.programLogsRepository = programLogsRepository
    self.setupRepository = setupRepository
    self.profileId = profileId
    self.now = now
  }

  public func getCalibrationProgress() throws -> CalibrationProgress {
    let logs = try programLogsRepository.load(profileId)
    let validLogs = logs.filter { log in
      log.completed || log.sets.contains { !$0.warmup && !$0.skipped && $0.validity == .valid }
    }
    return CalibrationProgress(loggedCount: validLogs.count, requiredCount: 7)
  }

  public static let defaultVariantLoads: [String: (convention: SetupLoadConvention, load: Int?)] = [
    "incline_dumbbell_press": (.perDumbbell, 30_000_000),
    "neutral_grip_lat_pulldown": (.machineSetting, 90_000_000),
    "incline_machine_press": (.machineSetting, 70_000_000),
    "chest_supported_row": (.machineSetting, 60_000_000),
    "cable_lateral_raise": (.machineSetting, 15_000_000),
    "cable_chest_fly": (.machineSetting, 25_000_000),
    "leg_press": (.platesOnly, 180_000_000),
    "leg_extension": (.machineSetting, 75_000_000),
    "seated_leg_curl": (.machineSetting, 70_000_000),
    "lying_leg_curl": (.machineSetting, 60_000_000),
    "machine_calf_raise": (.machineSetting, 100_000_000),
    "cable_crunch": (.machineSetting, 50_000_000),
    "machine_shoulder_press": (.machineSetting, 60_000_000),
    "dumbbell_shoulder_press": (.perDumbbell, 25_000_000),
    "reverse_pec_deck": (.machineSetting, 50_000_000),
    "cable_curl": (.machineSetting, 30_000_000),
    "overhead_cable_triceps_extension": (.machineSetting, 35_000_000),
    "supported_knee_raise": (.bodyweight, nil),
    "unassisted_pull_up": (.bodyweight, nil),
    "assisted_machine_pull_up": (.assistance, 70_000_000),
    "seated_cable_row": (.machineSetting, 80_000_000),
    "single_arm_cable_pulldown": (.machineSetting, 40_000_000),
    "machine_chest_fly": (.machineSetting, 70_000_000),
    "hack_squat": (.platesOnly, 140_000_000),
    "kneeling_ab_wheel": (.bodyweight, nil),
  ]

  @discardableResult
  public func calibrateBaselines(actionId: String) throws -> TrainingSetup {
    let currentNow = now()
    let existingSetup = try setupRepository.load(profileId)
    let logs = try programLogsRepository.load(profileId)

    // Extract latest valid working set load per variation from manual logs
    var loggedLoadsByVariant: [String: (load: Int?, setup: String, convention: LoadConvention)] =
      [:]
    for log in logs.sorted(by: { $0.startedAt < $1.startedAt }) {
      for set in log.sets where !set.warmup && !set.skipped && set.validity == .valid {
        loggedLoadsByVariant[set.variant] = (set.load, set.setup, set.convention)
      }
    }

    var equipmentList: [EquipmentSetup] = []
    var variantConventions: [String: SetupLoadConvention] = [:]
    var variantLoads: [String: Int?] = [:]

    let allVariants = Array(Self.defaultVariantLoads.keys).sorted()

    for variant in allVariants {
      let defaultInfo = Self.defaultVariantLoads[variant]!
      let convention: SetupLoadConvention
      let load: Int?
      let label: String

      if let logged = loggedLoadsByVariant[variant] {
        convention =
          SetupLoadConvention(rawValue: logged.convention.rawValue) ?? defaultInfo.convention
        load = (convention == .bodyweight) ? nil : (logged.load ?? defaultInfo.load)
        label = logged.setup.isEmpty ? (setupVariationNames[variant] ?? variant) : logged.setup
      } else {
        convention = defaultInfo.convention
        load = defaultInfo.load
        label = setupVariationNames[variant] ?? variant
      }

      variantConventions[variant] = convention
      variantLoads[variant] = load

      let workingLoads: [Int]
      let rehearsalLoads: [Int]

      if convention == .bodyweight {
        workingLoads = []
        rehearsalLoads = []
      } else if convention == .assistance {
        let baseLoad = load ?? 70_000_000
        workingLoads = [baseLoad]
        rehearsalLoads = [baseLoad]
      } else if let baseLoad = load {
        // Construct increments around the working load, ensuring 50% & 75% warmup loads exist
        var work = Set<Int>()
        work.insert(baseLoad)
        for offset in [
          -30_000_000, -20_000_000, -10_000_000, -5_000_000, 5_000_000, 10_000_000, 20_000_000,
        ] {
          let candidate = baseLoad + offset
          if candidate > 0 { work.insert(candidate) }
        }
        workingLoads = work.sorted()
        rehearsalLoads = Array(Set([0, baseLoad / 4, baseLoad / 2, (baseLoad * 3) / 4, baseLoad]))
          .sorted()
      } else {
        workingLoads = []
        rehearsalLoads = []
      }

      let eqId = "eq_\(variant)"
      let eq: EquipmentSetup
      if let priorEq = existingSetup?.equipment.first(where: { $0.id == eqId }),
        priorEq.variation == variant && priorEq.convention == convention
      {
        let unchanged =
          priorEq.label == label && priorEq.workingLoads == workingLoads
          && priorEq.rehearsalLoads == rehearsalLoads
        if unchanged {
          eq = priorEq
        } else {
          eq = try EquipmentSetup(
            id: eqId,
            revision: priorEq.revision + 1,
            label: label,
            variation: variant,
            equipmentId: nil,
            quantity: 1,
            capabilities: [],
            convention: convention,
            workingLoads: workingLoads,
            rehearsalLoads: rehearsalLoads,
            confirmedAt: currentNow
          )
        }
      } else {
        eq = try EquipmentSetup(
          id: eqId,
          revision: 0,
          label: label,
          variation: variant,
          equipmentId: nil,
          quantity: 1,
          capabilities: [],
          convention: convention,
          workingLoads: workingLoads,
          rehearsalLoads: rehearsalLoads,
          confirmedAt: currentNow
        )
      }
      equipmentList.append(eq)
    }

    var startingLoadsList: [StartingLoad] = []

    for session in ownerProgram {
      for exercise in session.exercises {
        for variant in setupVariantsFor(exercise) {
          let convention =
            variantConventions[variant] ?? Self.defaultVariantLoads[variant]!.convention
          let load = variantLoads[variant] ?? Self.defaultVariantLoads[variant]!.load
          let eqRevision = equipmentList.first(where: { $0.id == "eq_\(variant)" })?.revision ?? 0
          let startId = "base_\(session.id)_\(exercise.id)_\(variant)"
          let targetMicro = convention == .bodyweight ? nil : load

          let starting: StartingLoad
          if let priorStart = existingSetup?.startingLoads.first(where: { $0.id == startId }),
            priorStart.variation == variant && priorStart.convention == convention
          {
            let unchanged =
              priorStart.microPounds == targetMicro && priorStart.setupRevision == eqRevision
            if unchanged {
              starting = priorStart
            } else {
              starting = try StartingLoad(
                id: startId,
                sessionId: session.id,
                slotId: exercise.id,
                variation: variant,
                setupId: "eq_\(variant)",
                setupRevision: eqRevision,
                convention: convention,
                microPounds: targetMicro,
                confirmedAt: currentNow
              )
            }
          } else {
            starting = try StartingLoad(
              id: startId,
              sessionId: session.id,
              slotId: exercise.id,
              variation: variant,
              setupId: "eq_\(variant)",
              setupRevision: eqRevision,
              convention: convention,
              microPounds: targetMicro,
              confirmedAt: currentNow
            )
          }
          startingLoadsList.append(starting)
        }
      }
    }

    var rehearsals: [RehearsalConfirmation] = []
    let bodyweightVariants = [
      "assisted_machine_pull_up", "unassisted_pull_up", "supported_knee_raise", "kneeling_ab_wheel",
    ]

    for session in ownerProgram {
      for exercise in session.exercises {
        for variant in bodyweightVariants {
          if setupVariantsFor(exercise).contains(variant) {
            let rehearsalId = "rehearsal_\(session.id)_\(exercise.id)_\(variant)"
            if let priorRehearsal = existingSetup?.rehearsalConfirmations.first(where: {
              $0.id == rehearsalId
            }) {
              rehearsals.append(priorRehearsal)
            } else {
              let isCore = variant == "supported_knee_raise" || variant == "kneeling_ab_wheel"
              let eqRevision =
                equipmentList.first(where: { $0.id == "eq_\(variant)" })?.revision ?? 0
              let rehearsal = try RehearsalConfirmation(
                id: rehearsalId,
                sourceReference: "manual_log_7d",
                recordedAt: currentNow,
                sessionId: session.id,
                slotId: exercise.id,
                variation: variant,
                easyAndControlled: true,
                symptomsReported: false,
                setupId: "eq_\(variant)",
                setupRevision: eqRevision,
                assistance: variant == "assisted_machine_pull_up" ? 70_000_000 : nil,
                workingRangeRef: isCore ? "full_rom" : nil,
                rehearsalRangeRef: isCore ? "full_rom" : nil,
                withinWorkingRange: isCore ? true : nil
              )
              rehearsals.append(rehearsal)
            }
          }
        }
      }
    }

    let nextRevision = (existingSetup?.revision ?? -1) + 1
    let trainingDays =
      (existingSetup?.trainingDays.isEmpty == false)
      ? existingSetup!.trainingDays : [1, 2, 3, 5, 6]
    let preferredMinutes = existingSetup?.preferredMinutes ?? 60
    let setupDate = max(currentNow, existingSetup?.updatedAt ?? currentNow)

    let calibratedSetup = try TrainingSetup(
      schemaVersion: 2,
      reportedWork: existingSetup?.reportedWork ?? [],
      rehearsalConfirmations: rehearsals,
      programVersion: "owner-program-v2",
      profileId: profileId,
      revision: nextRevision,
      updatedAt: setupDate,
      trainingDays: trainingDays,
      preferredMinutes: preferredMinutes,
      supportedCapabilities: [],
      unsupportedCapabilities: [],
      limitations: [],
      excludedVariations: existingSetup?.excludedVariations ?? [],
      equipment: equipmentList,
      startingLoads: startingLoadsList
    )

    try setupRepository.save(
      calibratedSetup,
      expectedRevision: existingSetup?.revision ?? -1,
      actionId: actionId
    )

    return calibratedSetup
  }
}
