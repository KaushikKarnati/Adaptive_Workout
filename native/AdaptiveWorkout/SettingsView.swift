import SwiftUI
import WorkoutDomain
import WorkoutPersistence

struct SettingsView: View {
  let directory: URL
  @ObservedObject var notifications: WorkoutNotifications
  let exerciseReferences: [WgerReference]
  @Binding var appearance: String
  @Binding var hapticsEnabled: Bool
  var cue: (AppModel.Cue) -> Void = { _ in }
  var body: some View {
    NavigationView {
      Form {
        Section {
          DisclosureGroup("Appearance and feedback") {
            Picker("Appearance", selection: $appearance) {
              Text("System").tag("system")
              Text("Light").tag("light")
              Text("Dark").tag("dark")
            }.accessibilityIdentifier("appearance_picker")
            Toggle("Haptic feedback", isOn: $hapticsEnabled)
          }
        }
        Section {
          DisclosureGroup("Your program") {
            Text("Approved prescriptions. Actual records stay separate from recommendations.").font(
              .caption
            ).foregroundColor(.secondary)
            ForEach(ownerProgram, id: \.id) { session in
              DisclosureGroup(session.day + ": " + session.title) {
                ForEach(Array(session.blocks.enumerated()), id: \.offset) { _, block in
                  VStack(alignment: .leading, spacing: 6) {
                    if block.exercises.count == 2 {
                      Text("Superset · 3 paired rounds").font(.caption.bold())
                    }
                    ForEach(block.exercises, id: \.id) { exercise in
                      Text(exercise.name).font(.subheadline.bold())
                      Text(
                        "\(exercise.sets) sets · \(exercise.minReps)–\(exercise.maxReps) reps\(exercise.eachSide ? " each side" : "") · 2–3 RIR"
                      ).font(.caption)
                    }
                    Text(
                      "Rest \(block.restSeconds) seconds \(block.exercises.count == 2 ? "after both exercises" : block.exercises.first?.eachSide == true ? "after both sides" : "between sets")."
                    ).font(.caption).foregroundColor(.secondary)
                  }.padding(.vertical, 6)
                }
                if session.id == "wednesday" {
                  Text(
                    "Shoulder press: machine preferred, then dumbbells; each requires its own verified setup and baseline."
                  ).font(.caption).foregroundColor(.secondary)
                }
                if session.id == "friday" {
                  Text(
                    "Pull-ups: verified unassisted baseline first, otherwise a verified assisted-machine baseline."
                  ).font(.caption).foregroundColor(.secondary)
                }
                if session.id == "saturday" {
                  Text(
                    "Leg curl: seated preferred, then lying. Optional five-minute finisher remains off until its rules are approved."
                  ).font(.caption).foregroundColor(.secondary)
                }
              }
            }
            Text("Thursday · Recovery").font(.headline)
            Text(
              "No lifting. Easy walking and optional light mobility. Your supplied plan includes 8,000–10,000 total steps."
            ).font(.subheadline).foregroundColor(.secondary)
            Text("These day labels preserve your plan; automatic rescheduling is not enabled.")
              .font(.caption).foregroundColor(.secondary)
          }
        }
        Section {
          NavigationLink("Exercise library · wger") {
            ExerciseReferenceView(entries: exerciseReferences)
          }
        }
        Section {
          DisclosureGroup("Notifications") { NotificationSettingsView(model: notifications) }
        }
        Section { DisclosureGroup("Training setup") { SetupView(directory: directory, cue: cue) } }
        Section { DisclosureGroup("My gym") { GymSettingsView(directory: directory, cue: cue) } }
        #if DEBUG
          if ProcessInfo.processInfo.arguments.contains("--practice") {
            Section {
              DisclosureGroup("Developer practice") { PracticeSettingsView(directory: directory) }
            }
          }
        #endif
        Section {
          Text(
            "Core workouts, settings and history work offline. Manual logs and practice records do not become progression evidence."
          ).font(.caption).foregroundColor(.secondary)
        }
      }
      .navigationTitle("Settings")
    }
    .navigationViewStyle(.stack)
  }
}
@MainActor private final class GymSettingsModel: ObservableObject {
  @Published var saved: GymProfiles?
  @Published var pending: GymProfiles?
  @Published var error: String?
  private var repository: SqliteGymProfileRepository?
  private let path: String
  var locked: Bool { pending != nil || saved == nil }
  init(directory: URL) { path = directory.appendingPathComponent("gym_profiles.sqlite").path }
  func load() {
    guard pending == nil, saved == nil else { return }
    do {
      let repository = try SqliteGymProfileRepository(path: path)
      saved = try repository.load()
      self.repository = repository
      error = nil
    } catch { self.error = "Could not open your gyms. Try again." }
  }
  @discardableResult func select(_ gym: GymProfile) -> Bool {
    guard !locked, let saved else { return false }
    do {
      pending = try saved.select(gym)
      return retry()
    } catch {
      self.error = "Could not add this gym. Check its details or the 50-location limit."
      return false
    }
  }
  func clearSelection() -> Bool {
    guard !locked, let saved else { return false }
    do {
      pending = try GymProfiles(profiles: saved.profiles)
      return retry()
    } catch {
      self.error = "Could not clear selection."
      return false
    }
  }
  @discardableResult func update(
    category: String, availability: EquipmentAvailability, notes: String
  ) -> Bool {
    guard !locked, let selected = saved?.selected else { return false }
    do {
      return select(
        try selected.update(
          GymEquipment(
            category: category, availability: availability,
            checkedAt: availability == .unknown ? nil : Date(),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))))
    } catch {
      self.error = "Check the equipment details and try again."
      return false
    }
  }
  @discardableResult func retry() -> Bool {
    guard let pending, let saved, let repository else { return false }
    do {
      try repository.save(pending, expected: saved)
      let reloaded = try repository.load()
      try requireSetup(
        ManualJSON.bytesEqual(reloaded.encode(), pending.encode()), "save_not_confirmed")
      self.saved = reloaded
      self.pending = nil
      error = nil
      return true
    } catch {
      self.error =
        "Save not confirmed. Retry your saved change, or reload to review the latest profile."
      return false
    }
  }
  func reload() {
    pending = nil
    saved = nil
    load()
  }
}
private struct GymEquipmentEdit: Identifiable {
  var id: String
  var observation: GymEquipment?
}
private struct GymSettingsView: View {
  @StateObject private var model: GymSettingsModel
  let cue: (AppModel.Cue) -> Void
  @State private var adding = false
  @State private var editing: GymEquipmentEdit?
  @State private var name = ""
  @State private var address = ""
  @State private var formError: String?
  init(directory: URL, cue: @escaping (AppModel.Cue) -> Void) {
    self.cue = cue
    _model = StateObject(wrappedValue: GymSettingsModel(directory: directory))
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(
        "Location inventory only. Available equipment does not verify starting weights or authorize recommendations."
      ).font(.caption).foregroundColor(.secondary)
      if model.saved == nil { Button("Retry opening gyms") { model.load() } }
      if let saved = model.saved {
        Picker(
          "Selected gym",
          selection: Binding(
            get: { saved.selectedId ?? "" },
            set: { id in
              if id.isEmpty {
                cue(model.clearSelection() ? .selection : .error)
              } else if let gym = saved.profiles.first(where: { $0.id == id }) {
                cue(model.select(gym) ? .selection : .error)
              }
            })
        ) {
          Text("No gym selected").tag("")
          ForEach(saved.profiles.sorted { $0.name < $1.name }) { Text($0.name).tag($0.id) }
        }.disabled(model.locked)
        if !saved.profiles.contains(where: { $0.id == homewoodGymId }) {
          Button("Add CLUB4 Homewood") { cue(model.select(homewoodProfile()) ? .success : .error) }
            .disabled(model.locked)
        }
        Button("Add another location") { adding = true }.disabled(model.locked)
        if let gym = saved.selected {
          if !gym.address.isEmpty { Text(gym.address).font(.caption).foregroundColor(.secondary) }
          if gym.id == homewoodGymId {
            Text(
              "Name/address from the official location page, reviewed September 24, 2026. No machine inventory was preverified."
            ).font(.caption).foregroundColor(.secondary)
            Link("Location source", destination: URL(string: homewoodSource)!)
          }
          Text("General equipment checklist").font(.headline)
          Text("Mark only equipment you have checked at this location.").font(.caption)
            .foregroundColor(.secondary)
          ForEach(SetupTaxonomy.equipmentIds.sorted(), id: \.self) { category in
            let observation = gym.equipment.first { $0.category == category }
            Button {
              editing = GymEquipmentEdit(id: category, observation: observation)
            } label: {
              VStack(alignment: .leading) {
                Text(category.replacingOccurrences(of: "_", with: " ").capitalized)
                Text(observation?.availability.rawValue.capitalized ?? "Not checked").font(.caption)
                  .foregroundColor(.secondary)
                if let observation, !observation.notes.isEmpty {
                  Text(observation.notes).font(.caption).foregroundColor(.secondary)
                }
              }
            }.disabled(model.locked)
          }
        }
      }
      if let error = model.error { Text(error).foregroundColor(.red) }
      if model.pending != nil {
        Button("Retry saved change") { cue(model.retry() ? .success : .error) }
      }
      Button("Reload saved gyms") { model.reload() }
    }
    .buttonStyle(.borderless)
    .onAppear { model.load() }
    .sheet(isPresented: $adding) {
      NavigationView {
        Form {
          TextField("Gym name", text: $name)
          TextField("Address (optional)", text: $address)
          if let error = formError ?? model.error { Text(error).foregroundColor(.red) }
          if model.pending != nil {
            Button("Retry saved change") {
              if model.retry() {
                cue(.success)
                adding = false
                name = ""
                address = ""
              } else {
                cue(.error)
              }
            }
            Button("Reload saved gyms") {
              model.reload()
              adding = false
            }
          }
          Button("Save location") {
            do {
              let gym = try GymProfile(
                id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                address: address.trimmingCharacters(in: .whitespacesAndNewlines), equipment: [])
              if model.select(gym) {
                cue(.success)
                adding = false
                name = ""
                address = ""
                formError = nil
              } else {
                cue(.error)
              }
            } catch {
              formError = "Enter a valid name (up to 120 characters) and address (up to 240)."
              cue(.error)
            }
          }.disabled(model.locked)
        }.navigationTitle("Add location")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") { adding = false }.disabled(model.pending != nil)
            }
          }
      }.interactiveDismissDisabled(model.pending != nil)
    }
    .sheet(item: $editing) { item in GymEquipmentEditor(model: model, item: item, cue: cue) }
  }
}
private struct GymEquipmentEditor: View {
  @ObservedObject var model: GymSettingsModel
  let item: GymEquipmentEdit
  let cue: (AppModel.Cue) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var availability: EquipmentAvailability
  @State private var notes: String
  init(model: GymSettingsModel, item: GymEquipmentEdit, cue: @escaping (AppModel.Cue) -> Void) {
    self.cue = cue
    self.model = model
    self.item = item
    _availability = State(initialValue: item.observation?.availability ?? .unknown)
    _notes = State(initialValue: item.observation?.notes ?? "")
  }
  var body: some View {
    NavigationView {
      Form {
        Picker(
          "Availability",
          selection: Binding(
            get: { availability },
            set: {
              if availability != $0 {
                availability = $0
                cue(.selection)
              }
            })
        ) {
          Text("Not checked").tag(EquipmentAvailability.unknown)
          Text("Available").tag(EquipmentAvailability.available)
          Text("Unavailable").tag(EquipmentAvailability.unavailable)
        }.disabled(model.locked)
        TextField("Machine, attachment or settings notes", text: $notes).disabled(model.locked)
        Text("Notes stay descriptive. They are never interpreted as a prescription.").font(.caption)
          .foregroundColor(.secondary)
        if let error = model.error { Text(error).foregroundColor(.red) }
        if model.pending != nil {
          Button("Retry saved change") {
            if model.retry() {
              cue(.success)
              dismiss()
            } else {
              cue(.error)
            }
          }
          Button("Reload saved gyms") {
            model.reload()
            dismiss()
          }
        }
        Button("Save observation") {
          if model.update(category: item.id, availability: availability, notes: notes) {
            cue(.success)
            dismiss()
          } else {
            cue(.error)
          }
        }.disabled(model.locked)
      }.navigationTitle(item.id.replacingOccurrences(of: "_", with: " ").capitalized)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }.disabled(model.pending != nil)
          }
        }
    }.interactiveDismissDisabled(model.pending != nil)
  }
}

