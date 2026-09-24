import WorkoutDomain
import WorkoutPersistence
import XCTest

final class ManualLoggingTests: XCTestCase {
  func seed(
    _ day: String = "monday", version: String = ownerProgramVersion, id: String = "session",
    profile: String = "owner"
  ) -> ProgramLog {
    ProgramLog(
      programVersion: version, id: id, profile: profile, programId: day,
      startedAt: Date(timeIntervalSince1970: 1_767_225_600), revision: 0, completedAt: nil, sets: []
    )
  }
  func entry(
    slot: String = "incline_dumbbell_press", index: Int = 1, side: LoggedSide = .both,
    load: Int? = 30_000_000, reps: Int? = 10, rir: Int? = 2, skipped: Bool = false,
    warmup: Bool = false, variant: String? = nil, setup: String = "fixture_machine",
    convention: LoadConvention = .perDumbbell, validity: SetValidity = .valid
  ) -> ProgramSet {
    ProgramSet(
      slot: slot, index: index, side: side, variant: variant ?? slot, setup: setup,
      convention: convention,
      load: load, reps: reps, rir: rir, validity: validity, warmup: warmup, skipped: skipped)
  }
  func filled(_ source: ProgramLog) throws -> ProgramLog {
    var log = source
    for exercise in log.exercises {
      let variant = exercise.alternatives.first ?? exercise.id
      let convention: LoadConvention
      switch variant {
      case "incline_dumbbell_press", "dumbbell_shoulder_press": convention = .perDumbbell
      case "unassisted_pull_up", "hanging_knee_raise", "ab_wheel_rollout": convention = .bodyweight
      case "assisted_machine_pull_up": convention = .assistance
      default: convention = .machineSetting
      }
      for index in 1...exercise.sets {
        for side in exercise.eachSide ? [LoggedSide.left, .right] : [.both] {
          log = try log.record(
            entry(
              slot: exercise.id, index: index, side: side, load: nil, reps: nil, rir: nil,
              skipped: true, variant: variant, convention: convention, validity: .unknown))
        }
      }
    }
    return log
  }
  func assertError(
    _ code: String, _ body: () throws -> Void, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertThrowsError(try body(), file: file, line: line) { error in
      XCTAssertEqual((error as? LoggingException)?.code, code, file: file, line: line)
    }
  }
  func testAllFrozenPrescriptionsMatchDartBytes() throws {
    XCTAssertEqual(
      ownerProgram.map(\.id), ["monday", "tuesday", "wednesday", "friday", "saturday"])
    for version in [legacyOwnerProgramVersion, ownerProgramVersion] {
      for plan in try ownerProgramForVersion(version) {
        let log = seed(plan.id, version: version)
        XCTAssertEqual(log.prescriptionJSON(), ManualGoldenFixtures.values["\(version)_\(plan.id)"])
        XCTAssertTrue(
          plan.blocks.allSatisfy { $0.exercises.allSatisfy { $0.minRir == 2 && $0.maxRir == 3 } })
        XCTAssertEqual(try ProgramLog(jsonString: log.encodedJSON()), log)
      }
    }
    XCTAssertEqual(ownerProgramV1[2].blocks[0].exercises[0].sets, 2)
    XCTAssertEqual(ownerProgram[2].blocks[0].exercises[0].sets, 3)
    assertError("unsupported_program") { _ = try ownerProgramForVersion("future") }
  }
  func testPayloadAndReceiptBytesMatchDartWithExactMicrosecondsAndUnicode() throws {
    for key in ["start", "set", "early"] {
      let payload = try XCTUnwrap(ManualGoldenFixtures.values[key])
      let log = try ProgramLog(jsonString: payload)
      XCTAssertEqual(log.encodedJSON(), payload)
      let receipt = ManualJSON.object([
        ("expected", String(log.revision - 1)), ("payload", ManualJSON.string(log.encodedJSON())),
      ])
      XCTAssertEqual(receipt, ManualGoldenFixtures.values[key + "_receipt"])
      XCTAssertEqual(log.startedTimestamp.encoded, "2026-09-24T12:34:56.123457Z")
    }
    let log = try ProgramLog(jsonString: XCTUnwrap(ManualGoldenFixtures.values["set"]))
    XCTAssertEqual(try log.record(entry()).startedTimestamp.encoded, "2026-09-24T12:34:56.123457Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "2026-09-24T07:34:56.123457-05:00").encoded,
      "2026-09-24T12:34:56.123457Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "1969-12-31T23:59:59.999999Z").encoded,
      "1969-12-31T23:59:59.999999Z")
    XCTAssertEqual(dartISOString(Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000Z")
    XCTAssertThrowsError(try ManualTimestamp(parsing: "2026-09-24T12:34:56"))
  }
  func testLegacyShoulderCannotGainThirdSetOrChangeVersion() throws {
    let legacy = seed("wednesday", version: legacyOwnerProgramVersion)
    let record = entry(slot: "shoulder_press", index: 3, variant: "dumbbell_shoulder_press")
    assertError("invalid_set_identity") { _ = try legacy.record(record) }
    XCTAssertEqual(try seed("wednesday").record(record).sets.count, 1)
    XCTAssertEqual(
      try filled(legacy).finish(at: legacy.startedAt.addingTimeInterval(1)).programVersion,
      legacyOwnerProgramVersion)
  }
  func testCorrectionReplacesOneRecordAndMovesItToEnd() throws {
    let log = try seed().record(entry()).record(entry(index: 2)).record(entry(reps: 9))
    XCTAssertEqual(log.sets.count, 2)
    XCTAssertEqual(log.sets.map(\.index), [2, 1])
    XCTAssertEqual(log.sets.last?.reps, 9)
    XCTAssertEqual(log.revision, 3)
    XCTAssertFalse(log.recommendationEligible)
    XCTAssertEqual(log.exercises.first?.minReps, 6)
  }
  func testEarlyFinishRetainsPartialWorkAndOnlyAllowsCorrections() throws {
    let initial = seed()
    XCTAssertFalse(initial.encodedJSON().contains("endedEarly"))
    let partial = try initial.record(entry())
    assertError("unrecorded_sets") { _ = try partial.finish(at: partial.startedAt) }
    let ended = try partial.finish(at: partial.startedAt, endEarly: true)
    XCTAssertTrue(ended.completed)
    XCTAssertTrue(ended.endedEarly)
    XCTAssertFalse(ended.allWorkingSetsRecorded)
    XCTAssertTrue(try ended.record(entry(reps: 9)).endedEarly)
    XCTAssertEqual(try ended.finish(at: .distantPast), ended)
    assertError("completed_session") { _ = try ended.record(entry(index: 2)) }
    assertError("invalid_completion_time") {
      _ = try partial.finish(at: partial.startedAt.addingTimeInterval(-1), endEarly: true)
    }
    assertError("invalid_early_finish") {
      _ = try ProgramLog(
        jsonString: initial.encodedJSON().replacingOccurrences(
          of: "\"revision\":0", with: "\"endedEarly\":true,\"revision\":0"))
    }
  }
  func testEverySessionCanFinishWithExplicitSkipsAndWarmupsNeverSatisfyWork() throws {
    for day in ownerProgram.map(\.id) {
      let full = try filled(seed(day))
      let finished = try full.finish(at: full.startedAt.addingTimeInterval(1))
      XCTAssertTrue(finished.completed)
      XCTAssertTrue(finished.hasSkips)
      XCTAssertTrue(finished.allWorkingSetsRecorded)
      XCTAssertFalse(finished.recommendationEligible)
    }
    let warm = try seed().record(entry(warmup: true))
    XCTAssertFalse(warm.allWorkingSetsRecorded)
    assertError("unrecorded_sets") { _ = try warm.finish(at: warm.startedAt) }
    XCTAssertEqual(try seed().record(entry(index: 100, warmup: true)).sets.count, 1)
    assertError("invalid_set_identity") { _ = try seed().record(entry(index: 101, warmup: true)) }
  }
  func testUnilateralIdentityAndPainStop() throws {
    let friday = seed("friday")
    assertError("invalid_set_identity") {
      _ = try friday.record(entry(slot: "single_arm_cable_pulldown", convention: .machineSetting))
    }
    let left = try friday.record(
      entry(slot: "single_arm_cable_pulldown", side: .left, convention: .machineSetting))
    let both = try left.record(
      entry(slot: "single_arm_cable_pulldown", side: .right, convention: .machineSetting))
    XCTAssertEqual(both.sets.count, 2)
    XCTAssertEqual(try filled(friday).sets.count, 21)
    let pain = try seed().record(entry(validity: .pain))
    assertError("exercise_stopped") { _ = try pain.record(entry(index: 2)) }
    XCTAssertEqual(
      try pain.record(
        entry(index: 2, load: nil, reps: nil, rir: nil, skipped: true, validity: .unknown)
      ).sets.count, 2)
    XCTAssertEqual(try pain.record(entry(reps: 8, validity: .pain)).sets.first?.reps, 8)
  }
  func testActualAndIdentityBoundsMissingDataAndUTF16SetupLimit() throws {
    for record in [
      entry(load: -1), entry(load: 1_000_000_000_001), entry(load: nil), entry(reps: nil),
      entry(reps: -1),
      entry(reps: 10_001), entry(rir: -1), entry(rir: 10_001), entry(index: 0), entry(index: 4),
      entry(setup: " "), entry(setup: String(repeating: "x", count: 121)),
      entry(setup: String(repeating: "😀", count: 61)),
      entry(variant: "unknown"), entry(slot: "unknown"), entry(skipped: true), entry(side: .left),
    ] {
      XCTAssertThrowsError(try seed().record(record))
    }
    XCTAssertEqual(try seed().record(entry(load: 0, reps: 0, rir: nil)).sets.first?.load, 0)
    XCTAssertEqual(
      try seed().record(entry(load: 1_000_000_000_000, reps: 10_000, rir: 10_000)).sets.count, 1)
    XCTAssertEqual(try seed().record(entry(setup: String(repeating: "😀", count: 60))).sets.count, 1)
  }
  func testLoadConventionsAreNeverInterchangeable() throws {
    for convention in LoadConvention.allCases where convention != .perDumbbell {
      XCTAssertThrowsError(try seed().record(entry(convention: convention)))
    }
    let friday = seed("friday")
    XCTAssertEqual(
      try friday.record(
        entry(slot: "pull_up", load: nil, variant: "unassisted_pull_up", convention: .bodyweight)
      ).sets.count, 1)
    XCTAssertEqual(
      try friday.record(
        entry(slot: "pull_up", variant: "assisted_machine_pull_up", convention: .assistance)
      ).sets.count, 1)
    XCTAssertThrowsError(
      try friday.record(
        entry(slot: "pull_up", variant: "assisted_machine_pull_up", convention: .machineSetting)))
    XCTAssertThrowsError(
      try friday.record(
        entry(slot: "pull_up", variant: "unassisted_pull_up", convention: .bodyweight)))
    XCTAssertThrowsError(
      try seed().record(
        entry(load: nil, reps: nil, rir: nil, skipped: true, variant: "unknown", validity: .unknown)
      ))
  }
  func testMalformedStoredSessionsFailClosed() throws {
    let good = try seed().record(entry())
    let original = try ManualJSON.decode(good.encodedJSON())
    for (key, value) in [
      ("version", "future" as Any), ("programId", "unknown"), ("revision", -1), ("revision", true),
      (
        "sets",
        [
          try ManualJSON.decode(entry().encodedJSON()),
          try ManualJSON.decode(entry().encodedJSON()),
        ]
      ),
      ("startedAt", "2026-01-01T00:00:00.000"), ("completedAt", "2025-01-01T00:00:00.000Z"),
    ] {
      var bad = original
      bad[key] = value
      XCTAssertThrowsError(try ProgramLog(json: bad))
    }
    var json = try ManualJSON.decode(entry().encodedJSON())
    json["load"] = 1.5
    XCTAssertThrowsError(try ProgramSet(json: json))
    json["load"] = true
    XCTAssertThrowsError(try ProgramSet(json: json))
  }
  func testProlepticGregorianTimestampBoundsAndOverflowNormalization() throws {
    let yearOne = try ManualTimestamp(parsing: "0001-01-01T00:00:00.000Z")
    XCTAssertEqual(yearOne.microsecondsSince1970, -62_135_596_800_000_000)
    XCTAssertEqual(yearOne.encoded, "0001-01-01T00:00:00.000Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "0000-01-01T00:00:00.000Z").encoded, "0000-01-01T00:00:00.000Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "1582-10-10T00:00:00.123457Z").encoded,
      "1582-10-10T00:00:00.123457Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "1900-02-29T00:00:00.000Z").encoded, "1900-03-01T00:00:00.000Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "2000-02-29T00:00:00.000Z").encoded, "2000-02-29T00:00:00.000Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "2026-13-01T24:00:00.000Z").encoded, "2027-01-02T00:00:00.000Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "-0001-12-31T23:59:59.999999Z").encoded,
      "-0001-12-31T23:59:59.999999Z")
    XCTAssertEqual(
      try ManualTimestamp(parsing: "+275760-09-13T00:00:00.000Z").microsecondsSince1970,
      8_640_000_000_000_000_000)
    XCTAssertEqual(
      try ManualTimestamp(parsing: "-271821-04-20T00:00:00.000Z").microsecondsSince1970,
      -8_640_000_000_000_000_000)
    XCTAssertThrowsError(try ManualTimestamp(parsing: "+275760-09-13T00:00:00.000001Z"))
    XCTAssertThrowsError(try ManualTimestamp(parsing: "+999999-01-01T00:00:00.000Z"))
  }
  func testUnicodeNormalizationDoesNotMergeDistinctManualSetupIdentity() throws {
    let composed = entry(setup: "caf\u{00e9}")
    let decomposed = entry(setup: "cafe\u{0301}")
    XCTAssertNotEqual(composed, decomposed)
    let a = try seed(id: "a").record(composed).finish(at: seed().startedAt, endEarly: true)
    let b = try seed(id: "b").record(decomposed).finish(at: seed().startedAt, endEarly: true)
    XCTAssertEqual(exerciseHistory([a, b]).count, 2)
  }
  func testExactDecimalLoadsAndStorageIDs() throws {
    XCTAssertEqual(try parsePounds(" 30.123456 "), 30_123_456)
    XCTAssertEqual(try parsePounds("1000000"), 1_000_000_000_000)
    XCTAssertEqual(formatPounds(30_123_456), "30.123456")
    XCTAssertEqual(formatPounds(30_000_000), "30")
    XCTAssertEqual(formatPounds(25_100_000), "25.1")
    for value in ["", "1.", ".5", "1.0000001", "-1", "1e3", "1000000.000001", "NaN", "30,5", "１２"] {
      XCTAssertThrowsError(try parsePounds(value))
    }
    for id in ["", "space here", String(repeating: "a", count: 129), "😀", "a\n"] {
      XCTAssertThrowsError(try validateStorageId(id))
    }
    try validateStorageId("id_A-Z_123")
  }
  func testHistoryFilteringAndComparableSeries() throws {
    let first = try seed(id: "a").record(entry()).finish(at: seed().startedAt, endEarly: true)
    let second = try seed(id: "b").record(entry(reps: 9)).record(entry(index: 2, warmup: true))
      .finish(at: seed().startedAt, endEarly: true)
    let other = try seed(id: "c", profile: "other").finish(at: seed().startedAt, endEarly: true)
    let draft = seed(id: "draft")
    XCTAssertEqual(
      filterWorkoutHistory(
        [first, other, second, draft], profile: "owner", query: "monday fixture"
      ).map(\.id), ["a", "b"])
    XCTAssertTrue(
      filterWorkoutHistory([first], profile: "owner", since: first.startedAt.addingTimeInterval(1))
        .isEmpty)
    let series = exerciseHistory([first, second, draft])
    XCTAssertEqual(series.count, 1)
    XCTAssertEqual(series[0].points.map { $0.set.reps }, [10, 9])
    let different = try seed(id: "different").record(entry(setup: "different")).finish(
      at: first.startedAt, endEarly: true)
    let invalid = try seed(id: "invalid").record(entry(validity: .invalid)).finish(
      at: first.startedAt, endEarly: true)
    XCTAssertEqual(exerciseHistory([first, different, invalid]).count, 2)
    let old = try seed(version: legacyOwnerProgramVersion, id: "old").record(entry()).finish(
      at: first.startedAt, endEarly: true)
    XCTAssertEqual(exerciseHistory([first, old]).count, 2)
  }
}
