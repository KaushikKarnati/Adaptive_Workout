import Foundation
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class ManualRepositoryTests: XCTestCase {
  var path = ""
  var repo: SqliteProgramLogRepository!
  let helpers = ManualLoggingTests()
  override func setUpWithError() throws {
    path =
      FileManager.default.temporaryDirectory.appendingPathComponent(
        "manual-fixture-\(UUID().uuidString).sqlite"
      ).path
    repo = try SqliteProgramLogRepository(path: path)
  }
  override func tearDownWithError() throws {
    try repo?.close()
    for suffix in ["", "-journal", "-wal", "-shm"] {
      try? FileManager.default.removeItem(atPath: path + suffix)
    }
  }
  func testDurableCorrectionsIdempotencyProfilesAndAuditReopen() throws {
    let initial = helpers.seed()
    try repo.write(initial, expectedRevision: -1, actionId: "start")
    try repo.write(helpers.seed(profile: "other"), expectedRevision: -1, actionId: "start")
    let recorded = try initial.record(helpers.entry())
    try repo.write(recorded, expectedRevision: 0, actionId: "set")
    try repo.write(recorded, expectedRevision: 0, actionId: "set")
    XCTAssertThrowsError(try repo.write(recorded, expectedRevision: 0, actionId: "stale"))
    let corrected = try recorded.record(helpers.entry(reps: 9))
    try repo.write(corrected, expectedRevision: 1, actionId: "correct")
    let identical = try corrected.record(helpers.entry(reps: 9))
    try repo.write(identical, expectedRevision: 2, actionId: "identical")
    try repo.close()
    repo = try SqliteProgramLogRepository(path: path)
    XCTAssertEqual(try repo.load("owner").first, identical)
    XCTAssertEqual(try repo.load("other").first?.sets.count, 0)
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    XCTAssertEqual(try db.rows("SELECT * FROM revisions").count, 3)
    let previous = try XCTUnwrap(
      db.rows("SELECT payload FROM revisions WHERE revision=1").first?["payload"]?.string)
    XCTAssertEqual(try ProgramLog(jsonString: previous).sets.first?.reps, 10)
  }
  func testDartPayloadsAndReceiptsCanRetryWithoutConflicts() throws {
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    let payload = try XCTUnwrap(ManualGoldenFixtures.values["set"])
    let log = try ProgramLog(jsonString: payload)
    try db.execute(
      "INSERT INTO logs(profile,id,revision,completed,payload,prescription) VALUES(?,?,1,0,?,?)",
      [
        .text(log.profile), .text(log.id), .text(payload),
        .text(try XCTUnwrap(ManualGoldenFixtures.values["owner-program-v2_monday"])),
      ])
    try db.execute(
      "INSERT INTO receipts(profile,action,payload) VALUES(?,?,?)",
      [
        .text(log.profile), .text("dart-set"),
        .text(try XCTUnwrap(ManualGoldenFixtures.values["set_receipt"])),
      ])
    XCTAssertEqual(try repo.load("fixture").first?.encodedJSON(), payload)
    try repo.write(log, expectedRevision: 0, actionId: "dart-set")
    let end = try ProgramLog(jsonString: XCTUnwrap(ManualGoldenFixtures.values["early"]))
    try repo.write(end, expectedRevision: 1, actionId: "swift-end")
    XCTAssertEqual(
      try db.rows("SELECT payload FROM receipts WHERE action='swift-end'").first?["payload"]?
        .string,
      ManualGoldenFixtures.values["early_receipt"])
    XCTAssertEqual(
      try repo.load("fixture").first?.encodedJSON(), ManualGoldenFixtures.values["early"])
    if let export = ProcessInfo.processInfo.environment["MANUAL_PARITY_EXPORT"] {
      let payloads = try repo.load("fixture").map { $0.encodedJSON() }
      try ManualJSON.array(payloads.map(ManualJSON.string)).write(
        toFile: export, atomically: true, encoding: .utf8)
    }
  }
  func testReceiptFailureRollsBackAllTablesAndStableRetrySucceeds() throws {
    let initial = helpers.seed()
    try repo.write(initial, expectedRevision: -1, actionId: "start")
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute(
      "CREATE TRIGGER fail_receipt BEFORE INSERT ON receipts BEGIN SELECT RAISE(ABORT, 'fixture'); END"
    )
    let next = try initial.record(helpers.entry())
    XCTAssertThrowsError(try repo.write(next, expectedRevision: 0, actionId: "set"))
    XCTAssertEqual(try repo.load("owner").first?.revision, 0)
    XCTAssertTrue(try db.rows("SELECT * FROM revisions").isEmpty)
    try db.execute("DROP TRIGGER fail_receipt")
    try repo.write(next, expectedRevision: 0, actionId: "set")
    XCTAssertEqual(try repo.load("owner").first?.sets.count, 1)
  }
  func testOneDraftAndFutureSchemaFailWithoutDeletingState() throws {
    let initial = helpers.seed()
    try repo.write(initial, expectedRevision: -1, actionId: "start")
    XCTAssertThrowsError(
      try repo.write(
        helpers.seed("tuesday", id: "second"), expectedRevision: -1, actionId: "second"))
    let db = try SQLiteDatabase(path: path)
    try db.execute("PRAGMA user_version=3")
    try repo.close()
    XCTAssertThrowsError(try SqliteProgramLogRepository(path: path))
    XCTAssertEqual(try db.rows("SELECT * FROM logs").count, 1)
    XCTAssertEqual(try db.rows("PRAGMA user_version").first?["user_version"]?.int, 3)
    try db.close()
  }
  func testFrozenVersionsCoexistAndPrescriptionCorruptionFails() throws {
    let old = helpers.seed("wednesday", version: legacyOwnerProgramVersion, profile: "old")
    let current = helpers.seed("wednesday", profile: "current")
    try repo.write(old, expectedRevision: -1, actionId: "old")
    try repo.write(current, expectedRevision: -1, actionId: "current")
    XCTAssertEqual(try repo.load("old").first?.plan.blocks[0].exercises[0].sets, 2)
    XCTAssertEqual(try repo.load("current").first?.plan.blocks[0].exercises[0].sets, 3)
    var changed = try ManualJSON.decode(old.encodedJSON())
    changed["version"] = ownerProgramVersion
    changed["revision"] = 1
    XCTAssertThrowsError(
      try repo.write(ProgramLog(json: changed), expectedRevision: 0, actionId: "version-change"))
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute("UPDATE logs SET prescription='{}' WHERE profile='old'")
    XCTAssertThrowsError(try repo.load("old"))
    XCTAssertEqual(try repo.load("current").count, 1)
  }
  func testEarlyFinishPreservesSetsAndAllowsNewDraftAndHistoricalCorrection() throws {
    let initial = helpers.seed()
    try repo.write(initial, expectedRevision: -1, actionId: "start")
    let recorded = try initial.record(helpers.entry())
    try repo.write(recorded, expectedRevision: 0, actionId: "set")
    let ended = try recorded.finish(at: initial.startedAt.addingTimeInterval(1), endEarly: true)
    try repo.write(ended, expectedRevision: 1, actionId: "finish")
    try repo.write(ended, expectedRevision: 1, actionId: "finish")
    try repo.write(helpers.seed("friday", id: "next"), expectedRevision: -1, actionId: "next")
    let corrected = try ended.record(helpers.entry(reps: 9))
    try repo.write(corrected, expectedRevision: 2, actionId: "correction")
    let logs = try repo.load("owner")
    XCTAssertEqual(logs.count, 2)
    XCTAssertEqual(logs.filter { !$0.completed }.first?.programId, "friday")
    XCTAssertTrue(try XCTUnwrap(logs.first { $0.id == initial.id }).endedEarly)
    XCTAssertEqual(logs.first { $0.id == initial.id }?.sets.first?.reps, 9)
  }
  func testVersionOneUpgradePreservesBytesAndDeletionLeavesOnlyTombstone() throws {
    let initial = helpers.seed()
    try repo.write(initial, expectedRevision: -1, actionId: "start")
    let recorded = try initial.record(helpers.entry())
    try repo.write(recorded, expectedRevision: 0, actionId: "set")
    try repo.write(helpers.seed(profile: "other"), expectedRevision: -1, actionId: "start")
    try repo.close()
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    let before = try db.rows("SELECT * FROM logs ORDER BY profile")
    try db.execute("DROP TABLE deletions")
    try db.execute("PRAGMA user_version=1")
    repo = try SqliteProgramLogRepository(path: path)
    XCTAssertEqual(try db.rows("SELECT * FROM logs ORDER BY profile"), before)
    XCTAssertEqual(try db.rows("PRAGMA user_version").first?["user_version"]?.int, 2)
    XCTAssertThrowsError(
      try repo.delete("owner", id: initial.id, expectedRevision: 0, actionId: "delete"))
    XCTAssertThrowsError(
      try repo.delete("missing", id: initial.id, expectedRevision: 1, actionId: "delete"))
    XCTAssertThrowsError(
      try repo.delete("owner", id: initial.id, expectedRevision: 1, actionId: "set"))
    try repo.delete("owner", id: initial.id, expectedRevision: 1, actionId: "delete")
    try repo.delete("owner", id: initial.id, expectedRevision: 1, actionId: "delete")
    XCTAssertTrue(try repo.load("owner").isEmpty)
    XCTAssertEqual(try repo.load("other").count, 1)
    XCTAssertTrue(try db.rows("SELECT * FROM revisions WHERE profile='owner'").isEmpty)
    XCTAssertTrue(try db.rows("SELECT * FROM receipts WHERE profile='owner'").isEmpty)
    XCTAssertEqual(
      try db.rows("SELECT * FROM deletions"),
      [
        [
          "profile": .text("owner"), "id": .text(initial.id), "action": .text("delete"),
          "revision": .integer(1),
        ]
      ])
    XCTAssertThrowsError(try repo.write(initial, expectedRevision: -1, actionId: "start"))
    XCTAssertThrowsError(try repo.write(recorded, expectedRevision: 0, actionId: "set"))
    XCTAssertThrowsError(
      try repo.delete("owner", id: initial.id, expectedRevision: 1, actionId: "different-delete"))
  }
  func testDeletionFailureRollsBackReceiptAndAuditRemoval() throws {
    let initial = helpers.seed()
    try repo.write(initial, expectedRevision: -1, actionId: "start")
    let next = try initial.record(helpers.entry())
    try repo.write(next, expectedRevision: 0, actionId: "set")
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute(
      "CREATE TRIGGER reject_delete BEFORE DELETE ON logs BEGIN SELECT RAISE(ABORT, 'fixture'); END"
    )
    XCTAssertThrowsError(
      try repo.delete("owner", id: initial.id, expectedRevision: 1, actionId: "delete"))
    XCTAssertEqual(try repo.load("owner").first, next)
    XCTAssertEqual(try db.rows("SELECT * FROM receipts").count, 2)
    XCTAssertEqual(try db.rows("SELECT * FROM revisions").count, 1)
    XCTAssertTrue(try db.rows("SELECT * FROM deletions").isEmpty)
    try db.execute("DROP TRIGGER reject_delete")
    try repo.delete("owner", id: initial.id, expectedRevision: 1, actionId: "delete")
    XCTAssertTrue(try repo.load("owner").isEmpty)
  }
  func testMalformedReceiptRollsBackDeletionAndCrossProfileReferencesFail() throws {
    let initial = helpers.seed()
    try repo.write(initial, expectedRevision: -1, actionId: "start")
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute("INSERT INTO receipts(profile,action,payload) VALUES('owner','bad','{}')")
    XCTAssertThrowsError(
      try repo.delete("owner", id: initial.id, expectedRevision: 0, actionId: "delete"))
    XCTAssertEqual(try repo.load("owner").count, 1)
    XCTAssertEqual(try db.rows("SELECT * FROM receipts").count, 2)
    try db.execute(
      "UPDATE logs SET payload=? WHERE profile='owner'",
      [.text(helpers.seed(profile: "another").encodedJSON())])
    XCTAssertThrowsError(try repo.load("owner"))
  }
  func testConflictingActionAndMultipleMutationsFailWithoutChangingLog() throws {
    let initial = helpers.seed()
    try repo.write(initial, expectedRevision: -1, actionId: "start")
    let first = try initial.record(helpers.entry())
    XCTAssertThrowsError(try repo.write(first, expectedRevision: 0, actionId: "start"))
    var json = try ManualJSON.decode(first.encodedJSON())
    json["sets"] = [
      try ManualJSON.decode(helpers.entry().encodedJSON()),
      try ManualJSON.decode(helpers.entry(index: 2).encodedJSON()),
    ]
    XCTAssertThrowsError(
      try repo.write(ProgramLog(json: json), expectedRevision: 0, actionId: "two-records"))
    XCTAssertEqual(try repo.load("owner").first, initial)
    XCTAssertThrowsError(try repo.write(first, expectedRevision: -1, actionId: "bad-revision"))
  }
  func testSQLIdentityTamperingDoesNotLoadAsValidHistory() throws {
    try repo.write(helpers.seed(), expectedRevision: -1, actionId: "start")
    let db = try SQLiteDatabase(path: path)
    defer { try? db.close() }
    try db.execute("UPDATE logs SET revision=5")
    XCTAssertThrowsError(try repo.load("owner"))
    try db.execute("UPDATE logs SET revision=0,completed=1")
    XCTAssertThrowsError(try repo.load("owner"))
  }
}
