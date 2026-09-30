import SwiftUI
import UniformTypeIdentifiers
import WorkoutDomain
import WorkoutPersistence

@MainActor final class OnboardingModel: ObservableObject {
  @Published var profile = UserTrainingProfile()
  @Published var error: String?
  @Published var saved = false
  private var repository: SqliteUserTrainingProfileRepository?
  private var durable: UserTrainingProfile?
  var isSaved: Bool { durable == profile }
  init(directory: URL, existingOwner: Bool) {
    do {
      let repository = try SqliteUserTrainingProfileRepository(
        path: directory.appendingPathComponent("user_profiles.sqlite").path)
      self.repository = repository
      if let stored = try repository.currentProfile() {
        profile = stored
        durable = stored
      } else if existingOwner {
        profile = UserTrainingProfile(id: "local_owner")
      }
    } catch { self.error = "Profile storage could not be opened. Existing records are preserved." }
  }
  @discardableResult func save(step: OnboardingStep? = nil) -> Bool {
    var next = profile
    if let step { next.step = step }
    next.revision = durable.map { $0.revision + 1 } ?? 0
    do {
      guard let repository else { throw ProfileFailure.invalid }
      try repository.save(next, expectedRevision: durable?.revision)
      guard try repository.load(next.id) == next else { throw ProfileFailure.invalid }
      durable = next
      profile = next
      error = nil
      saved = true
      return true
    } catch {
      self.error =
        "Could not save setup. Check your entries and retry; previous saved data is preserved."
      saved = false
      return false
    }
  }
}

