import Foundation
import WorkoutApplication
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class LiveGenerationTests: XCTestCase {
  func testOwnerProgramCatalogSliceValidity() throws {
    XCTAssertEqual(OwnerProgramCatalogSlice.entries.count, 25)
    let validator = ExerciseCatalogValidator(importedAt: OwnerProgramCatalogSlice.retrievedAt)
    for entry in OwnerProgramCatalogSlice.entries {
      let issues = validator.validate(entry)
      XCTAssertTrue(issues.isEmpty, "\(entry.id) has issues: \(issues)")
      XCTAssertEqual(entry.availability, .enabled)
    }
    XCTAssertEqual(
      OwnerProgramCatalogSlice.manifest.contentSha256, OwnerProgramCatalogSlice.contentSha256)
    XCTAssertEqual(OwnerProgramCatalogSlice.bindings.exerciseIds.count, 25)
    for variant in OwnerProgramCatalogSlice.variants {
      XCTAssertNotNil(OwnerProgramCatalogSlice.bindings.exerciseIds[variant])
    }
  }

  func testCoordinatedGenerationSourceBlocksOnEmptyBaselines() throws {
    let setupRepo = try SqliteTrainingSetupRepository(path: ":memory:")
    let historyRepo = try SqliteRecommendationHistoryRepository(path: ":memory:")

    let source = CoordinatedSessionGenerationSource(
      profile: "test_user",
      setupRepository: setupRepo,
      historyRepository: historyRepo,
      catalog: OwnerProgramCatalogSlice.entries,
      catalogDigest: OwnerProgramCatalogSlice.contentSha256,
      candidateExerciseIds: Array(OwnerProgramCatalogSlice.bindings.exerciseIds.values),
      manifest: OwnerProgramCatalogSlice.manifest,
      preferredSessionId: "monday"
    )

    let composer = SessionComposer(
      evaluator: ExerciseEligibilityEvaluator(
        catalogValidator: ExerciseCatalogManifestValidator(
          importedAt: OwnerProgramCatalogSlice.retrievedAt)),
      bindings: OwnerProgramCatalogSlice.bindings
    )

    let service = SessionGenerationService(source: source, composer: composer)

    // With no setup configured, composition should cleanly fail-closed / require inputs
    let result = try service.generate("req_1", actionId: "act_1")
    XCTAssertFalse(result.isReady)
    XCTAssertNil(result.snapshot)
  }

  func testSavedWorkoutServicePrepareStartAndExecutionLifecycle() throws {
    let historyRepo = try SqliteRecommendationHistoryRepository(path: ":memory:")
    let savedService = SavedWorkoutService(historyRepo)
    let date = Date(timeIntervalSince1970: 1_728_000_000)

    let target = try SetTarget(
      index: 1, side: .both, warmup: false, load: 50_000_000, minReps: 8, maxReps: 12, minRir: 2,
      maxRir: 3, restSeconds: 90)
    let slot = try RecommendedSlot(
      id: "incline_machine_press", exerciseId: "owner_ex_incline_machine_press",
      blockId: "block_1", setupId: "machine_1", setupRevision: 0,
      baselineReference: "baseline_ref", convention: .machineSetting, unilateral: false,
      targets: [target])
    let plan = try RecommendationSnapshot(
      id: "rec_1", profile: "test_user", programId: "owner-program", programVersion: "v1",
      sessionTemplate: "monday", ruleVersion: "v1", catalogVersion: "2026.09.29.1",
      catalogDigest: String(repeating: "f", count: 64), createdAt: date, requestedDate: date,
      timezone: "UTC", historyRevision: 0,
      inputRevisions: Dictionary(
        uniqueKeysWithValues: [
          "profile", "equipment", "baseline", "constraints", "safety", "catalogSchema", "taxonomy",
        ].map { ($0, 0) }), evidence: [:], status: .ready, reasons: ["test"], slots: [slot],
      walkSeconds: 300, preferredMinutes: 60, estimatedSeconds: nil)

    try historyRepo.saveRecommendation(plan, actionId: "save_rec")

    // Start workout
    let startAction = try savedService.prepareStart(
      profile: "test_user", recommendationId: "rec_1", occurrenceId: "occ_1", at: date,
      actionId: "start_act")
    let started = try savedService.commit(startAction)
    XCTAssertEqual(started.occurrence.id, "occ_1")
    XCTAssertEqual(started.occurrence.status, .active)

    // Resumption should return the active workout
    let resumed = try savedService.resume("test_user")
    XCTAssertNotNil(resumed)
    XCTAssertEqual(resumed?.occurrence.id, "occ_1")

    // Record a set
    let programSet = ProgramSet(
      slot: "incline_machine_press", index: 1, side: .both,
      variant: "owner_ex_incline_machine_press", setup: "machine_1",
      convention: .machineSetting, load: 50_000_000, reps: 10, rir: 2,
      validity: .valid, warmup: false, skipped: false)
    let setAction = try savedService.prepareSet(
      profile: "test_user", occurrenceId: "occ_1", set: programSet,
      at: date.addingTimeInterval(60), actionId: "set_act")
    let afterSet = try savedService.commit(setAction)
    XCTAssertEqual(afterSet.occurrence.sets.count, 1)

    // Finish workout
    let finishAction = try savedService.prepareFinish(
      profile: "test_user", occurrenceId: "occ_1", endEarly: false,
      at: date.addingTimeInterval(120), actionId: "finish_act")
    let finished = try savedService.commit(finishAction)
    XCTAssertEqual(finished.occurrence.status, .completed)

    // Resumption should now be nil
    XCTAssertNil(try savedService.resume("test_user"))
  }

  @MainActor
  func testAdaptiveGenerationControllerLifecycle() async throws {
    let setupRepo = try SqliteTrainingSetupRepository(path: ":memory:")
    let historyRepo = try SqliteRecommendationHistoryRepository(path: ":memory:")

    let source = CoordinatedSessionGenerationSource(
      profile: "test_user",
      setupRepository: setupRepo,
      historyRepository: historyRepo,
      catalog: OwnerProgramCatalogSlice.entries,
      catalogDigest: OwnerProgramCatalogSlice.contentSha256,
      candidateExerciseIds: Array(OwnerProgramCatalogSlice.bindings.exerciseIds.values),
      manifest: OwnerProgramCatalogSlice.manifest,
      preferredSessionId: "monday"
    )

    let composer = SessionComposer(
      evaluator: ExerciseEligibilityEvaluator(
        catalogValidator: ExerciseCatalogManifestValidator(
          importedAt: OwnerProgramCatalogSlice.retrievedAt)),
      bindings: OwnerProgramCatalogSlice.bindings
    )

    let genService = SessionGenerationService(source: source, composer: composer)
    let savedService = SavedWorkoutService(historyRepo)

    let logsRepo = try SqliteProgramLogRepository(path: ":memory:")
    let calibrationService = BaselineCalibrationService(
      programLogsRepository: logsRepo,
      setupRepository: setupRepo,
      profileId: "test_user"
    )

    let controller = AdaptiveGenerationController(
      generationService: genService,
      savedService: savedService,
      historyRepository: historyRepo,
      setupRepository: setupRepo,
      calibrationService: calibrationService,
      profile: "test_user"
    )

    await controller.load()
    XCTAssertNil(controller.activeWorkout)
    XCTAssertNil(controller.latestRecommendation)

    // Attempt generation with empty baseline
    let result = await controller.generate()
    XCTAssertNotNil(result)
    XCTAssertFalse(result!.isReady)
    XCTAssertNil(controller.activeWorkout)
  }

  @MainActor
  func testBaselineCalibrationUnlocksGeneration() async throws {
    let setupRepo = try SqliteTrainingSetupRepository(path: ":memory:")
    let historyRepo = try SqliteRecommendationHistoryRepository(path: ":memory:")
    let logsRepo = try SqliteProgramLogRepository(path: ":memory:")

    // Seed a manual log with a custom working load
    let set = ProgramSet(
      slot: "incline_dumbbell_press",
      index: 1,
      side: .both,
      variant: "incline_dumbbell_press",
      setup: "Dumbbell Bench 30°",
      convention: .perDumbbell,
      load: 45_000_000,
      reps: 10,
      rir: 2,
      validity: .valid,
      warmup: false,
      skipped: false
    )
    let initial = ProgramLog(
      programVersion: ownerProgramVersion,
      endedEarly: false,
      id: "manual_log_day1",
      profile: "test_user",
      programId: "monday",
      startedAt: Date(timeIntervalSince1970: 1_728_000_000),
      revision: 0,
      completedAt: nil,
      sets: []
    )
    try logsRepo.write(initial, expectedRevision: -1, actionId: "seed_start")

    let recorded = try initial.record(set)
    try logsRepo.write(recorded, expectedRevision: 0, actionId: "seed_set")

    let finished = try recorded.finish(
      at: Date(timeIntervalSince1970: 1_728_003_600),
      endEarly: true
    )
    try logsRepo.write(finished, expectedRevision: 1, actionId: "seed_finish")

    let calibrationService = BaselineCalibrationService(
      programLogsRepository: logsRepo,
      setupRepository: setupRepo,
      profileId: "test_user"
    )

    let source = CoordinatedSessionGenerationSource(
      profile: "test_user",
      setupRepository: setupRepo,
      historyRepository: historyRepo,
      catalog: OwnerProgramCatalogSlice.entries,
      catalogDigest: OwnerProgramCatalogSlice.contentSha256,
      candidateExerciseIds: Array(OwnerProgramCatalogSlice.bindings.exerciseIds.values),
      manifest: OwnerProgramCatalogSlice.manifest,
      preferredSessionId: "monday"
    )

    let composer = SessionComposer(
      evaluator: ExerciseEligibilityEvaluator(
        catalogValidator: ExerciseCatalogManifestValidator(
          importedAt: OwnerProgramCatalogSlice.retrievedAt)),
      bindings: OwnerProgramCatalogSlice.bindings
    )

    let genService = SessionGenerationService(source: source, composer: composer)
    let savedService = SavedWorkoutService(historyRepo)

    let controller = AdaptiveGenerationController(
      generationService: genService,
      savedService: savedService,
      historyRepository: historyRepo,
      setupRepository: setupRepo,
      calibrationService: calibrationService,
      profile: "test_user"
    )

    await controller.load()
    // Initially no baselines -> blocked
    let initialResult = await controller.generate()
    XCTAssertNotNil(initialResult)
    XCTAssertFalse(initialResult!.isReady)

    // Calibrate baselines from logs
    let calibrated = await controller.calibrateBaselinesFromLogs()
    XCTAssertTrue(calibrated, "Calibration failed: \(controller.error ?? "unknown")")

    // Training setup should now have the calibrated load for incline_dumbbell_press
    let loadedSetup = try setupRepo.load("test_user")
    XCTAssertNotNil(loadedSetup)
    let dumbbellSetup = loadedSetup?.equipment.first { $0.variation == "incline_dumbbell_press" }
    XCTAssertNotNil(dumbbellSetup)
    XCTAssertTrue(dumbbellSetup?.workingLoads.contains(45_000_000) == true)
    XCTAssertEqual(dumbbellSetup?.label, "Dumbbell Bench 30°")

    // The latest recommendation generated by calibrateBaselinesFromLogs should now be READY
    XCTAssertNotNil(controller.latestRecommendation)
    XCTAssertEqual(controller.latestRecommendation?.status, .ready)
    XCTAssertEqual(controller.latestRecommendation?.slots.count, 6)
    XCTAssertTrue(controller.lastResult?.isReady == true)
  }

  @MainActor
  func testCalibrationProgressCalculationsAndRepositoryTracking() async throws {
    // 1. Value model calculations
    let zero = CalibrationProgress(loggedCount: 0)
    XCTAssertEqual(zero.loggedCount, 0)
    XCTAssertEqual(zero.requiredCount, 7)
    XCTAssertEqual(zero.remainingCount, 7)
    XCTAssertFalse(zero.isUnlocked)
    XCTAssertEqual(zero.percentage, 0)
    XCTAssertEqual(zero.fraction, 0.0)

    let twoDays = CalibrationProgress(loggedCount: 2)
    XCTAssertEqual(twoDays.loggedCount, 2)
    XCTAssertEqual(twoDays.requiredCount, 7)
    XCTAssertEqual(twoDays.remainingCount, 5)
    XCTAssertFalse(twoDays.isUnlocked)
    XCTAssertEqual(twoDays.percentage, 29)
    XCTAssertEqual(twoDays.fraction, 2.0 / 7.0, accuracy: 0.001)

    let completedTrial = CalibrationProgress(loggedCount: 7)
    XCTAssertEqual(completedTrial.loggedCount, 7)
    XCTAssertEqual(completedTrial.remainingCount, 0)
    XCTAssertTrue(completedTrial.isUnlocked)
    XCTAssertEqual(completedTrial.percentage, 100)
    XCTAssertEqual(completedTrial.fraction, 1.0)

    let extraLogs = CalibrationProgress(loggedCount: 10)
    XCTAssertEqual(extraLogs.remainingCount, 0)
    XCTAssertTrue(extraLogs.isUnlocked)
    XCTAssertEqual(extraLogs.percentage, 100)
    XCTAssertEqual(extraLogs.fraction, 1.0)

    // 2. Service and Controller integration with logs repository
    let setupRepo = try SqliteTrainingSetupRepository(path: ":memory:")
    let historyRepo = try SqliteRecommendationHistoryRepository(path: ":memory:")
    let logsRepo = try SqliteProgramLogRepository(path: ":memory:")

    let calibrationService = BaselineCalibrationService(
      programLogsRepository: logsRepo,
      setupRepository: setupRepo,
      profileId: "test_user"
    )

    let source = CoordinatedSessionGenerationSource(
      profile: "test_user",
      setupRepository: setupRepo,
      historyRepository: historyRepo,
      catalog: OwnerProgramCatalogSlice.entries,
      catalogDigest: OwnerProgramCatalogSlice.contentSha256,
      candidateExerciseIds: Array(OwnerProgramCatalogSlice.bindings.exerciseIds.values),
      manifest: OwnerProgramCatalogSlice.manifest,
      preferredSessionId: "monday"
    )

    let composer = SessionComposer(
      evaluator: ExerciseEligibilityEvaluator(
        catalogValidator: ExerciseCatalogManifestValidator(
          importedAt: OwnerProgramCatalogSlice.retrievedAt)),
      bindings: OwnerProgramCatalogSlice.bindings
    )

    let genService = SessionGenerationService(source: source, composer: composer)
    let savedService = SavedWorkoutService(historyRepo)

    let controller = AdaptiveGenerationController(
      generationService: genService,
      savedService: savedService,
      historyRepository: historyRepo,
      setupRepository: setupRepo,
      calibrationService: calibrationService,
      profile: "test_user"
    )

    // Initially 0 logs
    var progress = try calibrationService.getCalibrationProgress()
    XCTAssertEqual(progress.loggedCount, 0)
    XCTAssertEqual(progress.remainingCount, 7)
    XCTAssertFalse(progress.isUnlocked)

    await controller.load()
    XCTAssertEqual(controller.calibrationProgress.loggedCount, 0)
    XCTAssertEqual(controller.calibrationProgress.remainingCount, 7)

    // Seed 2 logged days (matching user's state: "i just logged 2 days")
    let validSet = ProgramSet(
      slot: "incline_dumbbell_press",
      index: 1,
      side: .both,
      variant: "incline_dumbbell_press",
      setup: "Dumbbell Bench 30°",
      convention: .perDumbbell,
      load: 35_000_000,
      reps: 10,
      rir: 2,
      validity: .valid,
      warmup: false,
      skipped: false
    )

    func seedCompletedLog(id: String, day: Int, programId: String) throws {
      let initial = ProgramLog(
        programVersion: ownerProgramVersion,
        endedEarly: false,
        id: id,
        profile: "test_user",
        programId: programId,
        startedAt: Date(timeIntervalSince1970: 1_728_000_000 + Double(day * 86400)),
        revision: 0,
        completedAt: nil,
        sets: []
      )
      try logsRepo.write(initial, expectedRevision: -1, actionId: "seed_start_\(id)")
      let recorded = try initial.record(validSet)
      try logsRepo.write(recorded, expectedRevision: 0, actionId: "seed_set_\(id)")
      let finished = try recorded.finish(
        at: Date(timeIntervalSince1970: 1_728_003_600 + Double(day * 86400)),
        endEarly: true
      )
      try logsRepo.write(finished, expectedRevision: 1, actionId: "seed_finish_\(id)")
    }

    for day in 1...2 {
      try seedCompletedLog(
        id: "log_day_\(day)",
        day: day,
        programId: "monday"
      )
    }

    progress = try calibrationService.getCalibrationProgress()
    XCTAssertEqual(progress.loggedCount, 2)
    XCTAssertEqual(progress.remainingCount, 5)
    XCTAssertEqual(progress.percentage, 29)
    XCTAssertFalse(progress.isUnlocked)

    await controller.load()
    XCTAssertEqual(controller.calibrationProgress.loggedCount, 2)
    XCTAssertEqual(controller.calibrationProgress.remainingCount, 5)
    XCTAssertEqual(controller.calibrationProgress.percentage, 29)
    XCTAssertFalse(controller.calibrationProgress.isUnlocked)

    // Seed remaining 5 logs (days 3 to 7) to reach full 7 days
    for day in 3...7 {
      try seedCompletedLog(
        id: "log_day_\(day)",
        day: day,
        programId: "monday"
      )
    }

    progress = try calibrationService.getCalibrationProgress()
    XCTAssertEqual(progress.loggedCount, 7)
    XCTAssertEqual(progress.remainingCount, 0)
    XCTAssertEqual(progress.percentage, 100)
    XCTAssertTrue(progress.isUnlocked)

    await controller.load()
    XCTAssertEqual(controller.calibrationProgress.loggedCount, 7)
    XCTAssertEqual(controller.calibrationProgress.remainingCount, 0)
    XCTAssertTrue(controller.calibrationProgress.isUnlocked)
  }
}
