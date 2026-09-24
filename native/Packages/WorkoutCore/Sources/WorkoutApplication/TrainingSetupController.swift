import Combine
import Foundation
import WorkoutDomain

/// Coordinates immutable setup aggregates and keeps failed write intent intact.
/// Reports and attestations are appended without manufacturing equipment or baselines.
@MainActor public final class TrainingSetupController: ObservableObject {
  private let repository: any TrainingSetupRepository
  public let profileId: String
  private let now: () -> Date
  private let newId: () -> String
  @Published public private(set) var saved: TrainingSetup?
  @Published public private(set) var error: String?
  @Published public private(set) var loaded = false
  @Published public private(set) var busy = false
  private var pending: TrainingSetup?
  private var actionId: String?
  public var locked: Bool { busy || pending != nil }
  public var canRetry: Bool { !busy && pending != nil }
  public init(
    repository: any TrainingSetupRepository, profileId: String = "local_owner",
    now: @escaping () -> Date = Date.init, newId: @escaping () -> String = { UUID().uuidString }
  ) {
    self.repository = repository
    self.profileId = profileId
    self.now = now
    self.newId = newId
  }
  public func load() {
    guard !locked else { return }
    busy = true
    error = nil
    defer { busy = false }
    do {
      saved = try repository.load(profileId)
      loaded = true
    } catch { self.error = "Could not open setup. Try again." }
  }
  private func next(
    at: Date, days: [Int]? = nil, minutes: Int? = nil, exclusions: [String]? = nil,
    equipment: [EquipmentSetup]? = nil, loads: [StartingLoad]? = nil,
    reports: [ReportedWorkingSetup]? = nil, rehearsals: [RehearsalConfirmation]? = nil
  ) throws -> TrainingSetup {
    try TrainingSetup(
      schemaVersion: reports != nil || rehearsals != nil ? 2 : saved?.schemaVersion ?? 1,
      reportedWork: reports ?? saved?.reportedWork ?? [],
      rehearsalConfirmations: rehearsals ?? saved?.rehearsalConfirmations ?? [],
      profileId: profileId, revision: (saved?.revision ?? -1) + 1, updatedAt: at,
      trainingDays: days ?? saved?.trainingDays ?? [],
      preferredMinutes: minutes ?? saved?.preferredMinutes,
      supportedCapabilities: saved?.supportedCapabilities,
      unsupportedCapabilities: saved?.unsupportedCapabilities, limitations: saved?.limitations,
      excludedVariations: exclusions ?? saved?.excludedVariations ?? [],
      equipment: equipment ?? saved?.equipment ?? [],
      startingLoads: loads ?? saved?.startingLoads ?? [])
  }
  @discardableResult public func saveIntake(
    reports: [ReportedWorkingSetup] = [], rehearsals: [RehearsalConfirmation] = []
  ) -> Bool {
    guard !locked, loaded else { return false }
    do {
      try requireSetup(!reports.isEmpty || !rehearsals.isEmpty, "empty_intake")
      return try save(
        next(
          at: now(), reports: (saved?.reportedWork ?? []) + reports,
          rehearsals: (saved?.rehearsalConfirmations ?? []) + rehearsals))
    } catch { return invalid() }
  }
  @discardableResult public func savePreferences(days: [Int], minutes: String, exclusions: [String])
    -> Bool
  {
    guard !locked, loaded else { return false }
    do {
      let text = minutes.trimmingCharacters(in: .whitespacesAndNewlines)
      guard text.range(of: "^[0-9]+$", options: .regularExpression) != nil, let value = Int(text)
      else { throw SetupException("invalid_duration") }
      return try save(next(at: now(), days: days, minutes: value, exclusions: exclusions))
    } catch { return invalid() }
  }
  @discardableResult public func saveMachine(
    existingId: String? = nil, label: String, sessionId: String, slotId: String, variation: String,
    convention: SetupLoadConvention, workingSettings: String, rehearsalSettings: String,
    startingWeight: String, confirmed: Bool, equipmentId: String? = nil, quantity: Int = 1,
    capabilities: [String] = []
  ) -> Bool {
    guard !locked, loaded else { return false }
    do {
      let at = now()
      let previous = saved?.equipment.first { $0.id == existingId }
      try requireSetup(existingId == nil || previous != nil, "unknown_setup")
      func settings(_ value: String) throws -> [Int] {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? []
          : try value.split(separator: ",", omittingEmptySubsequences: false).map {
            try parsePounds(String($0))
          }
      }
      let machine = try EquipmentSetup(
        id: existingId ?? newId(), revision: previous.map { $0.revision + 1 } ?? 0,
        label: label.trimmingCharacters(in: .whitespacesAndNewlines), variation: variation,
        equipmentId: equipmentId, quantity: quantity, capabilities: capabilities,
        convention: convention, workingLoads: settings(workingSettings),
        rehearsalLoads: settings(rehearsalSettings), confirmedAt: confirmed ? at : nil)
      let equipment = (saved?.equipment.filter { $0.id != machine.id } ?? []) + [machine]
      var loads = saved?.startingLoads ?? []
      if confirmed {
        let prior = loads.first {
          $0.setupId == machine.id && $0.sessionId == sessionId && $0.slotId == slotId
            && $0.variation == variation
        }
        let baseline = try StartingLoad(
          id: prior?.id ?? newId(), sessionId: sessionId, slotId: slotId, variation: variation,
          setupId: machine.id, setupRevision: machine.revision, convention: convention,
          microPounds: convention == .bodyweight ? nil : parsePounds(startingWeight),
          confirmedAt: at)
        loads.removeAll { $0.id == baseline.id }
        loads.append(baseline)
      } else {
        try requireSetup(
          startingWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          "confirm_starting_load_first")
      }
      return try save(next(at: at, equipment: equipment, loads: loads))
    } catch { return invalid() }
  }
  private func invalid() -> Bool {
    error =
      "Check your entries. Use exact pounds, unique settings and an explicit confirmation for a starting load."
    return false
  }
  private func save(_ next: TrainingSetup) throws -> Bool {
    try validateSetupTransition(saved, next)
    pending = next
    actionId = newId()
    return retry()
  }
  @discardableResult public func retry() -> Bool {
    guard !busy, let pending, let actionId else { return false }
    busy = true
    error = nil
    defer { busy = false }
    do {
      try repository.save(pending, expectedRevision: pending.revision - 1, actionId: actionId)
      let result = try repository.load(profileId)
      try requireSetup(result != nil && result!.revision >= pending.revision, "save_not_confirmed")
      saved = result
      self.pending = nil
      self.actionId = nil
      return true
    } catch {
      self.error = "Save not confirmed. Your entries are kept. Retry safely."
      return false
    }
  }
}
