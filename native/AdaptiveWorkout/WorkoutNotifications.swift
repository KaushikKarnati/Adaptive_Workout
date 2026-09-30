import SwiftUI
import UserNotifications
import WorkoutApplication

/// Injectable system boundary so permission, failures and cancellation can be tested without alerts.
@MainActor
protocol WorkoutNotificationClient: AnyObject {
  func setDelegate(_ delegate: any UNUserNotificationCenterDelegate)
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
  func add(_ request: UNNotificationRequest) async throws
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])
  func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemWorkoutNotificationClient: WorkoutNotificationClient {
  private let center = UNUserNotificationCenter.current()
  func setDelegate(_ delegate: any UNUserNotificationCenterDelegate) { center.delegate = delegate }
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    try await center.requestAuthorization(options: options)
  }
  func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
  }
  func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
  }
}

/// Local notifications contain no workout measurements or health details.
@MainActor
final class WorkoutNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
  @Published var restAlerts = false
  @Published var reminders = false
  @Published var weekdays: Set<Int> = []
  @Published var time = Calendar.current.date(from: DateComponents(hour: 18)) ?? Date()
  @Published private(set) var busy = false
  @Published private(set) var message: String?
  @Published private(set) var restError: String?
  private let center: any WorkoutNotificationClient
  private var preferences = UserDefaults.standard
  private var fixture = false
  private var restID: String?
  private let restPrefix = "adaptive.rest."
  private let reminderIDs = (1...7).map { "adaptive.workout.\($0)" }

  init(center: any WorkoutNotificationClient = SystemWorkoutNotificationClient()) {
    self.center = center
    super.init()
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func configure(preferences: UserDefaults, fixture: Bool) {
    self.preferences = preferences
    self.fixture = fixture
    if !fixture {
      center.setDelegate(self)
      // The on-screen countdown is in-memory. Cancel its former request on relaunch.
      restID = preferences.string(forKey: "notifications.restID")
      clearRest()
    }
    restAlerts = preferences.bool(forKey: "notifications.rest")
    reminders = preferences.bool(forKey: "notifications.workouts")
    weekdays = Set(
      (preferences.array(forKey: "notifications.days") as? [Int] ?? []).filter {
        (1...7).contains($0)
      })
    if let minutes = preferences.object(forKey: "notifications.minutes") as? Int,
      (0..<1440).contains(minutes)
    {
      time =
        Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60))
        ?? time
    }
  }

  private func authorize() async throws -> Bool {
    if fixture { return false }
    return try await center.requestAuthorization(options: [.alert, .sound])
  }

  func save() async {
    guard !busy else { return }
    guard !fixture else {
      message = "Notifications are disabled in test fixtures."
      return
    }
    guard !reminders || !weekdays.isEmpty else {
      message = "Choose at least one reminder day."
      return
    }
    busy = true
    defer { busy = false }
    var replacedReminders = false
    do {
      if restAlerts || reminders {
        guard try await authorize() else {
          message = "Allow notifications in iPhone Settings to receive alerts."
          return
        }
      }
      center.removePendingNotificationRequests(withIdentifiers: reminderIDs)
      replacedReminders = true
      if reminders {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let schedule = try WorkoutReminderSchedule(
          weekdays: weekdays,
          hour: components.hour ?? 0, minute: components.minute ?? 0)
        for date in schedule.dates {
          let day = date.weekday!
          let content = UNMutableNotificationContent()
          content.title = "Workout reminder"
          content.body = "Ready when you are. Open your workout when it suits you."
          content.sound = .default
          let trigger = UNCalendarNotificationTrigger(
            dateMatching: date,
            repeats: true)
          try await center.add(
            UNNotificationRequest(
              identifier: "adaptive.workout.\(day)", content: content, trigger: trigger))
        }
      }
      preferences.set(restAlerts, forKey: "notifications.rest")
      preferences.set(reminders, forKey: "notifications.workouts")
      preferences.set(weekdays.sorted(), forKey: "notifications.days")
      let components = Calendar.current.dateComponents([.hour, .minute], from: time)
      preferences.set(
        (components.hour ?? 0) * 60 + (components.minute ?? 0), forKey: "notifications.minutes")
      if !restAlerts { clearRest() }
      message = "Notification settings saved."
    } catch {
      if replacedReminders {
        center.removePendingNotificationRequests(withIdentifiers: reminderIDs)
        preferences.set(false, forKey: "notifications.workouts")
      }
      message =
        replacedReminders
        ? "Reminders could not be scheduled and are off. Your choices are kept; try saving again."
        : "Could not save notification settings. Please try again."
    }
  }

  func startRest(seconds: Int) {
    clearRest()
    guard preferences.bool(forKey: "notifications.rest"), !fixture, seconds > 0 else { return }
    let id = restPrefix + UUID().uuidString
    restID = id
    preferences.set(id, forKey: "notifications.restID")
    let content = UNMutableNotificationContent()
    content.title = "Rest complete"
    content.body = "Your rest timer has finished."
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: id, content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false))
    Task {
      do {
        try await center.add(request)
        if restID != id { center.removePendingNotificationRequests(withIdentifiers: [id]) }
      } catch {
        if restID == id {
          restError = "Rest alert could not be scheduled. The on-screen timer is still available."
        }
      }
    }
  }

  func clearRest() {
    restError = nil
    if let restID {
      center.removePendingNotificationRequests(withIdentifiers: [restID])
      center.removeDeliveredNotifications(withIdentifiers: [restID])
    }
    restID = nil
    preferences.removeObject(forKey: "notifications.restID")
  }
}

struct NotificationSettingsView: View {
  @ObservedObject var model: WorkoutNotifications
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle("Rest timer alerts", isOn: $model.restAlerts)
      Toggle("Workout reminders", isOn: $model.reminders)
      if model.reminders {
        ForEach(1...7, id: \.self) { day in
          Toggle(
            Calendar.current.weekdaySymbols[day - 1],
            isOn: Binding(
              get: { model.weekdays.contains(day) },
              set: { if $0 { model.weekdays.insert(day) } else { model.weekdays.remove(day) } }))
        }
        DatePicker("Reminder time", selection: $model.time, displayedComponents: .hourAndMinute)
      }
      Text(
        "Reminders follow your chosen days and local time. They do not select or start workouts."
      ).font(.caption)
      Button("Save notifications") { Task { await model.save() } }
      if let message = model.message { Text(message).font(.caption) }
      Link(
        "Open iPhone notification settings",
        destination: URL(string: UIApplication.openNotificationSettingsURLString)!)
    }.disabled(model.busy).buttonStyle(.borderless)
  }
}

struct RestNotificationStatus: View {
  @ObservedObject var model: WorkoutNotifications
  var body: some View {
    if let error = model.restError { Text(error).font(.caption).foregroundStyle(.red) }
  }
}
