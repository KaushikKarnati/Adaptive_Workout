import Foundation

public struct SetupException: Error, Equatable, CustomStringConvertible {
  public let code: String
  public init(_ code: String) { self.code = code }
  public var description: String { code }
}
public func requireSetup(_ valid: Bool, _ code: String) throws {
  if !valid { throw SetupException(code) }
}
public func validateSetupId(_ value: String) throws {
  try requireSetup(
    value.range(of: "^[a-zA-Z0-9_-]{1,128}$", options: .regularExpression) != nil, "invalid_id")
}
func setupUnique<T: Hashable>(_ values: [T], _ maximum: Int) throws {
  try requireSetup(
    values.count <= maximum && Set(values).count == values.count, "duplicate_or_excess_values")
}
func setupDate(_ value: Date) throws {
  try requireSetup(
    value.timeIntervalSince1970.isFinite && value >= Date(timeIntervalSince1970: -62_135_596_800)
      && value < Date(timeIntervalSince1970: 253_402_300_800), "invalid_time")
}
public func validateGymText(_ value: String, maximum: Int, allowEmpty: Bool = false) throws {
  try requireSetup(
    value == value.trimmingCharacters(in: .whitespacesAndNewlines) && (allowEmpty || !value.isEmpty)
      && value.utf16.count <= maximum
      && value.range(
        of: "[\\x{0000}-\\x{001f}\\x{007f}-\\x{009f}\\x{202a}-\\x{202e}\\x{2066}-\\x{2069}<>]",
        options: .regularExpression) == nil,
    "invalid_gym_text")
}
public enum SetupLoadConvention: String, Codable, CaseIterable, Sendable {
  case perDumbbell, machineSetting, platesOnly, totalExternal, assistance, bodyweight
  public var label: String {
    switch self {
    case .perDumbbell: return "Pounds per dumbbell"
    case .machineSetting: return "Displayed machine pounds"
    case .platesOnly: return "Added plates only, pounds"
    case .totalExternal: return "Total external pounds"
    case .assistance: return "Machine assistance, pounds"
    case .bodyweight: return "Bodyweight (no numeric load)"
    }
  }
}
public let setupVariationNames: [String: String] = [
  "incline_dumbbell_press": "Incline dumbbell press",
  "neutral_grip_lat_pulldown": "Neutral-grip lat pulldown",
  "incline_machine_press": "Incline machine press", "chest_supported_row": "Chest-supported row",
  "cable_lateral_raise": "Cable lateral raise", "cable_chest_fly": "Cable chest fly",
  "leg_press": "Leg press", "leg_extension": "Leg extension", "seated_leg_curl": "Seated leg curl",
  "lying_leg_curl": "Lying leg curl", "machine_calf_raise": "Machine calf raise",
  "cable_crunch": "Cable crunch", "machine_shoulder_press": "Seated machine shoulder press",
  "dumbbell_shoulder_press": "Seated dumbbell shoulder press",
  "reverse_pec_deck": "Reverse pec deck", "cable_curl": "Cable curl",
  "overhead_cable_triceps_extension": "Overhead cable triceps extension",
  "supported_knee_raise": "Supported captain’s-chair knee raise",
  "unassisted_pull_up": "Unassisted pull-up",
  "assisted_machine_pull_up": "Machine-assisted pull-up", "seated_cable_row": "Seated cable row",
  "single_arm_cable_pulldown": "Single-arm cable pulldown",
  "machine_chest_fly": "Machine chest fly", "hack_squat": "Hack squat",
  "kneeling_ab_wheel": "Kneeling ab-wheel rollout",
]
public func setupVariantsFor(_ exercise: ProgramExercise) -> [String] {
  switch exercise.id {
  case "seated_leg_curl", "leg_curl": return ["seated_leg_curl", "lying_leg_curl"]
  case "hanging_knee_raise": return ["supported_knee_raise"]
  case "ab_wheel_rollout": return ["kneeling_ab_wheel"]
  default: return exercise.alternatives.isEmpty ? [exercise.id] : exercise.alternatives
  }
}
public func setupConventionsFor(_ variant: String) -> [SetupLoadConvention] {
  switch variant {
  case "unassisted_pull_up", "supported_knee_raise", "kneeling_ab_wheel": return [.bodyweight]
  case "assisted_machine_pull_up": return [.assistance]
  case "incline_dumbbell_press", "dumbbell_shoulder_press": return [.perDumbbell]
  case "chest_supported_row": return [.machineSetting, .platesOnly, .totalExternal, .perDumbbell]
  default:
    return setupVariationNames[variant] == nil
      ? [] : [.machineSetting, .platesOnly, .totalExternal]
  }
}
public enum SetupTaxonomy {
  public static let equipmentIds = ExerciseCatalogValidator.equipmentIds
  public static let equipmentCapabilityIds = ExerciseCatalogValidator.equipmentCapabilityIds
  public static let functionalCapabilityIds = ExerciseCatalogValidator.functionalCapabilityIds
  public static let limitationConflictIds = ExerciseCatalogValidator.limitationConflictIds
}
func validateSetupSlot(_ sessionId: String, _ slotId: String, _ variation: String) throws {
  let slot = ownerProgram.first { $0.id == sessionId }?.blocks.flatMap(\.exercises).first {
    $0.id == slotId
  }
  try requireSetup(
    slot.map { setupVariantsFor($0).contains(variation) } == true, "invalid_slot_variation")
}
public struct EquipmentSetup: Equatable, Sendable {
  public let id: String, revision: Int, label: String, variation: String, equipmentId: String?,
    quantity: Int
  public let capabilities: [String], convention: SetupLoadConvention, workingLoads: [Int],
    rehearsalLoads: [Int]
  var confirmedStamp: ManualTimestamp?
  public var confirmedAt: Date? { confirmedStamp?.date }
  public var confirmed: Bool { confirmedAt != nil }
  public var recommendationEligible: Bool { false }
  public init(
    id: String, revision: Int, label: String, variation: String, equipmentId: String?,
    quantity: Int, capabilities: [String], convention: SetupLoadConvention, workingLoads: [Int],
    rehearsalLoads: [Int], confirmedAt: Date?
  ) throws {
    self.id = id
    self.revision = revision
    self.label = label
    self.variation = variation
    self.equipmentId = equipmentId
    self.quantity = quantity
    self.capabilities = capabilities
    self.convention = convention
    self.workingLoads = workingLoads
    self.rehearsalLoads = rehearsalLoads
    self.confirmedStamp = confirmedAt.map(ManualTimestamp.init)
    try validateSetupId(id)
    try requireSetup((0...2_147_483_647).contains(revision), "invalid_revision")
    try validateGymText(label, maximum: 120)
    try requireSetup(
      setupConventionsFor(variation).contains(convention), "invalid_variation_convention")
    try requireSetup(
      equipmentId == nil || SetupTaxonomy.equipmentIds.contains(equipmentId!), "unknown_equipment")
    try setupUnique(capabilities, 8)
    try setupUnique(workingLoads, 1000)
    try setupUnique(rehearsalLoads, 1000)
    try requireSetup(
      (1...8).contains(quantity)
        && capabilities.allSatisfy(SetupTaxonomy.equipmentCapabilityIds.contains),
      "invalid_equipment")
    try requireSetup(
      workingLoads.allSatisfy { (1...1_000_000_000_000).contains($0) }
        && rehearsalLoads.allSatisfy { (0...1_000_000_000_000).contains($0) }, "invalid_settings")
    if convention == .bodyweight {
      try requireSetup(workingLoads.isEmpty && rehearsalLoads.isEmpty, "bodyweight_has_load")
    } else if confirmed {
      try requireSetup(!workingLoads.isEmpty, "working_settings_required")
    }
    if convention == .assistance {
      try requireSetup(!rehearsalLoads.contains(0), "invalid_assistance")
    }
    if let confirmedAt { try setupDate(confirmedAt) }
  }
}
public struct StartingLoad: Equatable, Sendable {
  public let id: String, sessionId: String, slotId: String, variation: String, setupId: String,
    setupRevision: Int, convention: SetupLoadConvention, microPounds: Int?
  var confirmedStamp: ManualTimestamp
  public var confirmedAt: Date { confirmedStamp.date }
  public var recommendationEligible: Bool { false }
  public init(
    id: String, sessionId: String, slotId: String, variation: String, setupId: String,
    setupRevision: Int, convention: SetupLoadConvention, microPounds: Int?, confirmedAt: Date
  ) throws {
    self.id = id
    self.sessionId = sessionId
    self.slotId = slotId
    self.variation = variation
    self.setupId = setupId
    self.setupRevision = setupRevision
    self.convention = convention
    self.microPounds = microPounds
    self.confirmedStamp = ManualTimestamp(confirmedAt)
    try validateSetupId(id)
    try validateSetupId(setupId)
    try setupDate(confirmedAt)
    try requireSetup((0...2_147_483_647).contains(setupRevision), "invalid_setup_revision")
    try validateSetupSlot(sessionId, slotId, variation)
    try requireSetup(setupConventionsFor(variation).contains(convention), "invalid_slot_variation")
    try requireSetup(
      convention == .bodyweight
        ? microPounds == nil : microPounds.map { (1...1_000_000_000_000).contains($0) } == true,
      "invalid_starting_load")
  }
}
public struct TrainingSetup: Equatable, Sendable {
  public let schemaVersion: Int, reportedWork: [ReportedWorkingSetup],
    rehearsalConfirmations: [RehearsalConfirmation], programVersion: String, profileId: String,
    revision: Int, trainingDays: [Int], preferredMinutes: Int?
  public let supportedCapabilities: [String]?, unsupportedCapabilities: [String]?,
    limitations: [String]?, excludedVariations: [String], equipment: [EquipmentSetup],
    startingLoads: [StartingLoad]
  var updatedStamp: ManualTimestamp
  public var updatedAt: Date { updatedStamp.date }
  public var recommendationEligible: Bool { false }
  public func baselineIsCurrent(_ baseline: StartingLoad) -> Bool {
    startingLoads.contains(baseline)
      && equipment.contains {
        $0.id == baseline.setupId && $0.revision == baseline.setupRevision && $0.confirmed
      }
  }
  public init(
    schemaVersion: Int = 1, reportedWork: [ReportedWorkingSetup] = [],
    rehearsalConfirmations: [RehearsalConfirmation] = [],
    programVersion: String = "owner-program-v2", profileId: String, revision: Int, updatedAt: Date,
    trainingDays: [Int], preferredMinutes: Int?, supportedCapabilities: [String]?,
    unsupportedCapabilities: [String]?, limitations: [String]?, excludedVariations: [String],
    equipment: [EquipmentSetup], startingLoads: [StartingLoad],
    exactUpdatedAt: ManualTimestamp? = nil
  ) throws {
    self.schemaVersion = schemaVersion
    self.reportedWork = reportedWork
    self.rehearsalConfirmations = rehearsalConfirmations
    self.programVersion = programVersion
    self.profileId = profileId
    self.revision = revision
    self.updatedStamp = exactUpdatedAt ?? ManualTimestamp(updatedAt)
    self.trainingDays = trainingDays
    self.preferredMinutes = preferredMinutes
    self.supportedCapabilities = supportedCapabilities
    self.unsupportedCapabilities = unsupportedCapabilities
    self.limitations = limitations
    self.excludedVariations = excludedVariations
    self.equipment = equipment
    self.startingLoads = startingLoads
    try requireSetup([1, 2].contains(schemaVersion), "unsupported_setup_version")
    try requireSetup(
      schemaVersion == 2 || (reportedWork.isEmpty && rehearsalConfirmations.isEmpty),
      "schema_two_required")
    try setupUnique(reportedWork.map(\.id), 500)
    try setupUnique(rehearsalConfirmations.map(\.id), 500)
    try requireSetup(
      (reportedWork.map(\.recordedAt) + rehearsalConfirmations.map(\.recordedAt)).allSatisfy {
        $0 <= updatedAt
      }, "future_intake")
    for r in rehearsalConfirmations where r.setupId != nil {
      try requireSetup(
        equipment.contains {
          $0.id == r.setupId && $0.variation == r.variation && r.setupRevision! <= $0.revision
        }, "invalid_rehearsal_reference")
    }
    try requireSetup(
      ["owner-program-v1", "owner-program-v2"].contains(programVersion), "unsupported_program")
    try validateSetupId(profileId)
    if let exactUpdatedAt {
      try requireSetup(
        exactUpdatedAt.date == updatedAt
          && (-62_135_596_800_000_000...253_402_300_799_999_999).contains(
            exactUpdatedAt.microsecondsSince1970),
        "invalid_time")
    } else {
      try setupDate(updatedAt)
    }
    try requireSetup((0...2_147_483_647).contains(revision), "invalid_revision")
    try setupUnique(trainingDays, 7)
    try setupUnique(excludedVariations, 25)
    try requireSetup(
      trainingDays.allSatisfy { (1...7).contains($0) }
        && (preferredMinutes.map { (1...2_147_483_647).contains($0) } ?? true),
      "invalid_preferences")
    for values in [supportedCapabilities, unsupportedCapabilities] {
      if let values {
        try setupUnique(values, 32)
        try requireSetup(
          values.allSatisfy(SetupTaxonomy.functionalCapabilityIds.contains), "unknown_taxonomy_id")
      }
    }
    if let limitations {
      try setupUnique(limitations, 32)
      try requireSetup(
        limitations.allSatisfy(SetupTaxonomy.limitationConflictIds.contains), "unknown_taxonomy_id")
    }
    try requireSetup(
      (supportedCapabilities == nil) == (unsupportedCapabilities == nil)
        && Set(supportedCapabilities ?? []).isDisjoint(with: unsupportedCapabilities ?? []),
      "invalid_capabilities")
    try requireSetup(
      excludedVariations.allSatisfy { setupVariationNames[$0] != nil }, "unknown_exclusion")
    try setupUnique(equipment.map(\.id), 100)
    try setupUnique(startingLoads.map(\.id), 500)
    try setupUnique(
      startingLoads.map { "\($0.sessionId)/\($0.slotId)/\($0.variation)/\($0.setupId)" }, 500)
    try requireSetup(
      equipment.allSatisfy { $0.confirmedAt.map { $0 <= updatedAt } ?? true }, "future_confirmation"
    )
    for b in startingLoads {
      guard let e = equipment.first(where: { $0.id == b.setupId }) else {
        throw SetupException("invalid_baseline_reference")
      }
      try requireSetup(
        e.variation == b.variation && e.convention == b.convention && b.setupRevision <= e.revision
          && b.confirmedAt <= updatedAt, "invalid_baseline_reference")
      if b.setupRevision == e.revision {
        try requireSetup(
          e.confirmed && b.confirmedAt >= e.confirmedAt!
            && (b.microPounds.map(e.workingLoads.contains) ?? true), "unverified_baseline")
      }
    }
  }
  func validateExactChronology() throws {
    try requireSetup(
      (reportedWork.map(\.recordedStamp) + rehearsalConfirmations.map(\.recordedStamp)).allSatisfy {
        $0 <= updatedStamp
      }, "future_intake")
    try requireSetup(
      equipment.allSatisfy { $0.confirmedStamp.map { $0 <= updatedStamp } ?? true },
      "future_confirmation")
    for baseline in startingLoads {
      try requireSetup(baseline.confirmedStamp <= updatedStamp, "invalid_baseline_reference")
      if let setup = equipment.first(where: { $0.id == baseline.setupId }),
        setup.revision == baseline.setupRevision, let confirmation = setup.confirmedStamp
      {
        try requireSetup(baseline.confirmedStamp >= confirmation, "unverified_baseline")
      }
    }
  }

}
public protocol TrainingSetupRepository {
  func load(_ profileId: String) throws -> TrainingSetup?
  func save(_ setup: TrainingSetup, expectedRevision: Int, actionId: String) throws
}
public func validateSetupTransition(_ old: TrainingSetup?, _ next: TrainingSetup) throws {
  try requireSetup(
    old.map {
      next.profileId == $0.profileId && next.revision == $0.revision + 1
        && next.updatedStamp >= $0.updatedStamp
    } ?? (next.revision == 0), "invalid_transition")
  try requireSetup(old.map { next.schemaVersion >= $0.schemaVersion } ?? true, "schema_downgrade")
  for prior in old?.reportedWork ?? [] {
    try requireSetup(next.reportedWork.contains(prior), "intake_history_changed")
  }
  for prior in old?.rehearsalConfirmations ?? [] {
    try requireSetup(next.rehearsalConfirmations.contains(prior), "intake_history_changed")
  }
  for r in next.rehearsalConfirmations
  where !(old?.rehearsalConfirmations.contains { $0.id == r.id } ?? false) {
    if let id = r.setupId {
      guard let e = next.equipment.first(where: { $0.id == id }) else {
        throw SetupException("invalid_rehearsal_reference")
      }
      try requireSetup(
        e.confirmed && r.setupRevision == e.revision && r.recordedStamp >= e.confirmedStamp!,
        "stale_rehearsal_confirmation")
    }
  }
  for prior in old?.equipment ?? [] {
    try requireSetup(next.equipment.contains { $0.id == prior.id }, "setup_removal_unsupported")
  }
  for entry in next.equipment {
    if let prior = old?.equipment.first(where: { $0.id == entry.id }) {
      if !ManualJSON.bytesEqual(entry.canonicalJSON, prior.canonicalJSON) {
        try requireSetup(
          entry.revision == prior.revision + 1 && entry.variation == prior.variation
            && entry.convention == prior.convention, "invalid_setup_change")
        try requireSetup(
          entry.confirmedStamp.map { $0 >= old!.updatedStamp } ?? true, "stale_confirmation")
      }
    } else {
      try requireSetup(entry.revision == 0, "invalid_setup_revision")
    }
  }
  for prior in old?.startingLoads ?? [] {
    try requireSetup(
      next.startingLoads.contains { $0.id == prior.id }, "baseline_removal_unsupported")
  }
  for entry in next.startingLoads {
    let prior = old?.startingLoads.first { $0.id == entry.id }
    if prior.map({ !ManualJSON.bytesEqual($0.canonicalJSON, entry.canonicalJSON) }) ?? true {
      try requireSetup(next.baselineIsCurrent(entry), "stale_baseline_confirmation")
      try requireSetup(
        old.map { entry.confirmedStamp >= $0.updatedStamp } ?? true, "stale_confirmation")
      if let prior {
        try requireSetup(
          entry.sessionId == prior.sessionId && entry.slotId == prior.slotId
            && entry.variation == prior.variation && entry.setupId == prior.setupId,
          "baseline_context_changed")
      }
    }
  }
}
