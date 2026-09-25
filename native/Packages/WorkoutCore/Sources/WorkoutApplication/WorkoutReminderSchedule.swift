import Foundation

/// Explicit user-selected wall-clock reminders; never infers training days.
public struct WorkoutReminderSchedule: Equatable, Sendable {
  public let weekdays: [Int]
  public let hour: Int
  public let minute: Int
  public init(weekdays: Set<Int>, hour: Int, minute: Int) throws {
    guard !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }),
      (0...23).contains(hour), (0...59).contains(minute)
    else { throw ReminderError.invalidSchedule }
    self.weekdays = weekdays.sorted()
    self.hour = hour
    self.minute = minute
  }
  public var dates: [DateComponents] {
    weekdays.map { DateComponents(hour: hour, minute: minute, weekday: $0) }
  }
}
private enum ReminderError: Error { case invalidSchedule }
