import SwiftUI
import WorkoutApplication
import WorkoutDomain
import WorkoutPersistence

@MainActor final class SetupModel: ObservableObject {
  @Published var saved: TrainingSetup?
  @Published var loaded = false
  @Published var error: String?
  @Published var notice: String?
  @Published var days: Set<Int> = []
  @Published var minutes = ""
  @Published var exclusions: Set<String> = []
  @Published var pending = false
  private var controller: TrainingSetupController?
  private let path: String
  var locked: Bool { pending || !loaded }
  init(directory: URL) { path = directory.appendingPathComponent("training_setup.sqlite").path }
  private func sync() {
    saved = controller?.saved
    loaded = controller?.loaded ?? false
    error = controller?.error
    pending = controller?.canRetry ?? false
  }
  func load() {
    guard !loaded, !pending else { return }
    do {
      if controller == nil {
        controller = TrainingSetupController(
          repository: try SqliteTrainingSetupRepository(path: path))
      }
      controller?.load()
      sync()
      if loaded {
        days = Set(saved?.trainingDays ?? [])
        minutes = saved?.preferredMinutes.map(String.init) ?? ""
        exclusions = Set(saved?.excludedVariations ?? [])
      }
    } catch { self.error = "Could not open setup. Try again." }
  }
  @discardableResult func retry() -> Bool {
    let success = controller?.retry() ?? false
    sync()
    if success { notice = "Saved on this device." }
    return success
  }
  @discardableResult func savePreferences() -> Bool {
    let success =
      controller?.savePreferences(
        days: Array(days), minutes: minutes, exclusions: Array(exclusions)) ?? false
    sync()
    if success { notice = "Saved on this device." }
    return success
  }
  func saveMachine(
    existing: EquipmentSetup?, label: String, sessionId: String, slotId: String, variation: String,
    convention: SetupLoadConvention, equipmentId: String?, work: String, rehearsal: String,
    starting: String, confirmed: Bool
  ) -> Bool {
    let success =
      controller?.saveMachine(
        existingId: existing?.id, label: label, sessionId: sessionId, slotId: slotId,
        variation: variation, convention: convention, workingSettings: work,
        rehearsalSettings: rehearsal, startingWeight: starting, confirmed: confirmed,
        equipmentId: equipmentId, quantity: existing?.quantity ?? 1,
        capabilities: existing?.capabilities ?? []) ?? false
    sync()
    if success { notice = "Saved on this device." }
    return success
  }
}