struct OnboardingView: View {
  @StateObject private var model: OnboardingModel
  @Environment(\.dismiss) private var dismiss
  @StateObject private var health = HealthImportModel()
  @State private var exportDocument: ProfileDocument?
  @State private var exporting = false
  @State private var importing = false
  init(directory: URL, existingOwner: Bool) {
    _model = StateObject(
      wrappedValue: OnboardingModel(directory: directory, existingOwner: existingOwner))
  }
  var body: some View {
    Form {
      Section {
        Text("Make training yours").font(.title2.bold())
        Text("Step \(model.profile.step.rawValue + 1) of 10 · saved on this device")
        ProgressView(value: Double(model.profile.step.rawValue + 1), total: 10)
      }
      content
      if let error = model.error { Section { Text(error).foregroundStyle(.red) } }
      Section {
        Button("Save progress") { model.save() }.accessibilityIdentifier("onboarding_save")
        if model.isSaved { Text("Saved on this device").foregroundStyle(.secondary) }
        if model.profile.step != .welcome {
          Button("Back") {
            model.save(step: OnboardingStep(rawValue: model.profile.step.rawValue - 1))
          }
        }
        if model.profile.step != .review {
          Button("Save and continue") {
            model.save(step: OnboardingStep(rawValue: model.profile.step.rawValue + 1))
          }
        } else {
          Button("Save preferences and return") {
            model.profile.preferencesReviewed = true
            if model.save() { dismiss() }
          }
        }
      }
    }
    .fileExporter(
      isPresented: $exporting, document: exportDocument, contentType: .json,
      defaultFilename: "training-profile"
    ) { result in
      if case .failure = result { model.error = "Export could not complete." }
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
      do {
        let url = try result.get()
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 1_000_000 else { throw ProfileFailure.invalid }
        let data = try Data(contentsOf: url)
        guard data.count <= 1_000_000 else { throw ProfileFailure.invalid }
        var restored = try JSONDecoder().decode(UserTrainingProfile.self, from: data)
        try restored.validate()
        // Restore preferences to this profile, never identities, health observations or evidence.
        restored.id = model.profile.id
        restored.step = .review
        restored.preferencesReviewed = false
        let prior = model.profile
        model.profile = restored
        if !model.save() { model.profile = prior }
      } catch {
        model.error = "Restore rejected. Saved preferences and workout records are unchanged."
      }
    }
    .onChange(of: model.profile.healthCategories) { _, _ in health.clear() }
    .navigationTitle("Training setup")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Pause") { if model.save() { dismiss() } }
      }
    }
  }
  @ViewBuilder private var content: some View {
    switch model.profile.step {
    case .welcome:
      Section("Local, personal, explainable") {
        Text(
          "Choose your goals and prepare your program. Adaptive workouts require verified setup for the entire program. You can pause at any time."
        )
        Text(
          "No account is required. Manual records remain separate from verified training evidence.")
      }
    case .goals:
      Section("Goals and experience") {
        Picker("Primary goal", selection: $model.profile.goal) {
          Text("Choose").tag(nil as TrainingGoal?)
          ForEach(TrainingGoal.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
        }
        .accessibilityIdentifier("onboarding_goal")
        Picker("Training experience", selection: $model.profile.experience) {
          Text("Choose").tag(nil as TrainingExperience?)
          ForEach(TrainingExperience.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
        }
        ForEach(TrainingGoal.allCases.filter { $0 != model.profile.goal }, id: \.self) { goal in
          Toggle(
            "Also: \(goal.title)",
            isOn: Binding(
              get: { model.profile.secondaryGoals.contains(goal) },
              set: { enabled in
                model.profile.secondaryGoals.removeAll { $0 == goal }
                if enabled { model.profile.secondaryGoals.append(goal) }
              }))
        }
        Text(
          "These are preferences. Goal and experience mappings still require review before recommendations."
        )
      }.onChange(of: model.profile.goal) { _, goal in
        model.profile.secondaryGoals.removeAll { $0 == goal }
      }
    case .schedule:
      Section("When you train") {
        ForEach(1...7, id: \.self) { day in
          Toggle(
            ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day - 1],
            isOn: Binding(
              get: { model.profile.weekdays.contains(day) },
              set: { enabled in
                model.profile.weekdays.removeAll { $0 == day }
                if enabled { model.profile.weekdays.append(day) }
              }))
        }
        TextField("Preferred minutes", value: $model.profile.minutes, format: .number).keyboardType(
          .numberPad)
        Text("Duration is advisory. Missed days do not create catch-up work.")
      }
    case .environment:
      Section("Training environment") {
        TextField("Gym or home label", text: $model.profile.environment)
        Picker("Load units", selection: $model.profile.units) {
          Text("Pounds").tag("lb")
          Text("Kilograms").tag("kg")
        }
        ForEach(SetupTaxonomy.equipmentIds.sorted(), id: \.self) { item in
          Toggle(
            item,
            isOn: Binding(
              get: { model.profile.equipment.contains(item) },
              set: { enabled in
                model.profile.equipment.removeAll { $0 == item }
                if enabled { model.profile.equipment.append(item) }
              }))
        }
        Text(
          "Inventory is a preference, not physical setup verification. Units here do not reinterpret historical loads."
        )
      }
    case .constraints:
      Section("Movement constraints") {
        Picker("Current pain or concerning symptoms", selection: $model.profile.symptomReported) {
          Text("Not answered").tag(nil as Bool?)
          Text("Reported").tag(Optional(true))
          Text("None reported").tag(Optional(false))
        }
        TextField(
          "Relevant movement limitations (optional)", text: $model.profile.limitations,
          axis: .vertical)
        TextField(
          "Movements to exclude (optional)", text: $model.profile.exclusions, axis: .vertical)
        Text(
          "Only provide information relevant to training. These reports do not establish medical clearance. Symptoms block adaptive activation pending the reviewed safety process."
        )
      }
    case .program:
      Section("Program draft") {
        Text(
          "Edits guide future adaptation. Locks must be preserved or produce a conflict. Drafts do not alter existing logged prescriptions."
        )
        if model.profile.sessions.isEmpty {
          Button("Use owner five-session program as a draft") {
            model.profile.sessions = UserTrainingProfile.ownerDraft()
          }
        }
        Button("Add session") { model.profile.sessions.append(DraftSession()) }
        ForEach($model.profile.sessions) { $session in
          NavigationLink {
            DraftSessionEditor(session: $session)
          } label: {
            Text(session.title + " · \(session.exercises.count) exercises")
          }
        }.onDelete { model.profile.sessions.remove(atOffsets: $0) }
          .onMove { model.profile.sessions.move(fromOffsets: $0, toOffset: $1) }
        Text(
          "Automatic program creation is unavailable until catalog and goal/experience reviews are complete."
        )
      }.toolbar { EditButton() }
    case .equipment:
      Section("Full equipment verification") {
        Text(
          "Each executable variation needs a stable setup, load convention, available work/rehearsal settings and reviewed capabilities. Inventory selections do not satisfy this requirement."
        )
        ForEach(model.profile.sessions) { session in
          DisclosureGroup(session.title) {
            ForEach(session.exercises) { Text($0.name + " · verification required") }
          }
        }
        Text(
          "Verified setup cannot be completed in this version. Saved preferences do not enable adaptive workouts."
        )
      }
    case .baselines:
      Section("Starting targets and rehearsals") {
        Text(
          "Starting targets must be explicitly confirmed against current verified equipment. Rehearsals and safety evidence must also be reviewed. Manual or imported sets never automatically become baselines."
        )
        Text(
          "Starting-target verification is not available in this version.")
      }
    case .health:
      Section("Optional Apple Health preferences") {
        Text(
          "Choose optional categories to read from Apple Health. Observations stay in memory for this setup session; no health metric changes your workout."
        )
        ForEach(HealthCategory.allCases, id: \.self) { item in
          Toggle(
            item.title,
            isOn: Binding(
              get: { model.profile.healthCategories.contains(item) },
              set: { enabled in
                model.profile.healthCategories.removeAll { $0 == item }
                if enabled { model.profile.healthCategories.append(item) }
              }))
        }
      }
      Section("Apple Health connection") {
        Button("Connect and refresh Apple Health") {
          if model.save() {
            Task { await health.connect(categories: model.profile.healthCategories) }
          }
        }.disabled(health.busy || model.profile.healthCategories.isEmpty)
        Text(health.status)
        if let snapshot = health.snapshot {
          Text(
            "Unavailable categories: \(snapshot.unavailableCategories.map(\.rawValue).joined(separator: ", "))"
          )
          if snapshot.hasOverlappingSleep {
            Text("Overlapping sleep sources require reviewed interpretation.")
          }
          Button("Clear imported observations") { health.clear() }
        }
      }
    case .review:
      Section("Local backup") {
        Button("Export saved preferences and program draft") {
          if model.save() {
            do {
              exportDocument = ProfileDocument(data: try JSONEncoder().encode(model.profile))
              exporting = true
            } catch { model.error = "Export could not be prepared." }
          }
        }
        Button("Restore preferences from a backup") { importing = true }
        Text(
          "Restore replaces this profile’s preferences with a new revision. It does not import workout history, health samples or verified training evidence."
        )
      }
      Section("Review preferences") {
        Text("Goal: \(model.profile.goal?.title ?? "Not selected")")
        Text("Experience: \(model.profile.experience?.title ?? "Not selected")")
        Text(
          "\(model.profile.weekdays.count) training days · \(model.profile.sessions.count) draft sessions"
        )
        Text("Adaptive workouts are not enabled").font(.headline)
        ForEach(model.profile.activationBlockers, id: \.self) { Text($0) }
        Text(
          "Saving this review acknowledges preferences only. Complete-program verification is still mandatory."
        )
      }
    }
  }
}
private struct DraftSessionEditor: View {
  @Binding var session: DraftSession
  var body: some View {
    Form {
      TextField("Session title", text: $session.title)
      Toggle("Lock session structure", isOn: $session.locked)
      ForEach($session.exercises) { $exercise in
        DisclosureGroup(exercise.name.isEmpty ? "New exercise" : exercise.name) {
          TextField("Exercise name (manual draft)", text: $exercise.name)
          Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...20)
          Stepper("Minimum reps: \(exercise.minReps)", value: $exercise.minReps, in: 1...100)
          Stepper("Maximum reps: \(exercise.maxReps)", value: $exercise.maxReps, in: 1...100)
          Stepper(
            "Rest: \(exercise.restSeconds) seconds", value: $exercise.restSeconds, in: 0...3600,
            step: 15)
          TextField(
            "Superset group (optional)",
            text: Binding(
              get: { exercise.pair ?? "" }, set: { exercise.pair = $0.isEmpty ? nil : $0 }))
          Toggle("Lock exercise", isOn: $exercise.locked)
        }
      }.onDelete { session.exercises.remove(atOffsets: $0) }
        .onMove { session.exercises.move(fromOffsets: $0, toOffset: $1) }
      Button("Add exercise") { session.exercises.append(DraftExercise()) }
      Text(
        "Names are manual draft labels, not reviewed catalog bindings. Return to setup and save to persist edits."
      )
    }.navigationTitle("Edit session").toolbar { EditButton() }
  }
}

private struct ProfileDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else { throw ProfileFailure.invalid }
    self.data = data
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
