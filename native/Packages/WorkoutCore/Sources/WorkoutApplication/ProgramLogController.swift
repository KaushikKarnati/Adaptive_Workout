import Combine
import Foundation
import WorkoutDomain

/// A read-only view of the exact action retained until storage acknowledges it.
public struct PendingProgramLogChange: Sendable {
  public enum Kind: Equatable, Sendable {
    case start, set, correction, finish, earlyFinish, deletion
  }
  public let kind: Kind
  public let log: ProgramLog
  public let submittedSets: [ProgramSet]
}

@MainActor
public final class ProgramLogController: ObservableObject {
  private let repository: any ProgramLogRepository
  public let profile: String
  @Published public private(set) var logs: [ProgramLog] = []
  @Published public private(set) var selectedID: String?
  @Published public private(set) var error: String?
  @Published public private(set) var busy = false
  private var pending: ProgramLog?
  private var pendingDelete: ProgramLog?
  private var action: String?
  public var locked: Bool { busy || pending != nil || pendingDelete != nil }
  public var selected: ProgramLog? { logs.first { $0.id == selectedID } }
  public var draft: ProgramLog? { logs.first { !$0.completed } }
  public var pendingChange: PendingProgramLogChange? {
    if let pendingDelete {
      return PendingProgramLogChange(kind: .deletion, log: pendingDelete, submittedSets: [])
    }
    guard let pending else { return nil }
    guard let previous = logs.first(where: { $0.id == pending.id }) else {
      return PendingProgramLogChange(kind: .start, log: pending, submittedSets: [])
    }
    if !previous.completed && pending.completed {
      return PendingProgramLogChange(
        kind: pending.endedEarly ? .earlyFinish : .finish, log: pending, submittedSets: [])
    }
    let changed = pending.sets.filter { !previous.sets.contains($0) }
    // An identical correction still needs acknowledgement. record() puts the
    // submitted set last, preserving its identity even when its values match.
    let submitted = changed.isEmpty ? Array(pending.sets.suffix(1)) : changed
    let correction = submitted.contains { set in previous.sets.contains { $0.key == set.key } }
    return PendingProgramLogChange(
      kind: correction ? .correction : .set, log: pending, submittedSets: submitted)
  }
  public init(repository: any ProgramLogRepository, profile: String = "local_owner") {
    self.repository = repository
    self.profile = profile
  }
  private func identity() -> String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }
  public func load() async {
    guard !locked else { return }
    busy = true
    error = nil
    defer { busy = false }
    do {
      let repository = repository
      let profile = profile
      logs = try await Task.detached { try repository.load(profile) }.value
      if selectedID == nil { selectedID = draft?.id }
    } catch { self.error = "Could not open workouts. Try again." }
  }
  public func select(_ id: String?) {
    guard !locked else { return }
    selectedID = id
  }
  @discardableResult public func start(_ programID: String) async -> Bool {
    guard !locked else { return false }
    if let draft {
      select(draft.id)
      return true
    }
    let log = ProgramLog(
      id: identity(), profile: profile, programId: programID,
      startedAt: Date(), revision: 0, completedAt: nil, sets: [])
    return await save(log)
  }
  @discardableResult public func record(_ set: ProgramSet) async -> Bool {
    guard !locked, let selected else { return false }
    do { return await save(try selected.record(set)) } catch {
      self.error =
        "Check your entries. Pain stops further sets for that exercise; remaining sets can be skipped."
      return false
    }
  }
  @discardableResult public func finish(endEarly: Bool = false) async -> Bool {
    guard !locked, let selected else { return false }
    if selected.completed { return true }
    do { return await save(try selected.finish(at: Date(), endEarly: endEarly)) } catch {
      self.error = "Record or explicitly skip each working set before finishing, or finish early."
      return false
    }
  }
  @discardableResult public func delete(_ log: ProgramLog) async -> Bool {
    guard !locked, log.profile == profile else { return false }
    pendingDelete = log
    action = identity()
    return await retry()
  }
  private func save(_ log: ProgramLog) async -> Bool {
    guard !locked else { return false }
    pending = log
    action = identity()
    return await retry()
  }
  @discardableResult public func retry() async -> Bool {
    guard !busy, let action, pending != nil || pendingDelete != nil else { return false }
    busy = true
    error = nil
    defer { busy = false }
    do {
      let repository = repository
      let profile = profile
      if let deleted = pendingDelete {
        let updated = try await Task.detached {
          try repository.delete(
            profile, id: deleted.id, expectedRevision: deleted.revision, actionId: action)
          return try repository.load(profile)
        }.value
        guard !updated.contains(where: { $0.id == deleted.id }) else {
          throw ControllerFailure.unconfirmed
        }
        logs = updated
        if selectedID == deleted.id { selectedID = nil }
        pendingDelete = nil
      } else if let pending {
        let updated = try await Task.detached {
          try repository.write(pending, expectedRevision: pending.revision - 1, actionId: action)
          return try repository.load(profile)
        }.value
        guard
          updated.contains(where: {
            $0.id == pending.id && ManualJSON.bytesEqual($0.encodedJSON(), pending.encodedJSON())
          })
        else {
          throw ControllerFailure.unconfirmed
        }
        let justFinished =
          pending.completed && logs.contains { $0.id == pending.id && !$0.completed }
        logs = updated
        selectedID = justFinished ? nil : pending.id
        self.pending = nil
      }
      self.action = nil
      return true
    } catch {
      self.error =
        pendingDelete != nil
        ? "Deletion not confirmed. Retry safely."
        : "Save not confirmed. Your entries are kept. Retry safely."
      return false
    }
  }
}
private enum ControllerFailure: Error { case unconfirmed }
