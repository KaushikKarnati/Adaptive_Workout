import Foundation

public enum ReportedLoadScope: String, Codable, Sendable {
  case perHand, stackDisplay, eachStack, totalAddedPlates, bodyweight
}
public struct ReportedWorkingSetup: Equatable, Sendable {
  public let id: String, sourceReference: String, sessionId: String, slotId: String,
    variation: String, convention: SetupLoadConvention, load: Int?, sets: Int, minReps: Int?,
    maxReps: Int?, minRir: Int?, maxRir: Int?, eachSide: Bool, loadIncrement: Int?,
    loadScope: ReportedLoadScope?
  var recordedStamp: ManualTimestamp
  public var recordedAt: Date { recordedStamp.date }
  public var recommendationEligible: Bool { false }
  public init(
    id: String, sourceReference: String, recordedAt: Date, sessionId: String, slotId: String,
    variation: String, convention: SetupLoadConvention, load: Int?, sets: Int, minReps: Int?,
    maxReps: Int?, minRir: Int?, maxRir: Int?, eachSide: Bool, loadIncrement: Int? = nil,
    loadScope: ReportedLoadScope? = nil
  ) throws {
    self.id = id
    self.sourceReference = sourceReference
    self.recordedStamp = ManualTimestamp(recordedAt)
    self.sessionId = sessionId
    self.slotId = slotId
    self.variation = variation
    self.convention = convention
    self.load = load
    self.sets = sets
    self.minReps = minReps
    self.maxReps = maxReps
    self.minRir = minRir
    self.maxRir = maxRir
    self.eachSide = eachSide
    self.loadIncrement = loadIncrement
    self.loadScope = loadScope
    try validateSetupId(id)
    try validateSetupId(sourceReference)
    try setupDate(recordedAt)
    try validateSetupSlot(sessionId, slotId, variation)
    try requireSetup(
      setupConventionsFor(variation).contains(convention), "invalid_variation_convention")
    try requireSetup(convention == .bodyweight ? load == nil : load != nil, "invalid_reported_load")
    if let loadScope {
      let permitted: Bool
      switch convention {
      case .perDumbbell: permitted = loadScope == .perHand
      case .platesOnly: permitted = loadScope == .totalAddedPlates
      case .bodyweight: permitted = loadScope == .bodyweight
      case .machineSetting, .assistance:
        permitted = [.stackDisplay, .eachStack].contains(loadScope)
      default: permitted = false
      }
      try requireSetup(permitted, "invalid_load_scope")
    }
    for v in [load, loadIncrement].compactMap({ $0 }) {
      try requireSetup((1...1_000_000_000_000).contains(v), "invalid_intake_number")
    }
    try requireSetup(convention != .bodyweight || loadIncrement == nil, "bodyweight_has_load")
    try requireSetup((1...1000).contains(sets), "invalid_intake_number")
    try requireSetup((minReps == nil) == (maxReps == nil), "invalid_reported_reps")
    if let low = minReps, let high = maxReps {
      try requireSetup(
        (1...10000).contains(low) && high >= low && high <= 10000, "invalid_intake_number")
    }
    try requireSetup((minRir == nil) == (maxRir == nil), "invalid_reported_effort")
    if let low = minRir, let high = maxRir {
      try requireSetup(
        (0...10000).contains(low) && high >= low && high <= 10000, "invalid_intake_number")
    }
  }
}
public struct RehearsalConfirmation: Equatable, Sendable {
  public let id: String, sourceReference: String, sessionId: String, slotId: String,
    variation: String, easyAndControlled: Bool?, symptomsReported: Bool?, setupId: String?,
    setupRevision: Int?, assistance: Int?, workingRangeRef: String?, rehearsalRangeRef: String?,
    withinWorkingRange: Bool?
  var recordedStamp: ManualTimestamp
  public var recordedAt: Date { recordedStamp.date }
  public init(
    id: String, sourceReference: String, recordedAt: Date, sessionId: String, slotId: String,
    variation: String, easyAndControlled: Bool?, symptomsReported: Bool?, setupId: String? = nil,
    setupRevision: Int? = nil, assistance: Int? = nil, workingRangeRef: String? = nil,
    rehearsalRangeRef: String? = nil, withinWorkingRange: Bool? = nil
  ) throws {
    self.id = id
    self.sourceReference = sourceReference
    self.recordedStamp = ManualTimestamp(recordedAt)
    self.sessionId = sessionId
    self.slotId = slotId
    self.variation = variation
    self.easyAndControlled = easyAndControlled
    self.symptomsReported = symptomsReported
    self.setupId = setupId
    self.setupRevision = setupRevision
    self.assistance = assistance
    self.workingRangeRef = workingRangeRef
    self.rehearsalRangeRef = rehearsalRangeRef
    self.withinWorkingRange = withinWorkingRange
    try validateSetupId(id)
    try validateSetupId(sourceReference)
    try setupDate(recordedAt)
    try validateSetupSlot(sessionId, slotId, variation)
    try requireSetup(
      [
        "assisted_machine_pull_up", "unassisted_pull_up", "supported_knee_raise",
        "kneeling_ab_wheel",
      ].contains(variation), "unsupported_rehearsal")
    try requireSetup((setupId == nil) == (setupRevision == nil), "incomplete_setup_reference")
    if let setupId {
      try validateSetupId(setupId)
      try requireSetup((0...2_147_483_647).contains(setupRevision!), "invalid_intake_number")
    }
    if let assistance {
      try requireSetup((1...1_000_000_000_000).contains(assistance), "invalid_intake_number")
    }
    for range in [workingRangeRef, rehearsalRangeRef].compactMap({ $0 }) {
      try validateSetupId(range)
    }
    if variation != "assisted_machine_pull_up" {
      try requireSetup(assistance == nil, "invalid_assistance")
    }
    if ["assisted_machine_pull_up", "unassisted_pull_up"].contains(variation) {
      try requireSetup(
        workingRangeRef == nil && rehearsalRangeRef == nil && withinWorkingRange == nil,
        "invalid_rehearsal_range")
    }
    try requireSetup(
      withinWorkingRange != true || (workingRangeRef != nil && rehearsalRangeRef != nil),
      "range_required")
  }
  public var hasCompleteAttestation: Bool {
    guard easyAndControlled == true, symptomsReported == false, setupId != nil else { return false }
    switch variation {
    case "assisted_machine_pull_up": return assistance != nil
    case "unassisted_pull_up": return true
    case "supported_knee_raise":
      return withinWorkingRange == true && workingRangeRef == rehearsalRangeRef
    default: return withinWorkingRange == true
    }
  }
}