#if DEBUG
  @MainActor private final class PracticeSettingsModel: ObservableObject {
    @Published var sessions: [PracticeSession] = []
    @Published var selectedId: String?
    @Published var error: String?
    @Published var pending = false
    private var operation: (() throws -> Void)?
    private var expected: ((PracticeSession) -> Bool)?
    private var repository: SqlitePracticeRepository?
    private let path: String
    var selected: PracticeSession? { sessions.first { $0.id == selectedId } }
    var loaded: Bool { repository != nil }
    init(directory: URL) { path = directory.appendingPathComponent("adaptive_workout.sqlite").path }
    func load() {
      guard !pending else { return }
      do {
        if repository == nil { repository = try SqlitePracticeRepository(path: path) }
        sessions = try repository!.load("local_owner")
        if selectedId == nil {
          selectedId = sessions.first { !$0.completed }?.id ?? sessions.first?.id
        }
        error = nil
      } catch { self.error = "Could not open practice storage. Try again." }
    }
    @discardableResult func retry() -> Bool {
      guard let operation, let repository else { return false }
      do {
        try operation()
        let reloaded = try repository.load("local_owner")
        guard let saved = reloaded.first(where: { $0.id == selectedId }), expected?(saved) == true
        else { throw LoggingException(code: "save_not_confirmed") }
        sessions = reloaded
        self.operation = nil
        expected = nil
        pending = false
        error = nil
        return true
      } catch {
        self.error = "Save not confirmed. Your action is kept. Retry safely."
        return false
      }
    }
    private func perform(
      _ action: @escaping () throws -> Void, expected: @escaping (PracticeSession) -> Bool
    ) {
      guard !pending else { return }
      operation = action
      self.expected = expected
      pending = true
      _ = retry()
    }
    func start() {
      guard !pending, let repository else { return }
      if let draft = sessions.first(where: { !$0.completed }) {
        selectedId = draft.id
        return
      }
      let id = UUID().uuidString
      let action = UUID().uuidString
      let at = Date()
      selectedId = id
      perform(
        { try repository.start(profileId: "local_owner", sessionId: id, actionId: action, at: at) },
        expected: { $0.id == id })
    }
    func finish() {
      guard !pending, let repository, let selected, !selected.completed else { return }
      let action = UUID().uuidString
      let at = Date()
      perform(
        {
          try repository.complete(
            profileId: "local_owner", sessionId: selected.id, actionId: action,
            expectedRevision: selected.revision, at: at)
        }, expected: { $0.completed })
    }
    func record(_ record: PracticeSet, correction: Bool) {
      guard !pending, let repository, let selected else { return }
      let action = UUID().uuidString
      let at = Date()
      perform(
        {
          try repository.saveSet(
            profileId: "local_owner", sessionId: selected.id, actionId: action,
            expectedRevision: selected.revision, record: record, correction: correction, at: at)
        }, expected: { $0.revision >= selected.revision + 1 && $0.sets.contains(record) })
    }
  }
  private struct PracticeSettingsView: View {
    @StateObject private var model: PracticeSettingsModel
    @State private var exercise = "practice_press"
    @State private var load = ""
    @State private var reps = ""
    @State private var rir = ""
    @State private var working = true
    @State private var validity: SetValidity = .unknown
    @State private var skipped = false
    @State private var correcting: PracticeSet?
    @State private var entryError: String?
    init(directory: URL) {
      _model = StateObject(wrappedValue: PracticeSettingsModel(directory: directory))
    }
    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("Development records only. Never used as workout or progression evidence.").font(
          .caption
        ).foregroundColor(.secondary)
        if model.loaded {
          Button("Start or resume practice") { model.start() }.disabled(model.pending)
          Picker(
            "Saved practice",
            selection: Binding(
              get: { model.selectedId ?? "" },
              set: {
                model.selectedId = $0
                correcting = nil
              })
          ) {
            Text("Select a session").tag("")
            ForEach(model.sessions, id: \.id) { session in
              Text(session.startedAt.formatted() + (session.completed ? " · Finished" : " · Draft"))
                .tag(session.id)
            }
          }.disabled(model.pending)
          if let session = model.selected {
            ForEach(session.sets, id: \.id) { record in
              Button {
                correcting = record
                exercise = record.exerciseId
                load = record.microPounds.map(formatPounds) ?? ""
                reps = record.reps.map(String.init) ?? ""
                rir = record.rir.map(String.init) ?? ""
                working = record.working
                validity = record.validity
                skipped = record.skipped
              } label: {
                Text(
                  "\(practiceExercises[record.exerciseId]!) #\(record.index): \(record.skipped ? "Skipped" : "\(record.microPounds.map(formatPounds) ?? "—") lb × \(record.reps ?? 0)") · Correct"
                )
              }.disabled(model.pending)
            }
            if !session.completed || correcting != nil {
              Picker("Exercise", selection: $exercise) {
                ForEach(practiceExercises.keys.sorted(), id: \.self) {
                  Text(practiceExercises[$0]!).tag($0)
                }
              }.disabled(correcting != nil)
              Toggle("Working set", isOn: $working)
              Toggle("Explicitly skipped", isOn: $skipped)
              if !skipped {
                TextField("Pounds", text: $load).keyboardType(.decimalPad)
                TextField("Actual reps", text: $reps).keyboardType(.numberPad)
                TextField("Actual RIR (optional)", text: $rir).keyboardType(.numberPad)
                Picker("Set validity", selection: $validity) {
                  Text("Unknown").tag(SetValidity.unknown)
                  Text("Valid").tag(SetValidity.valid)
                  Text("Invalid").tag(SetValidity.invalid)
                  Text("Pain").tag(SetValidity.pain)
                }
              }
              Button(correcting == nil ? "Save practice set" : "Save correction") {
                do {
                  if !skipped && (Int(reps) == nil || (!rir.isEmpty && Int(rir) == nil)) {
                    throw LoggingException(code: "invalid_actuals")
                  }
                  let record = try PracticeSet(
                    id: correcting?.id ?? UUID().uuidString, exerciseId: exercise,
                    index: correcting?.index
                      ?? ((session.sets.filter { $0.exerciseId == exercise }.map(\.index).max() ?? 0)
                        + 1),
                    microPounds: skipped ? nil : parsePounds(load), reps: skipped ? nil : Int(reps),
                    rir: skipped ? nil : Int(rir), working: working,
                    validity: skipped ? .unknown : validity, skipped: skipped)
                  model.record(record, correction: correcting != nil)
                  if !model.pending {
                    correcting = nil
                    load = ""
                    reps = ""
                    rir = ""
                    entryError = nil
                  }
                } catch { entryError = "Check exact pounds, reps and RIR." }
              }.disabled(model.pending)
              if correcting != nil {
                Button("Cancel correction") { correcting = nil }.disabled(model.pending)
              }
            }
            if !session.completed {
              Button("Finish practice session") { model.finish() }.disabled(model.pending)
            }
          }
        }
        if let error = entryError ?? model.error { Text(error).foregroundColor(.red) }
        if model.pending { Button("Retry saved action") { if model.retry() { correcting = nil } } }
        if !model.loaded { Button("Retry opening practice") { model.load() } }
      }.buttonStyle(.borderless).onAppear { model.load() }
    }
  }
#endif
