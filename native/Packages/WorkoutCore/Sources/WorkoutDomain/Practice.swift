import Foundation

public let practiceExercises = ["practice_press": "Practice press", "practice_row": "Practice row"]
public struct PracticeSet: Equatable, Sendable {
  public let id: String, exerciseId: String, index: Int, microPounds: Int?, reps: Int?, rir: Int?,
    working: Bool, validity: SetValidity, skipped: Bool
  public init(
    id: String, exerciseId: String, index: Int, microPounds: Int?, reps: Int?, rir: Int?,
    working: Bool, validity: SetValidity, skipped: Bool = false
  ) throws {
    self.id = id
    self.exerciseId = exerciseId
    self.index = index
    self.microPounds = microPounds
    self.reps = reps
    self.rir = rir
    self.working = working
    self.validity = validity
    self.skipped = skipped
    try validateStorageId(id)
    guard practiceExercises[exerciseId] != nil && (1...10000).contains(index) else {
      throw LoggingException(code: "invalid_set_identity")
    }
    if skipped {
      guard microPounds == nil && reps == nil && rir == nil && validity == .unknown else {
        throw LoggingException(code: "invalid_skip")
      }
    } else {
      guard microPounds.map({ (0...1_000_000_000_000).contains($0) }) == true,
        reps.map({ (0...10000).contains($0) }) == true,
        rir.map({ (0...10000).contains($0) }) ?? true
      else { throw LoggingException(code: "invalid_actuals") }
    }
  }
  public var canonicalJSON: String {
    ManualJSON.object([
      ("id", SetupJSON.string(id)), ("exerciseId", SetupJSON.string(exerciseId)),
      ("index", String(index)), ("microPounds", SetupJSON.integer(microPounds)),
      ("reps", SetupJSON.integer(reps)), ("rir", SetupJSON.integer(rir)),
      ("working", SetupJSON.bool(working)), ("validity", SetupJSON.string(validity.rawValue)),
      ("skipped", SetupJSON.bool(skipped)),
    ])
  }
  public static func decode(_ payload: String) throws -> PracticeSet {
    do {
      let j = try ManualJSON.decode(payload)
      guard let validity = SetValidity(rawValue: try ManualJSON.text(j, "validity")) else {
        throw LoggingException(code: "invalid_stored_set")
      }
      return try PracticeSet(
        id: ManualJSON.text(j, "id"), exerciseId: ManualJSON.text(j, "exerciseId"),
        index: ManualJSON.int(j, "index"), microPounds: SetupJSON.optionalInt(j, "microPounds"),
        reps: SetupJSON.optionalInt(j, "reps"), rir: SetupJSON.optionalInt(j, "rir"),
        working: ManualJSON.bool(j, "working"), validity: validity,
        skipped: ManualJSON.bool(j, "skipped"))
    } catch { throw LoggingException(code: "invalid_stored_set") }
  }
}
public struct PracticeSession: Equatable, Sendable {
  public let id: String, profileId: String, startedAt: Date, completedAt: Date?, revision: Int,
    sets: [PracticeSet]
  public init(
    id: String, profileId: String, startedAt: Date, completedAt: Date?, revision: Int,
    sets: [PracticeSet]
  ) {
    self.id = id
    self.profileId = profileId
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.revision = revision
    self.sets = sets
  }
  public var completed: Bool { completedAt != nil }
  public var isPractice: Bool { true }
}
public protocol PracticeRepository {
  func load(_ profileId: String) throws -> [PracticeSession]
  func start(profileId: String, sessionId: String, actionId: String, at: Date) throws
  func saveSet(
    profileId: String, sessionId: String, actionId: String, expectedRevision: Int,
    record: PracticeSet, correction: Bool, at: Date) throws
  func complete(
    profileId: String, sessionId: String, actionId: String, expectedRevision: Int, at: Date) throws
}
