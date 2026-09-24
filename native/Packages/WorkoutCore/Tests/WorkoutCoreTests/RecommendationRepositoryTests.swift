import Foundation
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class RecommendationRepositoryTests: XCTestCase {
  var path = ""
  var repo: SqliteRecommendationHistoryRepository!
  let fixture = RecommendationHistoryTests()
  override func setUpWithError() throws {
    path =
      FileManager.default.temporaryDirectory.appendingPathComponent(
        "generated-fixture-\(UUID().uuidString).sqlite"
      ).path
    repo = try SqliteRecommendationHistoryRepository(path: path)
  }
  override func tearDownWithError() throws {
    try repo?.close()
    for suffix in ["", "-journal", "-wal", "-shm"] {
      try? FileManager.default.removeItem(atPath: path + suffix)
    }
  }
  func write(_ occurrence: GeneratedOccurrence, action: String) throws {
    let history = try repo.load(occurrence.profile)
    try repo.saveOccurrence(
      occurrence, expectedRevision: occurrence.revision - 1,
      expectedHistoryRevision: history.revision, actionId: action)
  }
  func complete(_ plan: RecommendationSnapshot, sequence: Int) throws -> GeneratedOccurrence {
    try repo.saveRecommendation(plan, actionId: "plan_\(plan.id)")
    var occurrence = try fixture.start(plan, id: "session\(sequence)", sequence: sequence)
    try write(occurrence, action: "start_\(plan.id)")
    for index in 1...2 {
      occurrence = try occurrence.record(
        fixture.actual(index: index), at: occurrence.updatedAt.addingTimeInterval(1),
        prescription: plan)
      try write(occurrence, action: "set_\(plan.id)_\(index)")
    }
    occurrence = try occurrence.finish(
      at: occurrence.updatedAt.addingTimeInterval(1), status: .completed, prescription: plan)
    try write(occurrence, action: "finish_\(plan.id)")
    return occurrence
  }
  func testFrozenVersionsProfileIsolationAndStableReceiptsReopen() throws {
    let plan = try fixture.plan(version: "historical_v0")
    try repo.saveRecommendation(plan, actionId: "plan")
    try repo.saveRecommendation(plan, actionId: "plan")
    try repo.saveRecommendation(fixture.plan(profile: "other"), actionId: "plan")
    let start = try fixture.start(plan)
    try write(start, action: "start")
    try repo.saveOccurrence(
      start, expectedRevision: -1, expectedHistoryRevision: 0, actionId: "start")
    XCTAssertThrowsError(
      try repo.saveOccurrence(
        start, expectedRevision: -1, expectedHistoryRevision: 1, actionId: "start"))
    XCTAssertThrowsError(
      try repo.saveRecommendation(fixture.plan(version: "changed"), actionId: "plan"))
    XCTAssertThrowsError(try repo.saveRecommendation(plan, actionId: "different"))
    try repo.close()
    repo = try SqliteRecommendationHistoryRepository(path: path)
    let history = try repo.load("fixture")
    XCTAssertEqual(history.recommendations, [plan])
    XCTAssertEqual(history.occurrences, [start])
    XCTAssertTrue(try repo.load("other").occurrences.isEmpty)
    XCTAssertEqual(try repo.load("missing").revision, 0)
    XCTAssertEqual(try repo.audit("fixture", occurrenceId: start.id), [start])
    XCTAssertTrue(try repo.audit("fixture", occurrenceId: "missing").isEmpty)
  }
  func testSchemaTwoPersistsBesideUnchangedSchemaOne() throws {
    let old = try fixture.plan(id: "old")
    let new = try RecommendationSnapshot.decode(
      XCTUnwrap(RecommendationGoldenFixtures.values["plan_v2"]))
    try repo.saveRecommendation(old, actionId: "old")
    try repo.saveRecommendation(new, actionId: "new")
    try repo.saveRecommendation(new, actionId: "new")
    try repo.close()
    repo = try SqliteRecommendationHistoryRepository(path: path)
    let history = try repo.load("fixture")
    XCTAssertEqual(history.recommendations.count, 2)
    XCTAssertEqual(history.recommendations.first { $0.id == old.id }?.encode(), old.encode())
    XCTAssertEqual(history.recommendations.first { $0.id == new.id }?.encode(), new.encode())
  }
  func testCorrectionsChangeProgressionAndInvalidateUnstartedPlansOnly() throws {
    let first = try fixture.plan()
    let a = try complete(first, sequence: 0)
    let second = try fixture.plan(
      id: "rec1", history: 4, at: fixture.time.addingTimeInterval(86_400),
      evidence: [a.id: a.revision])
    let b = try complete(second, sequence: 1)
    XCTAssertEqual(try fixture.evaluate(repo.load("fixture")).action, .increase)
    let future = try fixture.plan(
      id: "future", history: 8, at: fixture.time.addingTimeInterval(2 * 86_400),
      evidence: [b.id: b.revision])
    try repo.saveRecommendation(future, actionId: "future")
    let corrected = try b.record(
      fixture.actual(rir: nil), at: b.updatedAt.addingTimeInterval(1), prescription: second)
    try write(corrected, action: "correct")
    let history = try repo.load("fixture")
    XCTAssertEqual(history.revision, 9)
    XCTAssertEqual(try fixture.evaluate(history).action, .hold)
    XCTAssertTrue(history.isStale(future))
    XCTAssertEqual(history.recommendations.first { $0.id == second.id }?.encode(), second.encode())
    XCTAssertThrowsError(
      try write(fixture.start(future, id: "session2", sequence: 2), action: "stale_start"))
    XCTAssertEqual(try repo.audit("fixture", occurrenceId: b.id).count, 5)
    let staleEvidence = try fixture.plan(
      id: "stale_evidence", history: 9, at: future.createdAt, evidence: [b.id: b.revision])
    XCTAssertThrowsError(try repo.saveRecommendation(staleEvidence, actionId: "stale_evidence"))
  }
  func testReceiptFailureRollsBackHistoryAuditAndCurrentState() throws {
    let plan = try fixture.plan()
    try repo.saveRecommendation(plan, actionId: "plan")
    let original = try fixture.start(plan)
    try write(original, action: "start")
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute(
      "CREATE TRIGGER reject_receipt BEFORE INSERT ON receipts BEGIN SELECT RAISE(ABORT, 'fixture'); END"
    )
    let recorded = try original.record(fixture.actual(), at: fixture.time, prescription: plan)
    XCTAssertThrowsError(try write(recorded, action: "set"))
    XCTAssertEqual(try repo.load("fixture").revision, 1)
    XCTAssertEqual(try repo.load("fixture").occurrences, [original])
    XCTAssertTrue(try db.rows("SELECT * FROM revisions").isEmpty)
    try db.execute("DROP TRIGGER reject_receipt")
    try write(recorded, action: "set")
    XCTAssertEqual(try repo.load("fixture").revision, 2)
  }
  func testIncompleteOrCorruptAuditAndRelationalTamperingReject() throws {
    let plan = try fixture.plan()
    let occurrence = try complete(plan, sequence: 0)
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute("UPDATE occurrences SET sequence=7")
    XCTAssertThrowsError(try repo.load("fixture"))
    try db.execute("UPDATE occurrences SET sequence=0")
    XCTAssertEqual(try repo.load("fixture").occurrences, [occurrence])
    try db.execute("DELETE FROM revisions WHERE revision=1")
    XCTAssertThrowsError(try repo.load("fixture"))
    XCTAssertThrowsError(try repo.audit("fixture", occurrenceId: occurrence.id))
  }
  func testFutureSchemaRefusesToOpenAndPreservesRows() throws {
    try repo.saveRecommendation(fixture.plan(), actionId: "plan")
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute("PRAGMA user_version=2")
    try repo.close()
    XCTAssertThrowsError(try SqliteRecommendationHistoryRepository(path: path))
    XCTAssertEqual(try db.rows("SELECT * FROM recommendations").count, 1)
    XCTAssertEqual(try db.rows("PRAGMA user_version").first?["user_version"]?.int, 2)
  }
  func testDartRowsAndReceiptBytesReadThenSwiftMutationsMatchDart() throws {
    let plan = try RecommendationSnapshot.decode(
      XCTUnwrap(RecommendationGoldenFixtures.values["plan_v1"]))
    let start = try GeneratedOccurrence.decode(
      XCTUnwrap(RecommendationGoldenFixtures.values["start"]))
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute("INSERT INTO profiles(id,revision) VALUES('fixture',1)")
    try db.execute(
      "INSERT INTO recommendations(profile,id,payload) VALUES(?,?,?)",
      [.text(plan.profile), .text(plan.id), .text(plan.encode())])
    try db.execute(
      "INSERT INTO occurrences(profile,id,recommendation,sequence,revision,active,payload) VALUES(?,?,?,0,0,1,?)",
      [.text(start.profile), .text(start.id), .text(start.recommendationId), .text(start.encode())])
    try db.execute(
      "INSERT INTO receipts(profile,action,request) VALUES('fixture','plan',?)",
      [.text(try XCTUnwrap(RecommendationGoldenFixtures.values["plan_receipt"]))])
    try db.execute(
      "INSERT INTO receipts(profile,action,request) VALUES('fixture','start',?)",
      [.text(try XCTUnwrap(RecommendationGoldenFixtures.values["start_receipt"]))])
    try repo.saveRecommendation(plan, actionId: "plan")
    try repo.saveOccurrence(
      start, expectedRevision: -1, expectedHistoryRevision: 0, actionId: "start")
    for key in ["recorded", "pain", "corrected", "completed"] {
      let next = try GeneratedOccurrence.decode(XCTUnwrap(RecommendationGoldenFixtures.values[key]))
      try write(next, action: key)
      XCTAssertTrue(
        ManualJSON.bytesEqual(
          try XCTUnwrap(repo.load("fixture").occurrences.first).encode(),
          RecommendationGoldenFixtures.values[key]!))
    }
    XCTAssertEqual(try repo.audit("fixture", occurrenceId: start.id).count, 5)
    if let export = ProcessInfo.processInfo.environment["RECOMMENDATION_PARITY_EXPORT"] {
      let history = try repo.load("fixture")
      let output = ManualJSON.object([
        (
          "recommendations",
          ManualJSON.array(history.recommendations.map { ManualJSON.string($0.encode()) })
        ),
        (
          "occurrences",
          ManualJSON.array(history.occurrences.map { ManualJSON.string($0.encode()) })
        ),
      ])
      try output.write(toFile: export, atomically: true, encoding: .utf8)
    }
  }
  func testStaleHistoryActiveAndSequenceRulesDoNotPartiallySave() throws {
    let first = try fixture.plan()
    let second = try fixture.plan(id: "rec1")
    try repo.saveRecommendation(first, actionId: "first")
    try repo.saveRecommendation(second, actionId: "second")
    try write(fixture.start(first), action: "start")
    XCTAssertThrowsError(
      try repo.saveOccurrence(
        fixture.start(second, id: "another", sequence: 1), expectedRevision: -1,
        expectedHistoryRevision: 1, actionId: "another"))
    let current = try fixture.plan(id: "rec2", history: 1)
    try repo.saveRecommendation(current, actionId: "current")
    XCTAssertThrowsError(
      try write(fixture.start(current, id: "another", sequence: 1), action: "active"))
    let next = try fixture.start(first).record(
      fixture.actual(), at: fixture.time, prescription: first)
    XCTAssertThrowsError(
      try repo.saveOccurrence(
        next, expectedRevision: 0, expectedHistoryRevision: 0, actionId: "stale"))
    XCTAssertEqual(try repo.load("fixture").revision, 1)
    XCTAssertEqual(try repo.load("fixture").occurrences.count, 1)
  }
}
