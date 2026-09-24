import Foundation

public func sessionElapsed(start: Date, end: Date?, now: Date) -> TimeInterval {
  let elapsed = (end ?? now).timeIntervalSince(start)
  return elapsed.isFinite ? max(0, elapsed) : 0
}

public func timerText(_ duration: TimeInterval) -> String {
  guard duration.isFinite else { return "00:00" }
  let seconds = floor(max(0, duration))
  return String(
    format: "%02.0f:%02.0f", floor(seconds / 60), seconds.truncatingRemainder(dividingBy: 60))
}

/// Presentation state only: never consumed as training evidence.
public struct RestCountdown: Sendable {
  public private(set) var deadline: Date?
  public init() {}
  public var started: Bool { deadline != nil }
  public mutating func start(seconds: Int, now: Date) throws {
    guard seconds > 0 else { throw TimingError.invalidRest }
    let target = now.addingTimeInterval(Double(seconds))
    guard now.timeIntervalSince1970.isFinite, target.timeIntervalSince1970.isFinite else {
      throw TimingError.invalidTime
    }
    deadline = target
  }
  public mutating func clear() { deadline = nil }
  public func remaining(now: Date) -> TimeInterval {
    let seconds = deadline?.timeIntervalSince(now) ?? 0
    return seconds.isFinite ? ceil(max(0, seconds)) : 0
  }
}
public enum TimingError: Error { case invalidRest, invalidTime }