struct SetupView: View {
  @StateObject private var model: SetupModel
  let cue: (AppModel.Cue) -> Void
  @State private var editing: SetupEdit?
  init(directory: URL, cue: @escaping (AppModel.Cue) -> Void = { _ in }) {
    self.cue = cue
    _model = StateObject(wrappedValue: SetupModel(directory: directory))
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(
        "Save your preferences and verify equipment gradually. These records stay on this device."
      ).font(.subheadline).foregroundColor(.secondary)
      if !model.loaded { Button("Retry opening setup") { model.load() } }
      Text("Training days").font(.headline)
      ForEach(1...7, id: \.self) { day in
        Toggle(
          ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day - 1],
          isOn: Binding(
            get: { model.days.contains(day) },
            set: { value in
              if value { model.days.insert(day) } else { model.days.remove(day) }
              cue(.selection)
            })
        ).disabled(model.locked)
      }
      TextField("Preferred workout minutes", text: $model.minutes).keyboardType(.numberPad)
        .disabled(model.locked)
      Text("A time preference, not a hard cutoff.").font(.caption).foregroundColor(.secondary)
      DisclosureGroup("Exercises to exclude") {
        ForEach(setupVariationNames.keys.sorted(), id: \.self) { key in
          Toggle(
            setupVariationNames[key]!,
            isOn: Binding(
              get: { model.exclusions.contains(key) },
              set: { value in
                if value { model.exclusions.insert(key) } else { model.exclusions.remove(key) }
                cue(.selection)
              })
          ).disabled(model.locked)
        }
      }
      Button("Save preferences") { cue(model.savePreferences() ? .success : .error) }.disabled(
        model.locked)
      Divider()
      Text("Equipment and starting loads").font(.headline)
      Text(
        "Unknown assessments remain unknown. Equipment confirmation does not approve catalog entries or clear safety restrictions."
      ).font(.caption).foregroundColor(.secondary)
      ForEach(model.saved?.equipment ?? [], id: \.id) { item in
        Button {
          editing = SetupEdit(equipment: item)
        } label: {
          VStack(alignment: .leading) {
            Text(item.label)
            Text(
              item.confirmed ? "Confirmed setup · revision \(item.revision)" : "Unverified setup"
            ).font(.caption).foregroundColor(.secondary)
          }
        }.disabled(model.locked)
      }
      ForEach(model.saved?.startingLoads ?? [], id: \.id) { load in
        VStack(alignment: .leading) {
          Text(
            "\(load.sessionId.capitalized) · \(setupVariationNames[load.variation] ?? load.variation)"
          )
          Text(
            "\(load.microPounds.map(formatPounds) ?? "Bodyweight")\(load.microPounds == nil ? "" : " lb") · \(model.saved?.baselineIsCurrent(load) == true ? "Current confirmation" : "Stale — verify again")"
          ).font(.caption).foregroundColor(.secondary)
        }
      }
      Button("Add equipment") { editing = SetupEdit(equipment: nil) }.disabled(model.locked)
      if let error = model.error { Text(error).foregroundColor(.red).accessibilityLabel(error) }
      if model.pending { Button("Retry save") { cue(model.retry() ? .success : .error) } }
      if let notice = model.notice { Text(notice).font(.caption).foregroundColor(.secondary) }
    }
    .buttonStyle(.borderless)
    .onAppear { model.load() }
    .sheet(item: $editing) { edit in
      SetupMachineEditor(model: model, existing: edit.equipment, cue: cue)
    }
  }
}
private struct SetupEdit: Identifiable {
  let id = UUID()
  let equipment: EquipmentSetup?
}
private struct SetupMachineEditor: View {
  @ObservedObject var model: SetupModel
  let existing: EquipmentSetup?
  let cue: (AppModel.Cue) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var sessionId: String
  @State private var slotId: String
  @State private var variation: String
  @State private var convention: SetupLoadConvention
  @State private var label: String
  @State private var equipmentId: String
  @State private var work: String
  @State private var rehearsal: String
  @State private var starting = ""
  @State private var confirmed = false
  init(model: SetupModel, existing: EquipmentSetup?, cue: @escaping (AppModel.Cue) -> Void) {
    self.cue = cue
    self.model = model
    self.existing = existing
    let session = ownerProgram.first { session in
      existing == nil
        || session.blocks.flatMap(\.exercises).contains {
          setupVariantsFor($0).contains(existing!.variation)
        }
    }!
    let exercise = session.blocks.flatMap(\.exercises).first {
      existing == nil || setupVariantsFor($0).contains(existing!.variation)
    }!
    _sessionId = State(initialValue: session.id)
    _slotId = State(initialValue: exercise.id)
    let variation = existing?.variation ?? setupVariantsFor(exercise)[0]
    _variation = State(initialValue: variation)
    _convention = State(initialValue: existing?.convention ?? setupConventionsFor(variation)[0])
    _label = State(initialValue: existing?.label ?? "")
    _equipmentId = State(initialValue: existing?.equipmentId ?? "")
    _work = State(
      initialValue: existing?.workingLoads.map(formatPounds).joined(separator: ", ") ?? "")
    _rehearsal = State(
      initialValue: existing?.rehearsalLoads.map(formatPounds).joined(separator: ", ") ?? "")
  }
  private var sessions: [ProgramSession] {
    ownerProgram.filter { s in
      existing == nil
        || s.blocks.flatMap(\.exercises).contains { setupVariantsFor($0).contains(variation) }
    }
  }
  private var exercises: [ProgramExercise] {
    ownerProgram.first { $0.id == sessionId }!.blocks.flatMap(\.exercises)
  }
  private var exercise: ProgramExercise { exercises.first { $0.id == slotId } ?? exercises[0] }
  private func selection<T: Equatable>(_ binding: Binding<T>) -> Binding<T> {
    Binding(
      get: { binding.wrappedValue },
      set: { value in
        if binding.wrappedValue != value {
          binding.wrappedValue = value
          cue(.selection)
        }
      })
  }
  private func resetInputs() {
    work = ""
    rehearsal = ""
    starting = ""
    confirmed = false
    equipmentId = ""
  }
  var body: some View {
    NavigationView {
      Form {
        Section {
          Picker("Program session", selection: selection($sessionId)) {
            ForEach(sessions, id: \.id) { Text($0.day + ": " + $0.title).tag($0.id) }
          }
          .onChange(of: sessionId) { _, _ in
            let next =
              existing == nil
              ? exercises[0] : exercises.first { setupVariantsFor($0).contains(variation) }!
            slotId = next.id
            confirmed = false
            starting = ""
            if existing == nil {
              variation = setupVariantsFor(next)[0]
              convention = setupConventionsFor(variation)[0]
              resetInputs()
            }
          }
          Picker("Exercise slot", selection: selection($slotId)) {
            ForEach(exercises, id: \.id) { Text($0.name).tag($0.id) }
          }.disabled(existing != nil)
            .onChange(of: slotId) { _, _ in
              if existing == nil {
                variation = setupVariantsFor(exercise)[0]
                convention = setupConventionsFor(variation)[0]
                resetInputs()
              }
            }
          Picker("Exact variation", selection: selection($variation)) {
            ForEach(setupVariantsFor(exercise), id: \.self) {
              Text(setupVariationNames[$0] ?? $0).tag($0)
            }
          }.disabled(existing != nil)
            .onChange(of: variation) { _, value in
              if existing == nil {
                convention = setupConventionsFor(value)[0]
                resetInputs()
              }
            }
          TextField("Machine / setup label", text: $label)
          Picker("How weight is recorded", selection: selection($convention)) {
            ForEach(setupConventionsFor(variation), id: \.self) { Text($0.label).tag($0) }
          }.disabled(existing != nil)
            .onChange(of: convention) { _, _ in if existing == nil { resetInputs() } }
          Picker("Equipment category", selection: selection($equipmentId)) {
            Text("Not mapped yet").tag("")
            ForEach(SetupTaxonomy.equipmentIds.sorted(), id: \.self) {
              Text($0.replacingOccurrences(of: "_", with: " ")).tag($0)
            }
          }.onChange(of: equipmentId) { _, _ in confirmed = false }
          if convention != .bodyweight {
            TextField("Checked working settings (lb, comma separated)", text: $work)
            TextField("Checked warm-up settings (lb)", text: $rehearsal)
            TextField(
              convention == .assistance
                ? "Confirmed starting assistance (lb)" : "Confirmed starting weight (lb)",
              text: $starting
            ).keyboardType(.decimalPad)
          }
          Toggle(
            "I checked this exact setup, its settings and my starting load.",
            isOn: Binding(
              get: { confirmed },
              set: {
                confirmed = $0
                cue(.selection)
              }))
          Text(
            "Leave confirmation off and starting weight blank to save equipment for later verification."
          ).font(.caption).foregroundColor(.secondary)
        }.disabled(model.locked)
        if let error = model.error { Text(error).foregroundColor(.red) }
        if model.pending {
          Button("Retry save") {
            if model.retry() {
              cue(.success)
              dismiss()
            } else {
              cue(.error)
            }
          }
        }
        Button(confirmed ? "Save confirmed setup" : "Save unverified setup") {
          if model.saveMachine(
            existing: existing, label: label, sessionId: sessionId, slotId: slotId,
            variation: variation, convention: convention,
            equipmentId: equipmentId.isEmpty ? nil : equipmentId, work: work, rehearsal: rehearsal,
            starting: starting, confirmed: confirmed)
          {
            cue(.success)
            dismiss()
          } else {
            cue(.error)
          }
        }.disabled(model.locked)
      }
      .navigationTitle(existing == nil ? "Add equipment" : "Verify equipment again")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.disabled(model.pending)
        }
      }
    }.interactiveDismissDisabled(model.pending)
  }
}
