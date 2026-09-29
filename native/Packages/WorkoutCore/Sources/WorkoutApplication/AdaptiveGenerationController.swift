import Combine
import Foundation
import WorkoutDomain

@MainActor
public final class AdaptiveGenerationController: ObservableObject {
  private let generationService: SessionGenerationService
  private let savedService: SavedWorkoutService
  private let historyRepository: any RecommendationHistoryRepository
  private let setupRepository: any TrainingSetupRepository
  private let calibrationService: BaselineCalibrationService
  public let profile: String

  @Published public private(set) var activeWorkout: SavedWorkout?
  @Published public private(set) var latestRecommendation: RecommendationSnapshot?
  @Published public private(set) var lastResult: SessionCompositionResult?
  @Published public private(set) var history: GeneratedHistory?
  @Published public private(set) var calibrationProgress: CalibrationProgress = .init(
    loggedCount: 0)
  @Published public private(set) var busy = false
  @Published public private(set) var error: String?

  public var locked: Bool { busy }

  public init(
    generationService: SessionGenerationService,
    savedService: SavedWorkoutService,
    historyRepository: any RecommendationHistoryRepository,
    setupRepository: any TrainingSetupRepository,
    calibrationService: BaselineCalibrationService,
    profile: String = "local_owner"
  ) {
    self.generationService = generationService
    self.savedService = savedService
    self.historyRepository = historyRepository
    self.setupRepository = setupRepository
    self.calibrationService = calibrationService
    self.profile = profile
  }

  private func identity() -> String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  public func load() async {
    guard !busy else { return }
    busy = true
    error = nil
    defer { busy = false }

    do {
      let savedService = self.savedService
      let historyRepo = self.historyRepository
      let calibration = self.calibrationService
      let profile = self.profile

      let (resumed, loadedHistory, progress) = try await Task.detached {
        let resumed = try savedService.resume(profile)
        let hist = try historyRepo.load(profile)
        let prog =
          (try? calibration.getCalibrationProgress()) ?? CalibrationProgress(loggedCount: 0)
        return (resumed, hist, prog)
      }.value

      self.activeWorkout = resumed
      self.history = loadedHistory
      self.latestRecommendation = loadedHistory.recommendations.last
      self.calibrationProgress = progress
    } catch {
      self.error = "Could not load adaptive workouts. Try again."
    }
  }

  @discardableResult
  public func generate(sessionId: String? = nil) async -> SessionCompositionResult? {
    guard !busy else { return nil }
    busy = true
    error = nil
    defer { busy = false }

    do {
      let service = self.generationService
      let reqId = identity()
      let actId = identity()

      let result = try await Task.detached {
        try service.generate(reqId, actionId: actId)
      }.value

      self.lastResult = result
      if let snapshot = result.snapshot {
        self.latestRecommendation = snapshot
      }
      await refreshHistory()
      return result
    } catch {
      self.error = "Generation failed: \(error.localizedDescription)"
      return nil
    }
  }

  @discardableResult
  public func calibrateBaselinesFromLogs() async -> Bool {
    guard !busy else { return false }
    busy = true
    error = nil

    let succeeded: Bool
    do {
      let calibration = self.calibrationService
      let actId = identity()

      _ = try await Task.detached {
        try calibration.calibrateBaselines(actionId: actId)
      }.value

      succeeded = true
    } catch {
      self.error = "Could not calibrate baselines: \(error)"
      succeeded = false
    }
    busy = false

    if succeeded {
      await refreshHistory()
      _ = await generate()
      return true
    } else {
      return false
    }
  }

  @discardableResult
  public func start(recommendationId: String) async -> Bool {
    guard !busy else { return false }
    busy = true
    error = nil
    defer { busy = false }

    do {
      let service = self.savedService
      let profile = self.profile
      let occId = identity()
      let actId = identity()
      let now = Date()

      let started = try await Task.detached {
        let action = try service.prepareStart(
          profile: profile, recommendationId: recommendationId, occurrenceId: occId, at: now,
          actionId: actId)
        return try service.commit(action)
      }.value

      self.activeWorkout = started
      await refreshHistory()
      return true
    } catch {
      self.error = "Could not start workout: \(error.localizedDescription)"
      return false
    }
  }

  @discardableResult
  public func record(_ set: ProgramSet) async -> Bool {
    guard !busy, let active = activeWorkout else { return false }
    busy = true
    error = nil
    defer { busy = false }

    do {
      let service = self.savedService
      let profile = self.profile
      let occId = active.occurrence.id
      let actId = identity()
      let now = Date()

      let updated = try await Task.detached {
        let action = try service.prepareSet(
          profile: profile, occurrenceId: occId, set: set, at: now, actionId: actId)
        return try service.commit(action)
      }.value

      self.activeWorkout = updated
      return true
    } catch {
      self.error = "Could not save set. Try again."
      return false
    }
  }

  @discardableResult
  public func finish(endEarly: Bool = false) async -> Bool {
    guard !busy, let active = activeWorkout else { return false }
    busy = true
    error = nil
    defer { busy = false }

    do {
      let service = self.savedService
      let profile = self.profile
      let occId = active.occurrence.id
      let actId = identity()
      let now = Date()

      _ = try await Task.detached {
        let action = try service.prepareFinish(
          profile: profile, occurrenceId: occId, endEarly: endEarly, at: now, actionId: actId)
        return try service.commit(action)
      }.value

      self.activeWorkout = nil
      await refreshHistory()
      return true
    } catch {
      self.error = "Could not finish workout. Record all sets or finish early."
      return false
    }
  }

  private func refreshHistory() async {
    do {
      let repo = self.historyRepository
      let calibration = self.calibrationService
      let profile = self.profile
      let (hist, prog) = try await Task.detached {
        let prog =
          (try? calibration.getCalibrationProgress()) ?? CalibrationProgress(loggedCount: 0)
        return (try repo.load(profile), prog)
      }.value
      self.history = hist
      self.calibrationProgress = prog
      if let last = self.history?.recommendations.last {
        self.latestRecommendation = last
      }
    } catch {
      // non-fatal
    }
  }
}
