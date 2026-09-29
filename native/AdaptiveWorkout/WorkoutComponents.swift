import SwiftUI
import WorkoutApplication
import WorkoutDomain

struct WorkoutTimerCapsule: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let elapsed: TimeInterval
  let remaining: TimeInterval
  let duration: Int
  let started: Bool
  let completed: Bool
  let clear: () -> Void
  var body: some View {
    Group {
      if typeSize.isAccessibilitySize {
        HStack {
          VStack(alignment: .leading, spacing: 0) {
            Text(started ? "Rest" : "Workout").font(.caption2).foregroundStyle(Stitch.secondary)
            Text(timerText(started ? remaining : elapsed)).font(Stitch.font(24, .semibold))
              .monospacedDigit()
              .accessibilityLabel(
                started
                  ? "Rest remaining \(timerText(remaining))"
                  : "Rest ready. Workout elapsed \(timerText(elapsed))")
          }
          Spacer()
          if started {
            Button(action: clear) {
              Image(systemName: "xmark.circle").font(.system(size: 28)).frame(width: 48, height: 48)
            }
            .accessibilityLabel("Clear rest")
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Circle().fill(Stitch.amber).frame(width: 9, height: 9)
            StitchLabel(text: started ? "Rest interval" : "Session timer")
            Spacer()
            Text("Workout \(timerText(elapsed))").font(Stitch.font(12)).monospacedDigit()
          }
          if started && !completed {
            HStack(alignment: .firstTextBaseline) {
              Text(timerText(remaining)).font(Stitch.font(36, .bold)).monospacedDigit()
              StitchLabel(text: remaining == 0 ? "Rest complete" : "Remaining")
              Spacer(minLength: 0)
            }
            ProgressView(
              value: min(Double(max(duration, 1)), remaining), total: Double(max(duration, 1))
            )
            .tint(Stitch.amber)
            HStack {
              Label("On-device countdown", systemImage: "timer").font(Stitch.font(12))
                .foregroundStyle(Stitch.secondary)
              Spacer()
              Button("Dismiss Rest", action: clear).font(Stitch.font(12, .semibold))
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(Stitch.elevated, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Clear rest")
            }
          } else {
            Text(completed ? "Finished" : "Rest ready").font(Stitch.font(14, .semibold))
          }
        }
      }
    }.padding(16).background(Stitch.card, in: RoundedRectangle(cornerRadius: 20))
      .overlay(RoundedRectangle(cornerRadius: 20).stroke(Stitch.elevated, lineWidth: 1))
      .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
      .padding(.horizontal, 16).padding(.vertical, 8)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("workout_timer_capsule")
  }
}

struct DurationSheet: View {
  @ObservedObject var model: SetupModel
  var cue: (AppModel.Cue) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var minutes: Int?
  @State private var initialized = false
  @State private var submitted = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text("How long do you have today?").font(.title2.bold())
          Text(
            model.saved?.preferredMinutes.map { "Your usual is \($0) min. Saved on this device." }
              ?? "No time limit is saved."
          )
          .foregroundStyle(.secondary)
          ForEach(options, id: \.self) { value in
            Button {
              minutes = value == 0 ? nil : value
              cue(.selection)
            } label: {
              HStack {
                Text(value == 0 ? "No time limit" : "\(value) min")
                Spacer()
                if minutes == (value == 0 ? nil : value) {
                  Image(systemName: "checkmark").accessibilityHidden(true)
                }
              }.frame(minHeight: 44)
            }.disabled(model.locked).accessibilityAddTraits(
              minutes == (value == 0 ? nil : value) ? .isSelected : [])
          }
        }
        Section {
          Text(
            "Rules for fitting a session into less time are not approved yet. Nothing is removed from your plan. This saves an advisory preference only."
          ).foregroundStyle(.secondary)
          Button(minutes.map { "Use \($0) min" } ?? "Use no time limit") {
            submitted = true
            if model.saveDuration(minutes) {
              cue(.success)
              dismiss()
            } else {
              cue(.error)
            }
          }.buttonStyle(.borderedProminent).frame(minHeight: 52).disabled(model.locked)
        }
        if let error = model.error { Text(error).foregroundStyle(.red) }
        if model.pending {
          Button("Retry saved change") {
            if model.retry() {
              cue(.success)
              if submitted { dismiss() }
            } else {
              cue(.error)
            }
          }
        }
        if !model.loaded {
          Button("Retry opening preferences") {
            model.load()
            initialize()
          }
        }
      }
      .navigationTitle("Time available").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.disabled(model.pending)
        }
      }
    }
    .onAppear {
      model.load()
      initialize()
    }
    .interactiveDismissDisabled(model.pending)
  }
  private var options: [Int] {
    Array(Set([30, 45, 60, 75, 0] + [model.saved?.preferredMinutes].compactMap { $0 })).sorted {
      a, b in
      if a == 0 { return false }
      if b == 0 { return true }
      return a < b
    }
  }
  private func initialize() {
    guard model.loaded, !initialized else { return }
    initialized = true
    minutes = model.saved?.preferredMinutes
  }
}

