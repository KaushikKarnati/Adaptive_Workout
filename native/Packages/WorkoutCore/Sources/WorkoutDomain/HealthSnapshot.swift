import Foundation

/// Imported observations, never verified strength exposures or medical readiness.
public struct HealthObservation: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var category: HealthCategory
  public var source: String
  public var start: Date
  public var end: Date
  public var value: Double?
  public var unit: String
  public init(
    id: String, category: HealthCategory, source: String, start: Date, end: Date,
    value: Double?, unit: String
  ) {
    self.id = id
    self.category = category
    self.source = source
    self.start = start
    self.end = end
    self.value = value
    self.unit = unit
  }
}
public struct HealthSnapshot: Codable, Equatable, Sendable {
  public var schemaVersion = 1
  public var capturedAt: Date
  public var requested: [HealthCategory]
  public var observations: [HealthObservation]
  public init(capturedAt: Date, requested: [HealthCategory], observations: [HealthObservation])
    throws
  {
    self.capturedAt = capturedAt
    self.requested = requested
    self.observations = observations
    try validate()
    // A full replacement snapshot represents deletions and source revisions.
    self.observations.sort { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
  }
  public func validate() throws {
    guard schemaVersion == 1, capturedAt.timeIntervalSince1970.isFinite,
      Set(requested).count == requested.count, observations.count <= 20000,
      Set(observations.map(\.id)).count == observations.count
    else { throw ProfileFailure.invalid }
    for sample in observations {
      guard !sample.id.isEmpty, !sample.source.isEmpty, sample.id.utf8.count <= 128,
        sample.source.utf8.count <= 256, sample.unit.utf8.count <= 80,
        requested.contains(sample.category), sample.start.timeIntervalSince1970.isFinite,
        sample.end.timeIntervalSince1970.isFinite, sample.start <= sample.end,
        sample.end <= capturedAt,
        sample.value == nil || (sample.value!.isFinite && sample.value! >= 0)
      else { throw ProfileFailure.invalid }
    }
  }
  public var unavailableCategories: [HealthCategory] {
    requested.filter { category in !observations.contains { $0.category == category } }
  }
  /// Overlap is exposed, never summed into fabricated sleep duration.
  public var hasOverlappingSleep: Bool {
    let sleep = observations.filter { $0.category == .sleep }.sorted { $0.start < $1.start }
    var latestEnd: Date?
    for sample in sleep {
      if let latestEnd, sample.start < latestEnd { return true }
      latestEnd = max(latestEnd ?? sample.end, sample.end)
    }
    return false
  }
}
