import SwiftUI
import WorkoutDomain

struct SetEditor: View {
  let log: ProgramLog
  let exercise: ProgramExercise
  let index: Int
  let side: LoggedSide
  let warmup: Bool
  var cue: (AppModel.Cue) -> Void = { _ in }
  let save: (ProgramSet) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var variant = ""
  @State private var legacySetup = ""
  @State private var convention = ""
  @State private var load = ""
  @State private var reps = ""
  @State private var rir = ""
  @State private var validity = SetValidity.unknown
  @State private var error: String?
  @State private var initialized = false
  var body: some View {
    NavigationView {
      Form {
        Section {
          Text(exercise.name).font(.headline)
          Text(
            "\(warmup ? "Warm-up" : "Working set") \(index)\(side == .both ? "" : " · " + side.rawValue)"
          )
          if !exercise.alternatives.isEmpty {
            Picker(
              "Variation",
              selection: Binding(
                get: { variant },
                set: { value in
                  if variant != value {
                    variant = value
                    legacySetup = ""
                    convention =
                      manualLoadConventions(variant: value).count == 1
                      ? manualLoadConventions(variant: value)[0].rawValue : ""
                    load = ""
                    cue(.selection)
                  }
                })
            ) {
              Text("Choose variation").tag("")
              ForEach(exercise.alternatives, id: \.self) {
                Text($0.replacingOccurrences(of: "_", with: " ")).tag($0)
              }
            }
          }
          if let previous = log.previousSet(
            slot: exercise.id, index: index, side: side, warmup: warmup)
          {
            Button("Copy previous set") {
              if variant != previous.variant { legacySetup = "" }
              variant = previous.variant
              convention = previous.convention.rawValue
              load = previous.load.map(formatPounds) ?? ""
              reps = previous.reps.map(String.init) ?? ""
              cue(.selection)
            }.accessibilityIdentifier("copy_previous_set")
          }
          Picker(
            "Load measurement",
            selection: Binding(
              get: { convention },
              set: { value in
                if convention != value {
                  convention = value
                  cue(.selection)
                }
              })
          ) {
            Text("Choose measurement").tag("")
            ForEach(variant.isEmpty ? [] : manualLoadConventions(variant: variant), id: \.rawValue)
            {
              Text(conventionLabel($0)).tag($0.rawValue)
            }
          }.accessibilityIdentifier("set_convention")
          if convention != LoadConvention.bodyweight.rawValue {
            TextField("Actual load (lb)", text: $load).keyboardType(.decimalPad)
              .accessibilityIdentifier("set_load")
          }
          TextField("Completed reps", text: $reps).keyboardType(.numberPad).accessibilityIdentifier(
            "set_reps")
          TextField("RIR (optional)", text: $rir).keyboardType(.numberPad).accessibilityIdentifier(
            "set_rir")
          Picker(
            "Set validity",
            selection: Binding(
              get: { validity },
              set: { value in
                if validity != value {
                  validity = value
                  cue(value == .pain ? .warning : .selection)
                }
              })
          ) {
            ForEach(SetValidity.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0) }
          }.accessibilityIdentifier("set_validity")
        } footer: {
          Text(
            "Copy fills weight, reps, variation and load measurement. Review each set before saving. Logging does not verify a starting load."
          )
        }
        if let error { Section { Text(error).foregroundColor(.red) } }
        Section {
          Button("Save set") { submit(skip: false) }.accessibilityIdentifier("save_set")
          Button("Skip set") { submit(skip: true) }
        }
      }
      .navigationTitle("Record set").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
      .onAppear {
        guard !initialized else { return }
        initialized = true
        let set = log.sets.first {
          $0.slot == exercise.id && $0.index == index && $0.side == side && $0.warmup == warmup
        }
        variant = set?.variant ?? (exercise.alternatives.isEmpty ? exercise.id : "")
        legacySetup = set?.setup ?? ""
        convention =
          set?.convention.rawValue
          ?? (manualLoadConventions(variant: variant).count == 1
            ? manualLoadConventions(variant: variant)[0].rawValue : "")
        load = set?.load.map(formatPounds) ?? ""
        reps = set?.reps.map(String.init) ?? ""
        rir = set?.rir.map(String.init) ?? ""
        validity = set?.validity ?? .unknown
      }
    }.navigationViewStyle(.stack)
  }
  private func submit(skip: Bool) {
    do {
      guard let measurement = LoadConvention(rawValue: convention) else {
        throw LoggingException("setup_required")
      }
      let repetitions = skip ? nil : Int(reps.trimmingCharacters(in: .whitespaces))
      let effort =
        skip || rir.trimmingCharacters(in: .whitespaces).isEmpty
        ? nil : Int(rir.trimmingCharacters(in: .whitespaces))
      guard skip || repetitions != nil,
        skip || rir.trimmingCharacters(in: .whitespaces).isEmpty || effort != nil
      else { throw LoggingException("invalid_actuals") }
      let set = ProgramSet(
        slot: exercise.id, index: index, side: side, variant: variant,
        setup: legacySetup, convention: measurement,
        load: skip || measurement == .bodyweight ? nil : try parsePounds(load),
        reps: repetitions, rir: effort, validity: skip ? .unknown : validity,
        warmup: warmup, skipped: skip)
      try log.validateSet(set)
      save(set)
      dismiss()
    } catch {
      self.error =
        "Choose a variation and load measurement, then enter valid weight and reps. RIR may be blank."
      cue(.error)
    }
  }
}
func conventionLabel(_ convention: LoadConvention) -> String {
  switch convention {
  case .perDumbbell: "Pounds per dumbbell"
  case .machineSetting: "Displayed machine setting (lb)"
  case .platesOnly: "Added plates only (lb)"
  case .totalLoad: "Total load (lb)"
  case .assistance: "Assistance (lb)"
  case .bodyweight: "Bodyweight, no added load"
  }
}
