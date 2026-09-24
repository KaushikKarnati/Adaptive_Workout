import Foundation

public struct LoggingException: Error, Equatable, Sendable, LocalizedError {
  public let code: String
  public init(_ code: String) { self.code = code }
  public init(code: String) { self.code = code }
  public var errorDescription: String? { code }
}

public enum SetValidity: String, CaseIterable, Codable, Sendable {
  case unknown, valid, invalid, pain
}
public enum LoadConvention: String, CaseIterable, Codable, Sendable {
  case perDumbbell, machineSetting, platesOnly, totalLoad, assistance, bodyweight
}
public enum LoggedSide: String, CaseIterable, Codable, Sendable { case both, left, right }

public func validateStorageId(_ id: String) throws {
  guard !id.isEmpty, id.utf8.count <= 128,
    id.utf8.allSatisfy({
      (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95
        || $0 == 45
    })
  else {
    throw LoggingException("invalid_id")
  }
}

/// Decimal input is parsed exactly into micro-pounds, never through floating point.
public func parsePounds(_ text: String) throws -> Int {
  let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
  let pieces = trimmed.split(separator: ".", omittingEmptySubsequences: false)
  guard (1...2).contains(pieces.count), (1...7).contains(pieces[0].count),
    pieces.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy({ (48...57).contains($0) }) }),
    pieces.count == 1 || (1...6).contains(pieces[1].count), let whole = Int(pieces[0])
  else {
    throw LoggingException("invalid_load")
  }
  let fractional = pieces.count == 1 ? "" : String(pieces[1])
  let fraction = Int(fractional + String(repeating: "0", count: 6 - fractional.count)) ?? 0
  let result = whole * 1_000_000 + fraction
  guard result <= 1_000_000_000_000 else { throw LoggingException("invalid_load") }
  return result
}
public func formatPounds(_ value: Int) -> String {
  let whole = value / 1_000_000
  var fractional = String(format: "%06d", value % 1_000_000)
  while fractional.last == "0" { fractional.removeLast() }
  return fractional.isEmpty ? String(whole) : "\(whole).\(fractional)"
}

public struct ProgramSet: Equatable, Sendable, Identifiable {
  public static func == (lhs: ProgramSet, rhs: ProgramSet) -> Bool {
    ManualJSON.bytesEqual(lhs.encodedJSON(), rhs.encodedJSON())
  }
  public let slot: String
  public let index: Int
  public let side: LoggedSide
  public let variant: String
  public let setup: String
  public let convention: LoadConvention
  public let load: Int?
  public let reps: Int?
  public let rir: Int?
  public let validity: SetValidity
  public let warmup: Bool
  public let skipped: Bool
  public var key: String { "\(slot)_\(warmup ? "warmup" : "work")_\(index)_\(side.rawValue)" }
  public var id: String { key }
  public init(
    slot: String, index: Int, side: LoggedSide, variant: String, setup: String,
    convention: LoadConvention, load: Int?, reps: Int?, rir: Int?, validity: SetValidity,
    warmup: Bool, skipped: Bool
  ) {
    self.slot = slot
    self.index = index
    self.side = side
    self.variant = variant
    self.setup = setup
    self.convention = convention
    self.load = load
    self.reps = reps
    self.rir = rir
    self.validity = validity
    self.warmup = warmup
    self.skipped = skipped
  }
  public func encodedJSON() -> String {
    ManualJSON.object([
      ("slot", ManualJSON.string(slot)), ("index", String(index)),
      ("side", ManualJSON.string(side.rawValue)),
      ("variant", ManualJSON.string(variant)), ("setup", ManualJSON.string(setup)),
      ("convention", ManualJSON.string(convention.rawValue)), ("load", ManualJSON.integer(load)),
      ("reps", ManualJSON.integer(reps)), ("rir", ManualJSON.integer(rir)),
      ("validity", ManualJSON.string(validity.rawValue)), ("warmup", String(warmup)),
      ("skipped", String(skipped)),
    ])
  }
  public init(json: [String: Any]) throws {
    guard let side = LoggedSide(rawValue: try ManualJSON.text(json, "side")),
      let convention = LoadConvention(rawValue: try ManualJSON.text(json, "convention")),
      let validity = SetValidity(rawValue: try ManualJSON.text(json, "validity"))
    else { throw LoggingException("invalid_actuals") }
    self.init(
      slot: try ManualJSON.text(json, "slot"), index: try ManualJSON.int(json, "index"), side: side,
      variant: try ManualJSON.text(json, "variant"), setup: try ManualJSON.text(json, "setup"),
      convention: convention,
      load: try ManualJSON.optionalInt(json, "load"),
      reps: try ManualJSON.optionalInt(json, "reps"),
      rir: try ManualJSON.optionalInt(json, "rir"), validity: validity,
      warmup: try ManualJSON.bool(json, "warmup"), skipped: try ManualJSON.bool(json, "skipped"))
  }
}