struct LastTrainedView: View {
  let logs: [ProgramLog]
  let profile: String
  @Binding var enabled: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Last trained").font(.title2.bold())
      Text("Days since each area appeared in a finished workout.").foregroundStyle(.secondary)
      Toggle("Show last trained", isOn: $enabled)
      Text(
        "Descriptive calendar days only. This does not estimate recovery or readiness and never changes a recommendation."
      ).font(.footnote).foregroundStyle(.secondary)
      if enabled {
        ContentUnavailableView(
          "Muscle mappings awaiting review", systemImage: "checklist",
          description: Text(
            "Your workout history is saved. Muscle-area counts will appear when the exercise-to-muscle catalog mappings are reviewed; no areas are inferred from exercise names."
          ))
      }
    }.padding().background(
      Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
  }
}

struct ExerciseExceptionSheet: View {
  let exercise: ProgramExercise
  @ObservedObject var setup: SetupModel
  let directory: URL
  var cue: (AppModel.Cue) -> Void
  let pain: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var reason: String?
  @State private var gym = false
  @State private var excluded = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(exercise.name).font(.headline)
          Text("\(exercise.sets) × \(exercise.minReps)–\(exercise.maxReps) · 2–3 RIR")
            .foregroundStyle(.secondary)
        }
        Section("What’s happening?") {
          Button("Equipment unavailable", systemImage: "wrench.and.screwdriver") {
            reason = "Equipment unavailable"
            gym = true
          }
          Button(
            "Cannot perform this movement", systemImage: "figure.stand.line.dotted.figure.stand"
          ) { reason = "Cannot perform this movement" }
          Button("Replace for today", systemImage: "arrow.triangle.2.circlepath") {
            reason = "Replace for today"
          }
          Button("Do not recommend again", systemImage: "nosign") {
            reason = "Do not recommend again"
          }
        }
        if let reason {
          Section(reason) {
            if reason == "Do not recommend again" {
              Text(
                "Choose the exact variation to exclude from future recommendations. Your saved manual plan and past records stay intact."
              )
              ForEach(setupVariantsFor(exercise), id: \.self) { variant in
                Button {
                  excluded = setup.exclude(variant)
                  cue(excluded ? .success : .error)
                } label: {
                  Label(
                    setupVariationNames[variant] ?? variant,
                    systemImage: setup.saved?.excludedVariations.contains(variant) == true
                      ? "checkmark.circle.fill" : "circle")
                }.disabled(
                  setup.locked || setup.saved?.excludedVariations.contains(variant) == true)
              }
              if excluded { Text("Exclusion saved on this device.").foregroundStyle(.secondary) }
            } else {
              Text(
                "Automatic replacements are unavailable until catalog, safety and exact setup checks are complete. No exercise has been replaced. You can leave sets unrecorded and finish early, or explicitly skip them in the set editor."
              )
              if reason == "Equipment unavailable" {
                Button("Update my gym checklist") { gym = true }
              }
            }
          }
        }
        Section {
          Button(role: .destructive) {
            dismiss()
            pain()
          } label: {
            Label("Pain or concerning symptom", systemImage: "exclamationmark.triangle")
          }
          Text(
            "Stop this exercise. Record the affected set’s actuals with Pain selected. Saving that record blocks further sets for this exercise. This is not a swap."
          ).font(.footnote)
        }
        if let error = setup.error { Text(error).foregroundStyle(.red) }
        if setup.pending { Button("Retry saved change") { cue(setup.retry() ? .success : .error) } }
      }
      .navigationTitle("Change exercise").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }.disabled(setup.pending)
        }
      }
      .sheet(isPresented: $gym) {
        NavigationStack {
          Form { GymSettingsView(directory: directory, cue: cue) }.navigationTitle("My gym")
            .toolbar {
              ToolbarItem(placement: .confirmationAction) { Button("Done") { gym = false } }
            }
        }
      }
    }.onAppear { setup.load() }.interactiveDismissDisabled(setup.pending)
  }
}
