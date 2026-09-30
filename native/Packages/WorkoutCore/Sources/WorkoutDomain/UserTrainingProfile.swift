import Foundation

public enum TrainingGoal: String, Codable, CaseIterable, Sendable {
  case strength, muscle, generalFitness, flexibility
  public var title: String {
    switch self {
    case .strength: "Build strength"
    case .muscle: "Build muscle"
    case .generalFitness: "General fitness"
    case .flexibility: "Flexibility"
    }
  }
}
public enum TrainingExperience: String, Codable, CaseIterable, Sendable {
  case new, returning, consistent, experienced
  public var title: String {
    switch self {
    case .new: "New to strength training"
    case .returning: "Returning after a break"
    case .consistent: "Training consistently"
    case .experienced: "Experienced lifter"
    }
  }
}
public enum OnboardingStep: Int, Codable, CaseIterable, Sendable {
  case welcome, goals, schedule, environment, constraints, program, equipment, baselines, health,
    review
}
public enum HealthCategory: String, Codable, CaseIterable, Sendable {
  case workouts, sleep, hrv, restingHeartRate, steps, activeEnergy, weight, bodyFat, leanMass
  public var title: String {
    switch self {
    case .workouts: "Outside workouts"
    case .sleep: "Sleep"
    case .hrv: "Heart rate variability"
    case .restingHeartRate: "Resting heart rate"
    case .steps: "Steps"
    case .activeEnergy: "Active energy"
    case .weight: "Body weight"
    case .bodyFat: "Body fat percentage"
    case .leanMass: "Lean body mass"
    }
  }
}
public struct DraftExercise: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var sets: Int
  public var minReps: Int
  public var maxReps: Int
  public var restSeconds: Int
  public var pair: String?
  public var locked: Bool
  public init(
    id: String = UUID().uuidString, name: String = "", sets: Int = 3, minReps: Int = 8,
    maxReps: Int = 12, restSeconds: Int = 90, pair: String? = nil, locked: Bool = false
  ) {
    self.id = id
    self.name = name
    self.sets = sets
    self.minReps = minReps
    self.maxReps = maxReps
    self.restSeconds = restSeconds
    self.pair = pair
    self.locked = locked
  }
}
public struct DraftSession: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var title: String
  public var locked: Bool
  public var exercises: [DraftExercise]
  public init(
    id: String = UUID().uuidString, title: String = "Session", locked: Bool = false,
    exercises: [DraftExercise] = []
  ) {
    self.id = id
    self.title = title
    self.locked = locked
    self.exercises = exercises
  }
}
/// Preferences and reported inputs only. Never authoritative training evidence.
public struct UserTrainingProfile: Codable, Equatable, Sendable, Identifiable {
  public var schemaVersion = 1
  public var id: String
  public var revision = 0
  public var step: OnboardingStep = .welcome
  public var goal: TrainingGoal?
  public var secondaryGoals: [TrainingGoal] = []
  public var experience: TrainingExperience?
  public var weekdays: [Int] = []
  public var minutes: Int?
  public var units = "lb"
  public var environment = ""
  public var equipment: [String] = []
  public var limitations = ""
  public var symptomReported: Bool?
  public var exclusions = ""
  public var sessions: [DraftSession] = []
  public var healthCategories: [HealthCategory] = []
  public var preferencesReviewed = false
  public init(id: String = UUID().uuidString) { self.id = id }
  public var activationBlockers: [String] {
    var reasons = [
      "Exercise and training-profile reviews are incomplete",
      "Verified equipment required for the entire program",
      "Verified starting targets and rehearsals required", "Current safety assessment required",
      "Adaptive workout generation is not ready",
    ]
    if goal == nil || experience == nil { reasons.insert("Choose a goal and experience", at: 0) }
    if weekdays.isEmpty { reasons.insert("Choose training days", at: 0) }
    if sessions.isEmpty { reasons.insert("Prepare a supported program", at: 0) }
    if symptomReported != false { reasons.insert("Safety input requires review", at: 0) }
    return reasons
  }
  public func validate() throws {
    guard schemaVersion == 1, !id.isEmpty, id.utf8.count <= 128, revision >= 0, revision < Int.max,
      Set(weekdays).count == weekdays.count, weekdays.allSatisfy({ (1...7).contains($0) }),
      minutes == nil || minutes! > 0, ["lb", "kg"].contains(units),
      environment.utf8.count <= 120, limitations.utf8.count <= 2000, exclusions.utf8.count <= 2000,
      Set(equipment).count == equipment.count, equipment.count <= 100,
      equipment.allSatisfy({ SetupTaxonomy.equipmentIds.contains($0) }),
      Set(healthCategories).count == healthCategories.count,
      Set(secondaryGoals).count == secondaryGoals.count,
      !secondaryGoals.contains(where: { $0 == goal }),
      sessions.count <= 14, Set(sessions.map(\.id)).count == sessions.count
    else { throw ProfileFailure.invalid }
    for session in sessions {
      guard !session.id.isEmpty, session.id.utf8.count <= 128, !session.title.isEmpty,
        session.title.utf8.count <= 120, session.exercises.count <= 50,
        Set(session.exercises.map(\.id)).count == session.exercises.count
      else { throw ProfileFailure.invalid }
      for exercise in session.exercises {
        guard !exercise.id.isEmpty, exercise.id.utf8.count <= 128, !exercise.name.isEmpty,
          exercise.name.utf8.count <= 200, (1...20).contains(exercise.sets),
          (1...100).contains(exercise.minReps), (exercise.minReps...100).contains(exercise.maxReps),
          (0...3600).contains(exercise.restSeconds), (exercise.pair?.utf8.count ?? 0) <= 128
        else { throw ProfileFailure.invalid }
      }
    }
  }
  public static func ownerDraft() -> [DraftSession] {
    ownerProgram.map { session in
      DraftSession(
        id: session.id, title: session.title,
        exercises: session.blocks.enumerated().flatMap { index, block in
          block.exercises.map { exercise in
            DraftExercise(
              id: exercise.id, name: exercise.name, sets: exercise.sets,
              minReps: exercise.minReps, maxReps: exercise.maxReps, restSeconds: block.restSeconds,
              pair: block.isSuperset ? "pair-\(index)" : nil)
          }
        })
    }
  }
}
public enum ProfileFailure: Error { case invalid, conflict, unsupportedSchema }
public protocol UserTrainingProfileRepository: Sendable {
  func load(_ id: String) throws -> UserTrainingProfile?
  func save(_ next: UserTrainingProfile, expectedRevision: Int?) throws
}