/// Manual actuals never establish verified baselines or progression evidence.
public struct ProgramLog: Equatable, Sendable, Identifiable {
  public let id: String
  public let profile: String
  public let programId: String
  public let programVersion: String
  public let revision: Int
  public let endedEarly: Bool
  public let sets: [ProgramSet]
  public let startedTimestamp: ManualTimestamp
  public let completedTimestamp: ManualTimestamp?
  public var startedAt: Date { startedTimestamp.date }
  public var completedAt: Date? { completedTimestamp?.date }
  public var completed: Bool { completedTimestamp != nil }
  public var recommendationEligible: Bool { false }
  /// Validated logs always have a plan. Invalid construction is rejected before persistence.
  public var plan: ProgramSession {
    let programs = programVersion == legacyOwnerProgramVersion ? ownerProgramV1 : ownerProgram
    return programs.first(where: { $0.id == programId })
      ?? ProgramSession(programId, "", "Unknown prescription", [])
  }
  public var exercises: [ProgramExercise] { plan.exercises }
  public init(
    programVersion: String = ownerProgramVersion, endedEarly: Bool = false,
    id: String, profile: String, programId: String, startedAt: Date, revision: Int,
    completedAt: Date?, sets: [ProgramSet]
  ) {
    self.init(
      programVersion: programVersion, endedEarly: endedEarly, id: id, profile: profile,
      programId: programId,
      startedTimestamp: ManualTimestamp(startedAt), revision: revision,
      completedTimestamp: completedAt.map(ManualTimestamp.init), sets: sets)
  }
  private init(
    programVersion: String, endedEarly: Bool, id: String, profile: String, programId: String,
    startedTimestamp: ManualTimestamp, revision: Int, completedTimestamp: ManualTimestamp?,
    sets: [ProgramSet]
  ) {
    self.programVersion = programVersion
    self.endedEarly = endedEarly
    self.id = id
    self.profile = profile
    self.programId = programId
    self.startedTimestamp = startedTimestamp
    self.revision = revision
    self.completedTimestamp = completedTimestamp
    self.sets = sets
  }
  public var allWorkingSetsRecorded: Bool {
    guard supportsOwnerProgram(programVersion), ownerProgram.contains(where: { $0.id == programId })
    else { return false }
    for exercise in exercises {
      for index in 1...exercise.sets {
        for side in exercise.eachSide ? [LoggedSide.left, .right] : [.both] {
          if !sets.contains(where: {
            $0.slot == exercise.id && !$0.warmup && $0.index == index && $0.side == side
          }) {
            return false
          }
        }
      }
    }
    return true
  }
  public var hasSkips: Bool { sets.contains { !$0.warmup && $0.skipped } }
  public func validateSet(_ set: ProgramSet) throws {
    guard supportsOwnerProgram(programVersion) else {
      throw LoggingException("unsupported_program")
    }
    guard let e = exercises.first(where: { $0.id == set.slot }) else {
      throw LoggingException("unknown_slot")
    }
    guard set.index >= 1, set.index <= (set.warmup ? 100 : e.sets),
      e.eachSide ? set.side != .both : set.side == .both
    else { throw LoggingException("invalid_set_identity") }
    guard e.alternatives.isEmpty ? set.variant == e.id : e.alternatives.contains(set.variant),
      !set.setup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      set.setup.utf16.count <= 120
    else {
      throw LoggingException(set.skipped ? "invalid_skip" : "invalid_actuals")
    }
    let bodyweight = ["unassisted_pull_up", "hanging_knee_raise", "ab_wheel_rollout"].contains(
      set.variant)
    let dumbbell = ["incline_dumbbell_press", "dumbbell_shoulder_press"].contains(set.variant)
    let assisted = set.variant == "assisted_machine_pull_up"
    guard (set.convention == .bodyweight) == bodyweight,
      (set.convention == .perDumbbell) == dumbbell,
      (set.convention == .assistance) == assisted
    else { throw LoggingException("invalid_load_convention") }
    if set.skipped {
      guard set.load == nil, set.reps == nil, set.rir == nil, set.validity == .unknown else {
        throw LoggingException("invalid_skip")
      }
      return
    }
    guard set.convention == .bodyweight ? set.load == nil : set.load != nil,
      set.load.map({ (0...1_000_000_000_000).contains($0) }) ?? true,
      let reps = set.reps, (0...10_000).contains(reps),
      set.rir.map({ (0...10_000).contains($0) }) ?? true
    else { throw LoggingException("invalid_actuals") }
  }
  public func record(_ set: ProgramSet) throws -> ProgramLog {
    try validateSet(set)
    let existing = sets.contains { $0.key == set.key }
    if completed && !existing { throw LoggingException("completed_session") }
    if !existing && !set.skipped
      && sets.contains(where: { $0.slot == set.slot && $0.validity == .pain })
    {
      throw LoggingException("exercise_stopped")
    }
    guard revision < Int.max else { throw LoggingException("invalid_session") }
    return ProgramLog(
      programVersion: programVersion, endedEarly: endedEarly, id: id, profile: profile,
      programId: programId,
      startedTimestamp: startedTimestamp, revision: revision + 1,
      completedTimestamp: completedTimestamp,
      sets: sets.filter { $0.key != set.key } + [set])
  }
  public func finish(at: Date, endEarly: Bool = false) throws -> ProgramLog {
    try finish(timestamp: ManualTimestamp(at), endEarly: endEarly)
  }
  public func finish(timestamp: ManualTimestamp, endEarly: Bool = false) throws -> ProgramLog {
    if completed { return self }
    guard startedTimestamp.isValid, timestamp.isValid,
      timestamp.microsecondsSince1970 >= startedTimestamp.microsecondsSince1970
    else { throw LoggingException("invalid_completion_time") }
    guard endEarly || allWorkingSetsRecorded else { throw LoggingException("unrecorded_sets") }
    guard revision < Int.max else { throw LoggingException("invalid_session") }
    return ProgramLog(
      programVersion: programVersion, endedEarly: endEarly, id: id, profile: profile,
      programId: programId,
      startedTimestamp: startedTimestamp, revision: revision + 1, completedTimestamp: timestamp,
      sets: sets)
  }
  public func validate() throws {
    guard supportsOwnerProgram(programVersion) else {
      throw LoggingException("unsupported_program")
    }
    try validateStorageId(id)
    try validateStorageId(profile)
    guard ownerProgram.contains(where: { $0.id == programId }), startedTimestamp.isValid,
      revision >= 0, Set(sets.map(\.key)).count == sets.count
    else { throw LoggingException("invalid_session") }
    if let timestamp = completedTimestamp {
      guard timestamp.isValid,
        timestamp.microsecondsSince1970 >= startedTimestamp.microsecondsSince1970
      else { throw LoggingException("invalid_session") }
    }
    for set in sets { try validateSet(set) }
    if endedEarly && !completed { throw LoggingException("invalid_early_finish") }
    if completed && !endedEarly && !allWorkingSetsRecorded {
      throw LoggingException("incomplete_record")
    }
  }
  public func encodedJSON() -> String {
    var fields: [(String, String)] = [
      ("id", ManualJSON.string(id)), ("profile", ManualJSON.string(profile)),
      ("programId", ManualJSON.string(programId)),
      ("version", ManualJSON.string(programVersion)),
      ("startedAt", ManualJSON.string(startedTimestamp.encoded)),
      ("completedAt", completedTimestamp.map { ManualJSON.string($0.encoded) } ?? "null"),
    ]
    if endedEarly { fields.append(("endedEarly", "true")) }
    fields += [
      ("revision", String(revision)), ("sets", ManualJSON.array(sets.map { $0.encodedJSON() })),
    ]
    return ManualJSON.object(fields)
  }
  public init(jsonString: String) throws { try self.init(json: ManualJSON.decode(jsonString)) }
  public init(json: [String: Any]) throws {
    let version = try ManualJSON.text(json, "version")
    guard supportsOwnerProgram(version) else { throw LoggingException("unsupported_program") }
    guard let rawSets = json["sets"] as? [[String: Any]] else {
      throw LoggingException("invalid_session")
    }
    let end =
      json["completedAt"] == nil || json["completedAt"] is NSNull
      ? nil : try ManualTimestamp(parsing: ManualJSON.text(json, "completedAt"))
    let early =
      json["endedEarly"] == nil || json["endedEarly"] is NSNull
      ? false : try ManualJSON.bool(json, "endedEarly")
    self.init(
      programVersion: version, endedEarly: early, id: try ManualJSON.text(json, "id"),
      profile: try ManualJSON.text(json, "profile"),
      programId: try ManualJSON.text(json, "programId"),
      startedTimestamp: try ManualTimestamp(parsing: ManualJSON.text(json, "startedAt")),
      revision: try ManualJSON.int(json, "revision"), completedTimestamp: end,
      sets: try rawSets.map(ProgramSet.init(json:)))
    try validate()
  }
  public func prescriptionJSON() -> String {
    ManualJSON.object([
      ("id", ManualJSON.string(plan.id)), ("day", ManualJSON.string(plan.day)),
      ("title", ManualJSON.string(plan.title)),
      (
        "blocks",
        ManualJSON.array(
          plan.blocks.map { block in
            ManualJSON.object([
              ("rest", String(block.restSeconds)),
              (
                "exercises",
                ManualJSON.array(
                  block.exercises.map { e in
                    ManualJSON.object([
                      ("id", ManualJSON.string(e.id)), ("name", ManualJSON.string(e.name)),
                      ("sets", String(e.sets)),
                      ("minReps", String(e.minReps)), ("maxReps", String(e.maxReps)),
                      ("minRir", String(e.minRir)), ("maxRir", String(e.maxRir)),
                      ("eachSide", String(e.eachSide)),
                      ("alternatives", ManualJSON.array(e.alternatives.map(ManualJSON.string))),
                    ])
                  })
              ),
            ])
          })
      ),
    ])
  }
}

public protocol ProgramLogRepository: Sendable {
  func load(_ profile: String) throws -> [ProgramLog]
  func write(_ log: ProgramLog, expectedRevision: Int, actionId: String) throws
  func delete(_ profile: String, id: String, expectedRevision: Int, actionId: String) throws
  func close() throws
}
