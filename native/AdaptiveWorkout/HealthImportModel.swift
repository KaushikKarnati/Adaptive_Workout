import Foundation
import HealthKit
import WorkoutDomain

@MainActor final class HealthImportModel: ObservableObject {
  @Published private(set) var status = "Not connected"
  @Published private(set) var snapshot: HealthSnapshot?
  @Published private(set) var busy = false
  private let store = HKHealthStore()
  private func type(_ category: HealthCategory) -> HKSampleType {
    switch category {
    case .workouts: HKObjectType.workoutType()
    case .sleep: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    case .hrv: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    case .restingHeartRate: HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
    case .steps: HKObjectType.quantityType(forIdentifier: .stepCount)!
    case .activeEnergy: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    case .weight: HKObjectType.quantityType(forIdentifier: .bodyMass)!
    case .bodyFat: HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
    case .leanMass: HKObjectType.quantityType(forIdentifier: .leanBodyMass)!
    }
  }
  private func unit(_ category: HealthCategory) -> HKUnit? {
    switch category {
    case .hrv: .secondUnit(with: .milli)
    case .restingHeartRate: .count().unitDivided(by: .minute())
    case .steps: .count()
    case .activeEnergy: .kilocalorie()
    case .weight, .leanMass: .gramUnit(with: .kilo)
    case .bodyFat: .percent()
    default: nil
    }
  }
  func connect(categories: [HealthCategory]) async {
    guard !busy else { return }
    guard HKHealthStore.isHealthDataAvailable(), !categories.isEmpty else {
      status = "Health data unavailable or no categories selected"
      return
    }
    busy = true
    defer { busy = false }
    do {
      try await store.requestAuthorization(toShare: [], read: Set(categories.map { type($0) }))
      let now = Date()
      let since = Calendar(identifier: .gregorian).date(byAdding: .day, value: -30, to: now)!
      var observations: [HealthObservation] = []
      for category in categories {
        let samples = try await read(category, since: since, through: now)
        for sample in samples {
          let quantity = sample as? HKQuantitySample
          let categorySample = sample as? HKCategorySample
          // Raw category values preserve sleep stage; never sum overlapping sources.
          let value =
            quantity.flatMap { sample in unit(category).map { sample.quantity.doubleValue(for: $0) }
            }
            ?? categorySample.map { Double($0.value) }
          observations.append(
            HealthObservation(
              id: sample.uuid.uuidString, category: category,
              source: sample.sourceRevision.source.bundleIdentifier, start: sample.startDate,
              end: sample.endDate, value: value,
              unit: unit(category)?.unitString ?? (category == .sleep ? "sleepStage" : "workout")))
        }
      }
      snapshot = try HealthSnapshot(
        capturedAt: now, requested: categories, observations: observations)
      status =
        "Read \(observations.count) observations from the last 30 days. No data may mean absent samples or unavailable read access. Recovery interpretation is not activated."
    } catch {
      status =
        "Health import could not complete. Previous snapshot is unchanged; manual workouts remain available."
    }
  }
  func clear() {
    snapshot = nil
    status = "Imported observations cleared from this session"
  }
  private func read(_ category: HealthCategory, since: Date, through: Date) async throws
    -> [HKSample]
  {
    try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type(category),
        predicate: HKQuery.predicateForSamples(
          withStart: since, end: through, options: [.strictEndDate]),
        limit: 20001, sortDescriptors: nil
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: samples ?? [])
        }
      }
      store.execute(query)
    }
  }
}
