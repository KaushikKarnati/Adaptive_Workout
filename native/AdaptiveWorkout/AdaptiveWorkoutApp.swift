import SwiftUI
import WorkoutApplication
import WorkoutDomain
import WorkoutPersistence

@main
struct AdaptiveWorkoutApp: App {
  @StateObject private var model = AppModel()
  var body: some Scene {
    WindowGroup {
      Group {
        if let controller = model.controller {
          HomeView(controller: controller, model: model)
        } else {
          VStack(spacing: 20) {
            Text("Adaptive Workout").font(.largeTitle.bold())
            Text(model.error ?? "Opening your workouts…")
            if model.error != nil { Button("Try again") { model.open() } }
          }.padding()
        }
      }
      .preferredColorScheme(
        model.appearance == "system" ? nil : model.appearance == "dark" ? .dark : .light
      )
      .task { if model.controller == nil { model.open() } }
    }
  }
}

@MainActor
final class AppModel: ObservableObject {
  @Published var controller: ProgramLogController?
  @Published var error: String?
  @Published private(set) var appearance = "system"
  @Published private(set) var hapticsEnabled = true
  private var appearanceRepository: SqliteAppearanceRepository?
  private var preferences = UserDefaults.standard
  private let hostedIdentity = UUID().uuidString
  private var resetPerformed = false
  private(set) var directory: URL = FileManager.default.urls(
    for: .documentDirectory, in: .userDomainMask)[0]
  func open() {
    do {
      #if DEBUG
        let allowsTesting = true
      #else
        let allowsTesting = false
      #endif
      let context = try StorageLaunchContext(
        documents: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
        arguments: ProcessInfo.processInfo.arguments,
        hostedTest: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
        allowsTesting: allowsTesting, hostedIdentity: hostedIdentity)
      directory = context.directory
      if let domain = context.preferencesDomain {
        guard let scoped = UserDefaults(suiteName: domain) else {
          throw AppFailure.storageUnavailable
        }
        preferences = scoped
        if context.resetFixture && !resetPerformed {
          if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
          }
          scoped.removePersistentDomain(forName: domain)
          resetPerformed = true
        }
      } else {
        preferences = .standard
      }
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let stores = try LocalAppStores(directory: directory)
      controller = ProgramLogController(repository: stores.programLogs)
      hapticsEnabled = preferences.object(forKey: "adaptiveWorkout.hapticsEnabled") as? Bool ?? true
      applyAppearance(stores.appearance)
    } catch { self.error = "Could not open local storage. Existing data has been preserved." }
  }
  func retryAppearance() {
    applyAppearance(LocalAppStores.loadAppearance(directory: directory))
  }
  private func applyAppearance(_ result: Result<LocalAppStores.LoadedAppearance, Error>) {
    switch result {
    case .success(let loaded):
      appearanceRepository = loaded.repository
      appearance = loaded.preference.rawValue
      error = nil
    case .failure:
      appearanceRepository = nil
      error = "Your saved appearance could not be loaded. Workouts remain available. Try again."
    }
  }
  var appearanceBinding: Binding<String> {
    Binding(
      get: { self.appearance },
      set: { value in
        guard value != self.appearance, let selection = AppAppearance(rawValue: value) else {
          return
        }
        do {
          guard let repository = self.appearanceRepository else {
            throw AppFailure.storageUnavailable
          }
          try repository.save(selection)
          self.appearance = try repository.load().rawValue
          self.cue(.selection)
        } catch {
          self.error = "Appearance could not be saved. Try again."
          self.cue(.error)
        }
      })
  }
  var hapticsBinding: Binding<Bool> {
    Binding(
      get: { self.hapticsEnabled },
      set: { value in
        guard value != self.hapticsEnabled else { return }
        self.preferences.set(value, forKey: "adaptiveWorkout.hapticsEnabled")
        self.hapticsEnabled = value
        if value { self.cue(.selection) }
      })
  }
  func cue(_ kind: Cue) {
    guard hapticsEnabled, UIApplication.shared.applicationState == .active else { return }
    switch kind {
    case .selection: UISelectionFeedbackGenerator().selectionChanged()
    case .impact: UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
    case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
  }
  enum Cue { case selection, impact, success, warning, error }
}
private enum AppFailure: Error { case storageUnavailable }
