import WorkoutDomain
import WorkoutPersistence
import XCTest

final class SettingsRepositoryTests: XCTestCase {
  private func path() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "settings-fixture-\(UUID().uuidString).sqlite"
    ).path
  }
  private func fixture(_ key: String = "setup1") throws -> TrainingSetup {
    try TrainingSetup.decode(XCTUnwrap(SettingsGoldenFixtures.values[key]))
  }
  private func next(_ old: TrainingSetup, revision: Int? = nil, minutes: Int = 75) throws
    -> TrainingSetup
  {
    try TrainingSetup(
      schemaVersion: old.schemaVersion, reportedWork: old.reportedWork,
      rehearsalConfirmations: old.rehearsalConfirmations, programVersion: old.programVersion,
      profileId: old.profileId, revision: revision ?? old.revision + 1, updatedAt: old.updatedAt,
      trainingDays: old.trainingDays, preferredMinutes: minutes,
      supportedCapabilities: old.supportedCapabilities,
      unsupportedCapabilities: old.unsupportedCapabilities, limitations: old.limitations,
      excludedVariations: old.excludedVariations, equipment: old.equipment,
      startingLoads: old.startingLoads)
  }
  func testSetupReceiptsRevisionReopenAndProfileIsolation() throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let first = try fixture()
    let repo = try SqliteTrainingSetupRepository(path: path)
    try repo.save(first, expectedRevision: -1, actionId: "start")
    try repo.save(first, expectedRevision: -1, actionId: "start")
    let db = try SQLiteDatabase(path: path)
    XCTAssertEqual(
      try db.rows("SELECT request FROM receipts").first?["request"]?.string,
      SettingsGoldenFixtures.values["setupReceipt"])
    let updated = try next(first)
    try repo.save(updated, expectedRevision: 0, actionId: "update")
    XCTAssertThrowsError(
      try repo.save(next(first, minutes: 80), expectedRevision: 0, actionId: "update"))
    XCTAssertThrowsError(
      try repo.save(next(first, minutes: 80), expectedRevision: 0, actionId: "stale"))
    XCTAssertEqual(
      try db.rows("SELECT payload FROM revisions").first?["payload"]?.string, first.encode())
    XCTAssertEqual(try db.rows("SELECT * FROM receipts").count, 2)
    XCTAssertNil(try repo.load("another_profile"))
    try repo.close()
    try db.close()
    let reopened = try SqliteTrainingSetupRepository(path: path)
    XCTAssertEqual(try reopened.load("synthetic")?.encode(), updated.encode())
    try reopened.close()
  }
  func testSetupMalformedIdentityFutureSchemaAndAtomicRollback() throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try SqliteTrainingSetupRepository(path: path)
    let db = try SQLiteDatabase(path: path)
    let first = try fixture()
    try db.execute(
      "CREATE TRIGGER fail_receipt BEFORE INSERT ON receipts BEGIN SELECT RAISE(ABORT,'fixture'); END"
    )
    XCTAssertThrowsError(try repo.save(first, expectedRevision: -1, actionId: "start"))
    XCTAssertNil(try repo.load("synthetic"))
    XCTAssertEqual(try db.rows("SELECT * FROM profiles").count, 0)
    try db.execute("DROP TRIGGER fail_receipt")
    try repo.save(first, expectedRevision: -1, actionId: "start")
    try db.execute("UPDATE profiles SET revision=42")
    XCTAssertThrowsError(try repo.load("synthetic"))
    try db.execute("PRAGMA user_version=9")
    try repo.close()
    try db.close()
    XCTAssertThrowsError(try SqliteTrainingSetupRepository(path: path))
    let check = try SQLiteDatabase(path: path)
    XCTAssertEqual(try check.rows("SELECT * FROM profiles").count, 1)
    try check.close()
  }
  func testSetupSchemaTwoEvidenceCannotBeDiscarded() throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try SqliteTrainingSetupRepository(path: path)
    let first = try fixture("setup2")
    try repo.save(first, expectedRevision: -1, actionId: "start")
    try repo.save(next(first), expectedRevision: 0, actionId: "preferences")
    XCTAssertEqual(try repo.load("synthetic")?.reportedWork.count, 1)
    let empty = try TrainingSetup(
      profileId: "synthetic", revision: 2, updatedAt: first.updatedAt, trainingDays: [],
      preferredMinutes: nil, supportedCapabilities: nil, unsupportedCapabilities: nil,
      limitations: nil, excludedVariations: [], equipment: [], startingLoads: [])
    XCTAssertThrowsError(try repo.save(empty, expectedRevision: 1, actionId: "discard"))
    XCTAssertEqual(try repo.load("synthetic")?.revision, 1)
    try repo.close()
  }
  func testGymCompareAndSaveRetriesSwitchesAndCorruption() throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try SqliteGymProfileRepository(path: path)
    let empty = try repo.load()
    let first = try GymProfiles.decode(XCTUnwrap(SettingsGoldenFixtures.values["gym"]))
    try repo.save(first, expected: empty)
    try repo.save(first, expected: empty)
    let other = try first.select(
      GymProfile(id: "another", name: "Another gym", address: "", equipment: []))
    try repo.save(other, expected: first)
    XCTAssertEqual(try repo.load().profiles.count, 2)
    XCTAssertEqual(try repo.load().selected?.equipment.count, 0)
    XCTAssertThrowsError(try repo.save(GymProfiles(profiles: []), expected: first))
    try repo.close()
    let reopened = try SqliteGymProfileRepository(path: path)
    XCTAssertEqual(try reopened.load().encode(), other.encode())
    let db = try SQLiteDatabase(path: path)
    try db.execute("UPDATE gym_profiles SET payload='{}'")
    XCTAssertThrowsError(try reopened.load())
    try reopened.close()
    try db.close()
  }
  func testPracticeDartReceiptsSafeRetryCorrectionCompletionAndReopen() throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try SqlitePracticeRepository(path: path)
    let at = try dartDate("2026-09-23T12:34:56.123456Z")
    let record = try PracticeSet.decode(XCTUnwrap(SettingsGoldenFixtures.values["practiceSet"]))
    try repo.start(profileId: "fixture", sessionId: "session", actionId: "start", at: at)
    try repo.start(profileId: "fixture", sessionId: "session", actionId: "start", at: at)
    XCTAssertThrowsError(
      try repo.start(profileId: "fixture", sessionId: "second", actionId: "second", at: at))
    try repo.saveSet(
      profileId: "fixture", sessionId: "session", actionId: "set", expectedRevision: 0,
      record: record, correction: false, at: at)
    try repo.saveSet(
      profileId: "fixture", sessionId: "session", actionId: "set", expectedRevision: 0,
      record: record, correction: false, at: at)
    let db = try SQLiteDatabase(path: path)
    XCTAssertEqual(
      try db.rows("SELECT payload FROM actions WHERE id='start'").first?["payload"]?.string,
      SettingsGoldenFixtures.values["practiceStart"])
    XCTAssertEqual(
      try db.rows("SELECT payload FROM actions WHERE id='set'").first?["payload"]?.string,
      SettingsGoldenFixtures.values["practiceReceipt"])
    let correction = try PracticeSet(
      id: record.id, exerciseId: record.exerciseId, index: record.index,
      microPounds: record.microPounds, reps: 9, rir: 2, working: true, validity: .valid)
    XCTAssertThrowsError(
      try repo.saveSet(
        profileId: "fixture", sessionId: "session", actionId: "stale", expectedRevision: 0,
        record: correction, correction: true, at: at))
    try repo.saveSet(
      profileId: "fixture", sessionId: "session", actionId: "correct", expectedRevision: 1,
      record: correction, correction: true, at: at)
    try repo.complete(
      profileId: "fixture", sessionId: "session", actionId: "finish", expectedRevision: 2, at: at)
    try repo.complete(
      profileId: "fixture", sessionId: "session", actionId: "finish_again", expectedRevision: 2,
      at: at)
    XCTAssertEqual(
      try db.rows("SELECT prior_payload FROM set_revisions").first?["prior_payload"]?.string,
      record.canonicalJSON)
    XCTAssertTrue(try repo.load("unrelated").isEmpty)
    try repo.close()
    try db.close()
    let reopened = try SqlitePracticeRepository(path: path)
    let session = try XCTUnwrap(reopened.load("fixture").first)
    XCTAssertTrue(session.isPractice)
    XCTAssertTrue(session.completed)
    XCTAssertEqual(session.revision, 3)
    XCTAssertEqual(session.sets, [correction])
    try reopened.close()
  }
  func testPracticeUnrepresentableDatesAndOverflowRevisionsCannotCommit() throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try SqlitePracticeRepository(path: path)
    XCTAssertThrowsError(
      try repository.start(
        profileId: "fixture", sessionId: "session", actionId: "start",
        at: Date(timeIntervalSince1970: 1e20)))
    XCTAssertTrue(try repository.load("fixture").isEmpty)
    let at = Date(timeIntervalSince1970: 1_790_000_000)
    try repository.start(profileId: "fixture", sessionId: "session", actionId: "start", at: at)
    let record = try PracticeSet.decode(XCTUnwrap(SettingsGoldenFixtures.values["practiceSet"]))
    XCTAssertThrowsError(
      try repository.saveSet(
        profileId: "fixture", sessionId: "session", actionId: "overflow", expectedRevision: Int.max,
        record: record, correction: false, at: at))
    XCTAssertThrowsError(
      try repository.complete(
        profileId: "fixture", sessionId: "session", actionId: "overflow", expectedRevision: Int.max,
        at: at))
    XCTAssertEqual(try repository.load("fixture").first?.revision, 0)
    try repository.close()
  }
  func testPracticeRollbackAndRelationalIdentityTampering() throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try SqlitePracticeRepository(path: path)
    let db = try SQLiteDatabase(path: path)
    let at = Date(timeIntervalSince1970: 1_790_000_000)
    try db.execute(
      "CREATE TRIGGER fail_receipt BEFORE INSERT ON actions BEGIN SELECT RAISE(ABORT,'fixture'); END"
    )
    XCTAssertThrowsError(
      try repo.start(profileId: "fixture", sessionId: "session", actionId: "start", at: at))
    XCTAssertTrue(try repo.load("fixture").isEmpty)
    try db.execute("DROP TRIGGER fail_receipt")
    try repo.start(profileId: "fixture", sessionId: "session", actionId: "start", at: at)
    let record = try PracticeSet.decode(XCTUnwrap(SettingsGoldenFixtures.values["practiceSet"]))
    try repo.saveSet(
      profileId: "fixture", sessionId: "session", actionId: "set", expectedRevision: 0,
      record: record, correction: false, at: at)
    try db.execute("UPDATE set_records SET set_index=9")
    XCTAssertThrowsError(try repo.load("fixture"))
    try repo.close()
    try db.close()
  }
}
