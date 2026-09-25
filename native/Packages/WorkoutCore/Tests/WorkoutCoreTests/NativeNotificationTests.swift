#if canImport(AdaptiveWorkout) && canImport(UIKit)
  @testable import AdaptiveWorkout
  import Foundation
  import UserNotifications
  import XCTest

  @MainActor
  private final class NotificationClientDouble: WorkoutNotificationClient {
    enum Failure: Error { case rejected }
    var authorized = true
    var authorizationError = false
    var authorizationCalls = 0
    var failAddNumber: Int?
    var suspend = false
    var requests: [UNNotificationRequest] = []
    var pending: [String: UNNotificationRequest] = [:]
    var removed: [String] = []
    var deliveredRemoved: [String] = []
    var suspended: [String: CheckedContinuation<Void, Error>] = [:]
    func setDelegate(_ delegate: any UNUserNotificationCenterDelegate) {}
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
      authorizationCalls += 1
      if authorizationError { throw Failure.rejected }
      return authorized
    }
    func add(_ request: UNNotificationRequest) async throws {
      requests.append(request)
      if failAddNumber == requests.count { throw Failure.rejected }
      if suspend {
        try await withCheckedThrowingContinuation { suspended[request.identifier] = $0 }
      }
      pending[request.identifier] = request
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
      removed += identifiers
      for id in identifiers { pending.removeValue(forKey: id) }
    }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
      deliveredRemoved += identifiers
    }
    func release(_ id: String) { suspended.removeValue(forKey: id)?.resume() }
  }

  final class NativeNotificationTests: XCTestCase {
    @MainActor private func fixture() -> (
      WorkoutNotifications, NotificationClientDouble, UserDefaults
    ) {
      let name = "AdaptiveWorkout.NotificationTests." + UUID().uuidString
      let preferences = UserDefaults(suiteName: name)!
      addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
      let client = NotificationClientDouble()
      let model = WorkoutNotifications(center: client)
      model.configure(preferences: preferences, fixture: false)
      return (model, client, preferences)
    }
    @MainActor private func settle(_ predicate: () -> Bool) async {
      for _ in 0..<1000 {
        if predicate() { return }
        await Task.yield()
      }
      XCTFail("Notification task did not settle")
    }
    @MainActor func testAllowedRemindersPersistExactDaysAndLocalTimeAndCanBeDisabled() async throws
    {
      let (model, client, preferences) = fixture()
      model.restAlerts = true
      model.reminders = true
      model.weekdays = [2, 6]
      model.time = try XCTUnwrap(Calendar.current.date(from: DateComponents(hour: 18, minute: 25)))
      await model.save()
      XCTAssertEqual(client.authorizationCalls, 1)
      XCTAssertEqual(
        client.requests.map(\.identifier), ["adaptive.workout.2", "adaptive.workout.6"])
      for request in client.requests {
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 18)
        XCTAssertEqual(trigger.dateComponents.minute, 25)
        XCTAssertNil(trigger.dateComponents.timeZone)
        XCTAssertEqual(
          request.content.body, "Ready when you are. Open your workout when it suits you.")
      }
      XCTAssertTrue(preferences.bool(forKey: "notifications.rest"))
      XCTAssertTrue(preferences.bool(forKey: "notifications.workouts"))
      XCTAssertEqual(preferences.array(forKey: "notifications.days") as? [Int], [2, 6])
      XCTAssertEqual(preferences.integer(forKey: "notifications.minutes"), 1105)
      let reopened = WorkoutNotifications(center: client)
      reopened.configure(preferences: preferences, fixture: false)
      XCTAssertEqual(reopened.weekdays, [2, 6])
      XCTAssertEqual(Calendar.current.component(.minute, from: reopened.time), 25)
      reopened.reminders = false
      reopened.restAlerts = false
      await reopened.save()
      XCTAssertTrue(client.pending.isEmpty)
      XCTAssertEqual(client.authorizationCalls, 1)
      XCTAssertFalse(preferences.bool(forKey: "notifications.workouts"))
    }
    @MainActor func testMissingDaysAndDeniedPermissionDoNotPersistOrReplaceRequests() async {
      let (model, client, preferences) = fixture()
      model.reminders = true
      await model.save()
      XCTAssertEqual(client.authorizationCalls, 0)
      XCTAssertTrue(client.removed.isEmpty)
      model.weekdays = [2]
      client.authorized = false
      await model.save()
      XCTAssertTrue(client.requests.isEmpty)
      XCTAssertTrue(client.removed.isEmpty)
      XCTAssertFalse(preferences.bool(forKey: "notifications.workouts"))
      XCTAssertEqual(model.message, "Allow notifications in iPhone Settings to receive alerts.")
      XCTAssertFalse(model.busy)
    }
    @MainActor func testSchedulingFailureClearsPartialRequestsAndRetainsRetryChoices() async {
      let (model, client, preferences) = fixture()
      model.reminders = true
      model.weekdays = [2, 4]
      client.failAddNumber = 2
      await model.save()
      XCTAssertTrue(client.pending.isEmpty)
      XCTAssertTrue(model.reminders)
      XCTAssertEqual(model.weekdays, [2, 4])
      XCTAssertFalse(preferences.bool(forKey: "notifications.workouts"))
      XCTAssertNotNil(model.message)
      client.failAddNumber = nil
      await model.save()
      XCTAssertEqual(Set(client.pending.keys), ["adaptive.workout.2", "adaptive.workout.4"])
      XCTAssertTrue(preferences.bool(forKey: "notifications.workouts"))
    }
    @MainActor func testAuthorizationFailureDoesNotRemoveExistingSchedule() async {
      let (model, client, preferences) = fixture()
      model.reminders = true
      model.weekdays = [3]
      await model.save()
      let removals = client.removed
      client.authorizationError = true
      await model.save()
      XCTAssertEqual(client.removed, removals)
      XCTAssertEqual(Set(client.pending.keys), ["adaptive.workout.3"])
      XCTAssertTrue(preferences.bool(forKey: "notifications.workouts"))
    }
    @MainActor func testRestReplacementCancelsLateOldRequestWithoutCancellingNewRequest()
      async throws
    {
      let (model, client, preferences) = fixture()
      preferences.set(true, forKey: "notifications.rest")
      client.suspend = true
      model.startRest(seconds: 120)
      await settle { client.requests.count == 1 }
      let first = try XCTUnwrap(client.requests.first?.identifier)
      model.startRest(seconds: 60)
      await settle { client.requests.count == 2 }
      let second = try XCTUnwrap(client.requests.last?.identifier)
      client.release(second)
      await settle { client.pending[second] != nil }
      client.release(first)
      await settle { client.removed.filter { $0 == first }.count == 2 }
      XCTAssertEqual(Set(client.pending.keys), [second])
      let trigger = try XCTUnwrap(
        client.pending[second]?.trigger as? UNTimeIntervalNotificationTrigger)
      XCTAssertEqual(trigger.timeInterval, 60)
      XCTAssertFalse(trigger.repeats)
      model.clearRest()
      XCTAssertTrue(client.pending.isEmpty)
      XCTAssertTrue(client.deliveredRemoved.contains(second))
      XCTAssertNil(preferences.string(forKey: "notifications.restID"))
    }
    @MainActor func testRestFailureDisabledStateAndRelaunchCleanup() async throws {
      let (model, client, preferences) = fixture()
      model.startRest(seconds: 60)
      await Task.yield()
      XCTAssertTrue(client.requests.isEmpty)
      preferences.set(true, forKey: "notifications.rest")
      model.startRest(seconds: 0)
      XCTAssertTrue(client.requests.isEmpty)
      client.failAddNumber = 1
      model.startRest(seconds: 60)
      await settle { model.restError != nil }
      XCTAssertTrue(client.pending.isEmpty)
      client.failAddNumber = nil
      model.startRest(seconds: 60)
      await settle { client.pending.count == 1 }
      let id = try XCTUnwrap(preferences.string(forKey: "notifications.restID"))
      let reopened = WorkoutNotifications(center: client)
      reopened.configure(preferences: preferences, fixture: false)
      XCTAssertTrue(client.pending.isEmpty)
      XCTAssertTrue(client.removed.contains(id))
      XCTAssertNil(preferences.string(forKey: "notifications.restID"))
    }
    @MainActor func testBusySaveRejectsCompetingSubmission() async throws {
      let (model, client, _) = fixture()
      model.reminders = true
      model.weekdays = [2]
      client.suspend = true
      let saving = Task { await model.save() }
      await settle { client.requests.count == 1 }
      XCTAssertTrue(model.busy)
      await model.save()
      XCTAssertEqual(client.authorizationCalls, 1)
      XCTAssertEqual(client.requests.count, 1)
      client.release(try XCTUnwrap(client.requests.first?.identifier))
      await saving.value
      XCTAssertFalse(model.busy)
      XCTAssertEqual(client.pending.count, 1)
    }
    @MainActor func testFixtureModeNeverTouchesSystemNotifications() async {
      let (model, client, preferences) = fixture()
      model.configure(preferences: preferences, fixture: true)
      model.reminders = true
      model.restAlerts = true
      model.weekdays = [1]
      preferences.set(true, forKey: "notifications.rest")
      await model.save()
      model.startRest(seconds: 60)
      model.clearRest()
      await Task.yield()
      XCTAssertEqual(client.authorizationCalls, 0)
      XCTAssertTrue(client.requests.isEmpty)
      XCTAssertTrue(client.removed.isEmpty)
      XCTAssertTrue(client.deliveredRemoved.isEmpty)
    }
  }
#endif
