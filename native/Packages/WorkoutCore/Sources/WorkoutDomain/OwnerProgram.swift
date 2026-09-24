import Foundation

/// Approved manual prescriptions, never catalog identities or generated recommendations.
public let ownerProgramVersion = "owner-program-v2"
public let legacyOwnerProgramVersion = "owner-program-v1"

public struct ProgramExercise: Equatable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let sets: Int
  public let minReps: Int
  public let maxReps: Int
  public let eachSide: Bool
  public let alternatives: [String]
  public var minRir: Int { 2 }
  public var maxRir: Int { 3 }
  public init(
    _ id: String, _ name: String, _ sets: Int, _ minReps: Int, _ maxReps: Int,
    eachSide: Bool = false, alternatives: [String] = []
  ) {
    self.id = id
    self.name = name
    self.sets = sets
    self.minReps = minReps
    self.maxReps = maxReps
    self.eachSide = eachSide
    self.alternatives = alternatives
  }
}

public struct ProgramBlock: Equatable, Sendable {
  public let restSeconds: Int
  public let exercises: [ProgramExercise]
  public var isSuperset: Bool { exercises.count == 2 }
  public init(_ restSeconds: Int, _ exercises: [ProgramExercise]) {
    self.restSeconds = restSeconds
    self.exercises = exercises
  }
}

public struct ProgramSession: Equatable, Sendable, Identifiable {
  public let id: String
  public let day: String
  public let title: String
  public let blocks: [ProgramBlock]
  public var exercises: [ProgramExercise] { blocks.flatMap(\.exercises) }
  public init(_ id: String, _ day: String, _ title: String, _ blocks: [ProgramBlock]) {
    self.id = id
    self.day = day
    self.title = title
    self.blocks = blocks
  }
}

public let ownerProgramV1: [ProgramSession] = [
  ProgramSession(
    "monday", "Monday", "Upper chest + lats",
    [
      ProgramBlock(
        120, [ProgramExercise("incline_dumbbell_press", "Incline Dumbbell Press", 3, 6, 10)]),
      ProgramBlock(
        120, [ProgramExercise("neutral_grip_lat_pulldown", "Neutral-Grip Lat Pulldown", 3, 8, 12)]),
      ProgramBlock(
        90,
        [
          ProgramExercise("incline_machine_press", "Incline Machine Press", 3, 8, 12),
          ProgramExercise("chest_supported_row", "Chest-Supported Row", 3, 8, 12),
        ]),
      ProgramBlock(
        60,
        [
          ProgramExercise("cable_lateral_raise", "Cable Lateral Raise", 3, 12, 20),
          ProgramExercise("cable_chest_fly", "Cable Chest Fly", 3, 12, 15),
        ]),
    ]),
  ProgramSession(
    "tuesday", "Tuesday", "Legs + abs",
    [
      ProgramBlock(120, [ProgramExercise("leg_press", "Leg Press", 3, 10, 15)]),
      ProgramBlock(
        75,
        [
          ProgramExercise("leg_extension", "Leg Extension", 3, 12, 15),
          ProgramExercise("seated_leg_curl", "Seated Leg Curl", 3, 10, 15),
        ]),
      ProgramBlock(
        60,
        [
          ProgramExercise("machine_calf_raise", "Machine Calf Raise", 3, 12, 20),
          ProgramExercise("cable_crunch", "Cable Crunch", 3, 10, 15),
        ]),
    ]),
  ProgramSession(
    "wednesday", "Wednesday", "Shoulders + arms + abs",
    [
      ProgramBlock(
        120,
        [
          ProgramExercise(
            "shoulder_press", "Seated Shoulder Press", 2, 8, 12,
            alternatives: ["machine_shoulder_press", "dumbbell_shoulder_press"])
        ]),
      ProgramBlock(
        60,
        [
          ProgramExercise("cable_lateral_raise", "Cable Lateral Raise", 3, 12, 20),
          ProgramExercise("reverse_pec_deck", "Reverse Pec Deck", 3, 12, 20),
        ]),
      ProgramBlock(
        60,
        [
          ProgramExercise("cable_curl", "Cable Curl", 3, 8, 12),
          ProgramExercise(
            "overhead_cable_triceps_extension", "Overhead Cable Triceps Extension", 3, 10, 15),
        ]),
      ProgramBlock(60, [ProgramExercise("hanging_knee_raise", "Hanging Knee Raise", 3, 8, 15)]),
    ]),
  ProgramSession(
    "friday", "Friday", "Back + chest",
    [
      ProgramBlock(
        120,
        [
          ProgramExercise(
            "pull_up", "Pull-Ups / Assisted Pull-Ups", 3, 6, 10,
            alternatives: ["unassisted_pull_up", "assisted_machine_pull_up"])
        ]),
      ProgramBlock(
        90,
        [
          ProgramExercise("incline_machine_press", "Incline Machine Press", 3, 8, 12),
          ProgramExercise("seated_cable_row", "Seated Cable Row", 3, 8, 12),
        ]),
      ProgramBlock(
        90,
        [
          ProgramExercise(
            "single_arm_cable_pulldown", "Single-Arm Cable Pulldown", 3, 10, 15, eachSide: true)
        ]),
      ProgramBlock(
        60,
        [
          ProgramExercise("machine_chest_fly", "Machine Chest Fly", 3, 12, 15),
          ProgramExercise("cable_lateral_raise", "Cable Lateral Raise", 3, 15, 20),
        ]),
    ]),
  ProgramSession(
    "saturday", "Saturday", "Legs + abs + conditioning",
    [
      ProgramBlock(120, [ProgramExercise("hack_squat", "Hack Squat", 3, 8, 12)]),
      ProgramBlock(
        75,
        [
          ProgramExercise("leg_extension", "Leg Extension", 3, 12, 15),
          ProgramExercise(
            "leg_curl", "Seated/Lying Leg Curl", 3, 10, 15,
            alternatives: ["seated_leg_curl", "lying_leg_curl"]),
        ]),
      ProgramBlock(
        60,
        [
          ProgramExercise("machine_calf_raise", "Machine Calf Raise", 3, 12, 20),
          ProgramExercise("ab_wheel_rollout", "Ab-Wheel Rollout", 3, 6, 12),
        ]),
    ]),
]

public let ownerProgram: [ProgramSession] = ownerProgramV1.map { session in
  guard session.id == "wednesday" else { return session }
  return ProgramSession(
    session.id, session.day, session.title,
    session.blocks.map { block in
      ProgramBlock(
        block.restSeconds,
        block.exercises.map { e in
          guard e.id == "shoulder_press" else { return e }
          return ProgramExercise(
            e.id, e.name, 3, e.minReps, e.maxReps,
            eachSide: e.eachSide, alternatives: e.alternatives)
        })
    })
}

public func supportsOwnerProgram(_ version: String) -> Bool {
  version == ownerProgramVersion || version == legacyOwnerProgramVersion
}
public func ownerProgramForVersion(_ version: String) throws -> [ProgramSession] {
  switch version {
  case ownerProgramVersion: return ownerProgram
  case legacyOwnerProgramVersion: return ownerProgramV1
  default: throw LoggingException("unsupported_program")
  }
}
