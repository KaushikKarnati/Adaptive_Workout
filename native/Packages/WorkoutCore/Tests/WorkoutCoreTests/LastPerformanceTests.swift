import WorkoutDomain
import XCTest

final class LastPerformanceTests: XCTestCase {
  let base = Date(timeIntervalSince1970: 1_767_225_600)
  func log(
    _ id: String, day: Int, program: String = "monday", profile: String = "owner",
    version: String = ownerProgramVersion
  ) -> ProgramLog {
    ProgramLog(
      programVersion: version, id: id, profile: profile, programId: program,
      startedAt: base.addingTimeInterval(Double(day) * 86_400), revision: 0, completedAt: nil,
      sets: [])
  }
  func set(
    _ index: Int, reps: Int? = 10, load: Int? = 30_000_000, setup: String = "bench_a",
    warmup: Bool = false, skipped: Bool = false, validity: SetValidity = .valid
  ) -> ProgramSet {
    ProgramSet(
      slot: "incline_dumbbell_press", index: index, side: .both,
      variant: "incline_dumbbell_press", setup: setup, convention: .perDumbbell,
      load: skipped ? nil : load, reps: skipped ? nil : reps, rir: skipped ? nil : 2,
      validity: skipped ? .unknown : validity, warmup: warmup, skipped: skipped)
  }
  func finished(_ source: ProgramLog, _ sets: [ProgramSet]) throws -> ProgramLog {
    try sets.reduce(source) { try $0.record($1) }.finish(at: source.startedAt, endEarly: true)
  }
  func lookup(_ logs: [ProgramLog], _ current: ProgramLog) -> LastPerformance? {
    lastPerformance(logs, current: current, slot: "incline_dumbbell_press", side: .both)
  }

  func testMostRecentEarlierFinishedWorkoutInSetOrder() throws {
    let older = try finished(log("older", day: 0), [set(1, reps: 12)])
    let recent = try finished(log("recent", day: 2), [set(2, reps: 9), set(1, reps: 11)])
    let later = try finished(log("later", day: 9), [set(1, reps: 5)])
    let draft = try log("draft", day: 3).record(set(1, reps: 7))
    let today = log("today", day: 5)
    let result = try XCTUnwrap(lookup([older, later, recent, draft, today], today))
    XCTAssertEqual(result.log.id, "recent")
    XCTAssertEqual(result.sets.map(\.reps), [11, 9])
    XCTAssertFalse(result.matchesCurrentSetup)
  }

  func testExcludesWarmupsSkipsInvalidPainAndEmptySetups() throws {
    let noisy = try finished(
      log("noisy", day: 1),
      [
        set(1, warmup: true), set(1, skipped: true), set(2, validity: .invalid),
        set(3, validity: .pain),
      ])
    let unknownSetup = try finished(log("unknown", day: 2), [set(1, setup: "")])
    XCTAssertNil(lookup([noisy, unknownSetup], log("today", day: 5)))
  }

  func testMatchesTheSetupAlreadyRecordedToday() throws {
    let benchA = try finished(log("a", day: 1), [set(1, reps: 12, setup: "bench_a")])
    let benchB = try finished(log("b", day: 2), [set(1, reps: 8, setup: "bench_b")])
    let today = try log("today", day: 5).record(set(1, reps: 10, setup: "bench_a"))
    let result = try XCTUnwrap(lookup([benchA, benchB], today))
    XCTAssertEqual(result.log.id, "a")
    XCTAssertTrue(result.matchesCurrentSetup)
    XCTAssertNil(lookup([benchB], today))
  }

  func testWithoutTodaysSetupShowsOnlyTheFirstSetOfOneSetup() throws {
    let mixed = try finished(
      log("mixed", day: 1),
      [set(1, reps: 12, setup: "bench_a"), set(2, reps: 8, setup: "bench_b"), set(3, reps: 10)])
    let result = try XCTUnwrap(lookup([mixed], log("today", day: 5)))
    XCTAssertEqual(result.sets.map(\.index), [1, 3])
  }

  func testScopedToProfileSessionAndProgramVersion() throws {
    let otherProfile = try finished(log("p", day: 1, profile: "other"), [set(1)])
    let legacy = try finished(log("v", day: 1, version: legacyOwnerProgramVersion), [set(1)])
    XCTAssertNil(lookup([otherProfile, legacy], log("today", day: 5)))
    XCTAssertNil(lookup([], log("today", day: 5)))
  }
}
