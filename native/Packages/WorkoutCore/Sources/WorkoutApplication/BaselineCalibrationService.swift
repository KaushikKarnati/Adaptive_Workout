import Foundation
import WorkoutDomain

/// Descriptive manual-log progress only; log count never authorizes generation.
public struct CalibrationProgress: Equatable, Sendable {
  public let loggedCount: Int
  public let requiredCount: Int

  public init(loggedCount: Int, requiredCount: Int = 7) {
    self.loggedCount = loggedCount
    self.requiredCount = requiredCount
  }

  public var remainingCount: Int {
    max(0, requiredCount - loggedCount)
  }

  public var isUnlocked: Bool {
    false
  }

  public var fraction: Double {
    guard requiredCount > 0 else { return 1.0 }
    return min(1.0, max(0.0, Double(loggedCount) / Double(requiredCount)))
  }

  public var percentage: Int {
    Int((fraction * 100).rounded())
  }
}

/// Reads manual-log progress without promoting observations into verified evidence.
public struct BaselineCalibrationService: Sendable {
  public let programLogsRepository: any ProgramLogRepository
  public let setupRepository: any TrainingSetupRepository
  public let profileId: String
  public let now: @Sendable () -> Date

  public init(
    programLogsRepository: any ProgramLogRepository,
    setupRepository: any TrainingSetupRepository,
    profileId: String = "local_owner",
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.programLogsRepository = programLogsRepository
    self.setupRepository = setupRepository
    self.profileId = profileId
    self.now = now
  }

  public func getCalibrationProgress() throws -> CalibrationProgress {
    let logs = try programLogsRepository.load(profileId)
    let validLogs = logs.filter { log in
      log.completed || log.sets.contains { !$0.warmup && !$0.skipped && $0.validity == .valid }
    }
    return CalibrationProgress(loggedCount: validLogs.count, requiredCount: 7)
  }

  /// Manual records are observations, not owner attestations of equipment,
  /// starting loads, rehearsal feedback, or safety clearance (ADRs 0012/0015).
  @discardableResult
  public func calibrateBaselines(actionId: String) throws -> TrainingSetup {
    throw SetupException("explicit_setup_and_baseline_confirmation_required")
  }
}
