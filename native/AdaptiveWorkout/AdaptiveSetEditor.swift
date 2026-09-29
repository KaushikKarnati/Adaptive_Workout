import SwiftUI
import WorkoutApplication
import WorkoutDomain

struct AdaptiveSetEditor: View {
  let slot: RecommendedSlot
  let target: SetTarget
  let currentSet: ProgramSet?
  var cue: (AppModel.Cue) -> Void = { _ in }
  let save: (ProgramSet) -> Void
  let skip: (ProgramSet) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var load = ""
  @State private var reps = ""
  @State private var rir = ""
  @State private var validity = SetValidity.valid
  @State private var error: String?
  @State private var initialized = false

  private var exerciseName: String {
    let raw = target.rehearsalIdentity?.exerciseId ?? slot.exerciseId
    let variant = raw.hasPrefix("owner_ex_") ? String(raw.dropFirst("owner_ex_".count)) : raw
    return setupVariationNames[variant]
      ?? variant.replacingOccurrences(of: "_", with: " ").capitalized
  }

  private var convention: LoadConvention {
    target.rehearsalIdentity?.convention ?? slot.convention
  }

  private var isBodyweight: Bool {
    convention == .bodyweight
  }

  var body: some View {
    NavigationView {
      Form {
        infoSection
        performanceSection
        if let error {
          Section {
            Text(error).foregroundColor(.red)
          }
        }
        actionsSection
      }
      .scrollContentBackground(.hidden)
      .background(Stitch.canvas)
      .navigationTitle(target.warmup ? "Warm-up set" : "Working set")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .onAppear { initializeState() }
      .onChange(of: validity) { _, next in
        cue(next == .pain ? .warning : .selection)
      }
    }
    .navigationViewStyle(.stack)
  }

  @ViewBuilder
  private var infoSection: some View {
    Section {
      Text(exerciseName).font(Stitch.font(24, .semibold))
      Text(
        "Prescribed: \(target.minReps)–\(target.maxReps) reps · \(target.minRir.map { "RIR \($0)–\(target.maxRir ?? 3)" } ?? "RIR 2–3")"
      ).font(.subheadline).foregroundStyle(.secondary)

      if let targetLoad = target.load, !isBodyweight {
        Text("Target load: \(formatPounds(targetLoad)) lb (\(conventionLabel(convention)))")
          .font(Stitch.font(14, .medium)).foregroundStyle(Stitch.amber)
      } else if isBodyweight {
        Text("Target: Bodyweight (\(conventionLabel(convention)))")
          .font(Stitch.font(14, .medium)).foregroundStyle(Stitch.secondary)
      }

      if validity == .pain {
        Text(
          "Warning: Pain will permanently stop subsequent sets for this exercise during this workout."
        )
        .foregroundStyle(.red)
      }

      Text(
        "\(target.warmup ? "Warm-up" : "Working set") \(target.index)\(target.side == .both ? "" : " · " + target.side.rawValue.capitalized)"
      ).font(Stitch.font(14)).foregroundStyle(.secondary)

      Text("Setup: \(target.rehearsalIdentity?.setupId ?? slot.setupId)")
        .font(Stitch.font(12)).foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var performanceSection: some View {
    Section(
      header: Text("Actual performance"),
      footer: Text("Deterministic engine targets are calibrated from your baselines.")
    ) {
      if !isBodyweight {
        TextField("Actual load (lb)", text: $load)
          .keyboardType(.decimalPad)
          .accessibilityIdentifier("adaptive_set_load")
      }
      TextField("Completed reps", text: $reps)
        .keyboardType(.numberPad)
        .accessibilityIdentifier("adaptive_set_reps")
      TextField("RIR (optional)", text: $rir)
        .keyboardType(.numberPad)
        .accessibilityIdentifier("adaptive_set_rir")

      Picker("Set validity", selection: $validity) {
        ForEach(SetValidity.allCases, id: \.rawValue) {
          Text($0.rawValue.capitalized).tag($0)
        }
      }
      .accessibilityIdentifier("adaptive_set_validity")
    }
  }

  @ViewBuilder
  private var actionsSection: some View {
    Section {
      Button("Save set") {
        submit(isSkip: false)
      }
      .buttonStyle(.borderedProminent)
      .frame(minHeight: 52)
      .accessibilityIdentifier("save_adaptive_set")

      Button("Skip set") {
        submit(isSkip: true)
      }
      .accessibilityIdentifier("skip_adaptive_set")
    }
  }

  private func initializeState() {
    guard !initialized else { return }
    initialized = true
    if let current = currentSet {
      load = current.load.map(formatPounds) ?? ""
      reps = current.reps.map(String.init) ?? ""
      rir = current.rir.map(String.init) ?? ""
      validity = current.validity
    } else {
      load = target.load.map(formatPounds) ?? ""
      reps = String(target.minReps)
      rir = target.minRir.map(String.init) ?? ""
      validity = .valid
    }
  }

  private func submit(isSkip: Bool) {
    do {
      let variant = target.rehearsalIdentity?.exerciseId ?? slot.exerciseId
      let setupId = target.rehearsalIdentity?.setupId ?? slot.setupId
      let measurement = convention

      if isSkip {
        let set = ProgramSet(
          slot: slot.id,
          index: target.index,
          side: target.side,
          variant: variant,
          setup: setupId,
          convention: measurement,
          load: nil,
          reps: nil,
          rir: nil,
          validity: .unknown,
          warmup: target.warmup,
          skipped: true
        )
        skip(set)
        dismiss()
        return
      }

      let parsedLoad: Int?
      if measurement == .bodyweight {
        parsedLoad = nil
      } else {
        guard !load.trimmingCharacters(in: .whitespaces).isEmpty else {
          throw LoggingException("missing_load")
        }
        parsedLoad = try parsePounds(load)
      }

      guard let parsedReps = Int(reps.trimmingCharacters(in: .whitespaces)), parsedReps >= 0 else {
        throw LoggingException("invalid_reps")
      }

      let trimmedRir = rir.trimmingCharacters(in: .whitespaces)
      let parsedRir = trimmedRir.isEmpty ? nil : Int(trimmedRir)

      let set = ProgramSet(
        slot: slot.id,
        index: target.index,
        side: target.side,
        variant: variant,
        setup: setupId,
        convention: measurement,
        load: parsedLoad,
        reps: parsedReps,
        rir: parsedRir,
        validity: validity,
        warmup: target.warmup,
        skipped: false
      )
      save(set)
      dismiss()
    } catch {
      self.error = "Please check the entered load and reps values."
      cue(.error)
    }
  }
}
