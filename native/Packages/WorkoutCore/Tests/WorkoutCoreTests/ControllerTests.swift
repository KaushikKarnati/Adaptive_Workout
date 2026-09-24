import Foundation
import WorkoutApplication
import WorkoutDomain
import WorkoutPersistence
import XCTest

private final class UncertainRepository: ProgramLogRepository, @unchecked Sendable {
  private let lock = NSLock()
  private let backing: SqliteProgramLogRepository
  private var failRead = false
  private var failNextAcknowledgement = true
  init() throws { backing = try SqliteProgramLogRepository(path: ":memory:") }
  func load(_ profile: String) throws -> [ProgramLog] {
    lock.lock()
    defer { lock.unlock() }
    if failRead {
      failRead = false
      throw LoggingException("lost_acknowledgement")
    }
    return try backing.load(profile)
  }
  func write(_ log: ProgramLog, expectedRevision: Int, actionId: String) throws {
    lock.lock()
    defer { lock.unlock() }
    try backing.write(log, expectedRevision: expectedRevision, actionId: actionId)
    if failNextAcknowledgement {
      failNextAcknowledgement = false
      failRead = true
    }
  }
  func delete(_ profile: String, id: String, expectedRevision: Int, actionId: String) throws {
    lock.lock()
    defer { lock.unlock() }
    try backing.delete(profile, id: id, expectedRevision: expectedRevision, actionId: actionId)
  }
  func close() throws { try backing.close() }
}
private final class AlteredAcknowledgement: ProgramLogRepository, @unchecked Sendable {
  private let lock = NSLock()
  private let backing = try! SqliteProgramLogRepository(path: ":memory:")
  private var alterNextRead = true
  func load(_ profile: String) throws -> [ProgramLog] {
    lock.lock()
    defer { lock.unlock() }
    let logs = try backing.load(profile)
    guard alterNextRead, let log = logs.first else { return logs }
    alterNextRead = false
    return [
      ProgramLog(
        id: log.id, profile: log.profile, programId: "tuesday", startedAt: log.startedAt,
        revision: log.revision, completedAt: nil, sets: [])
    ]
  }
  func write(_ log: ProgramLog, expectedRevision: Int, actionId: String) throws {
    try backing.write(log, expectedRevision: expectedRevision, actionId: actionId)
  }
  func delete(_ profile: String, id: String, expectedRevision: Int, actionId: String) throws {
    try backing.delete(profile, id: id, expectedRevision: expectedRevision, actionId: actionId)
  }
  func close() throws { try backing.close() }
}
private final class ControlledFailureRepository: ProgramLogRepository, @unchecked Sendable {
  enum Failure { case write, acknowledgement }
  private let lock = NSLock()
  private let backing: SqliteProgramLogRepository
  private var nextFailure: Failure?
  private var failRead = false
  init() throws { backing = try SqliteProgramLogRepository(path: ":memory:") }
  func failNext(_ failure: Failure) {
    lock.lock()
    defer { lock.unlock() }
    nextFailure = failure
  }
  func load(_ profile: String) throws -> [ProgramLog] {
    lock.lock()
    defer { lock.unlock() }
    if failRead {
      failRead = false
      throw LoggingException("lost_acknowledgement")
    }
    return try backing.load(profile)
  }
  private func perform(_ mutation: () throws -> Void) throws {
    lock.lock()
    defer { lock.unlock() }
    let failure = nextFailure
    nextFailure = nil
    if failure == .write { throw LoggingException("write_failed") }
    try mutation()
    failRead = failure == .acknowledgement
  }
  func write(_ log: ProgramLog, expectedRevision: Int, actionId: String) throws {
    try perform { try backing.write(log, expectedRevision: expectedRevision, actionId: actionId) }
  }
  func delete(_ profile: String, id: String, expectedRevision: Int, actionId: String) throws {
    try perform {
      try backing.delete(profile, id: id, expectedRevision: expectedRevision, actionId: actionId)
    }
  }
  func close() throws { try backing.close() }
}
final class ControllerTests: XCTestCase {
  @MainActor func testUnconfirmedSetAndCorrectionExposeExactValuesUntilAcknowledged() async throws {
    let repository = try ControlledFailureRepository()
    let controller = ProgramLogController(repository: repository)
    let started = await controller.start("monday")
    XCTAssertTrue(started)
    let set = ProgramSet(
      slot: "incline_dumbbell_press", index: 1, side: .both, variant: "incline_dumbbell_press",
      setup: "Fixture café · pair A", convention: .perDumbbell, load: 30_123_456,
      reps: 9, rir: nil, validity: .invalid, warmup: true, skipped: false)
    let prior = try XCTUnwrap(controller.selected)
    repository.failNext(.write)
    let saved = await controller.record(set)
    XCTAssertFalse(saved)
    XCTAssertNotNil(controller.error)
    XCTAssertTrue(controller.locked)
    let pending = try XCTUnwrap(controller.pendingChange)
    XCTAssertEqual(pending.kind, .set)
    XCTAssertEqual(pending.submittedSets, [set])
    XCTAssertTrue(
      ManualJSON.bytesEqual(pending.log.encodedJSON(), try prior.record(set).encodedJSON()))
    XCTAssertTrue(controller.selected?.sets.isEmpty == true)
    let recovered = await controller.retry()
    XCTAssertTrue(recovered)
    XCTAssertNil(controller.pendingChange)
    XCTAssertNil(controller.error)
    XCTAssertEqual(controller.selected?.sets, [set])

    let correction = ProgramSet(
      slot: set.slot, index: set.index, side: set.side, variant: set.variant,
      setup: "Fixture cafe\u{0301} · pair B", convention: set.convention, load: 32_654_321,
      reps: 7, rir: 3, validity: .pain, warmup: true, skipped: false)
    repository.failNext(.acknowledgement)
    let corrected = await controller.record(correction)
    XCTAssertFalse(corrected)
    let pendingCorrection = try XCTUnwrap(controller.pendingChange)
    XCTAssertEqual(pendingCorrection.kind, .correction)
    XCTAssertEqual(pendingCorrection.submittedSets, [correction])
    XCTAssertEqual(controller.selected?.sets, [set])
    let correctionPayload = pendingCorrection.log.encodedJSON()
    let acknowledged = await controller.retry()
    XCTAssertTrue(acknowledged)
    XCTAssertNil(controller.pendingChange)
    XCTAssertTrue(
      ManualJSON.bytesEqual(try XCTUnwrap(controller.selected).encodedJSON(), correctionPayload))

    // A correction submitting unchanged values is still inspectable during a failed acknowledgement.
    repository.failNext(.acknowledgement)
    let unchanged = await controller.record(correction)
    XCTAssertFalse(unchanged)
    XCTAssertEqual(controller.pendingChange?.kind, .correction)
    XCTAssertEqual(controller.pendingChange?.submittedSets, [correction])
    let unchangedAcknowledged = await controller.retry()
    XCTAssertTrue(unchangedAcknowledged)
    XCTAssertNil(controller.pendingChange)
  }
  @MainActor func testUnconfirmedLifecycleActionsExposeSnapshotUntilAcknowledged() async throws {
    let repository = try ControlledFailureRepository()
    let controller = ProgramLogController(repository: repository)
    repository.failNext(.write)
    let started = await controller.start("friday")
    XCTAssertFalse(started)
    let pendingStart = try XCTUnwrap(controller.pendingChange)
    XCTAssertEqual(pendingStart.kind, .start)
    XCTAssertEqual(pendingStart.log.programId, "friday")
    XCTAssertTrue(pendingStart.submittedSets.isEmpty)
    XCTAssertNil(controller.selected)
    let recovered = await controller.retry()
    XCTAssertTrue(recovered)
    XCTAssertNil(controller.pendingChange)
    XCTAssertTrue(
      ManualJSON.bytesEqual(
        try XCTUnwrap(controller.selected).encodedJSON(), pendingStart.log.encodedJSON()))

    repository.failNext(.acknowledgement)
    let ended = await controller.finish(endEarly: true)
    XCTAssertFalse(ended)
    let pendingFinish = try XCTUnwrap(controller.pendingChange)
    XCTAssertEqual(pendingFinish.kind, .earlyFinish)
    XCTAssertTrue(pendingFinish.log.endedEarly)
    XCTAssertNotNil(pendingFinish.log.completedAt)
    XCTAssertFalse(try XCTUnwrap(controller.selected).completed)
    let finishRecovered = await controller.retry()
    XCTAssertTrue(finishRecovered)
    XCTAssertNil(controller.pendingChange)
    XCTAssertTrue(
      ManualJSON.bytesEqual(
        try XCTUnwrap(controller.selected).encodedJSON(), pendingFinish.log.encodedJSON()))

    repository.failNext(.acknowledgement)
    let deleted = await controller.delete(try XCTUnwrap(controller.selected))
    XCTAssertFalse(deleted)
    XCTAssertEqual(controller.pendingChange?.kind, .deletion)
    XCTAssertEqual(controller.pendingChange?.log.id, pendingStart.log.id)
    let deleteRecovered = await controller.retry()
    XCTAssertTrue(deleteRecovered)
    XCTAssertNil(controller.pendingChange)
    XCTAssertTrue(controller.logs.isEmpty)
  }
  @MainActor func testAlteredSameRevisionReloadIsNotAcknowledged() async {
    let controller = ProgramLogController(repository: AlteredAcknowledgement())
    let saved = await controller.start("monday")
    XCTAssertFalse(saved)
    XCTAssertTrue(controller.locked)
    let recovered = await controller.retry()
    XCTAssertTrue(recovered)
    XCTAssertEqual(controller.selected?.programId, "monday")
    XCTAssertEqual(controller.logs.count, 1)
  }
  @MainActor func testUncertainCommitRetainsRetryAndBlocksCompetingAction() async throws {
    let repository = try UncertainRepository()
    let controller = ProgramLogController(repository: repository)
    await controller.load()
    let started = await controller.start("monday")
    XCTAssertFalse(started)
    XCTAssertTrue(controller.locked)
    XCTAssertNotNil(controller.error)
    let competing = await controller.start("tuesday")
    XCTAssertFalse(competing)
    let retried = await controller.retry()
    XCTAssertTrue(retried)
    XCTAssertFalse(controller.locked)
    XCTAssertEqual(controller.logs.count, 1)
    XCTAssertEqual(controller.selected?.programId, "monday")
    guard let log = controller.selected else { return XCTFail("Missing acknowledged workout") }
    let finished = await controller.finish(endEarly: true)
    XCTAssertTrue(finished)
    XCTAssertTrue(controller.selected?.endedEarly == true)
    let removed = await controller.delete(controller.selected ?? log)
    XCTAssertTrue(removed)
    XCTAssertTrue(controller.logs.isEmpty)
    XCTAssertNil(controller.selected)
  }
  @MainActor func testInvalidSetDoesNotCreatePendingWrite() async throws {
    let controller = ProgramLogController(
      repository: try SqliteProgramLogRepository(path: ":memory:"))
    let started = await controller.start("monday")
    XCTAssertTrue(started)
    let set = ProgramSet(
      slot: "unknown", index: 1, side: .both, variant: "unknown", setup: "fixture",
      convention: .totalLoad, load: 1, reps: 1, rir: nil, validity: .unknown, warmup: false,
      skipped: false)
    let saved = await controller.record(set)
    XCTAssertFalse(saved)
    XCTAssertFalse(controller.locked)
    XCTAssertEqual(controller.selected?.revision, 0)
  }
}
