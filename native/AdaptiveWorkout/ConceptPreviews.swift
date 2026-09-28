import SwiftUI
import WorkoutDomain

#if DEBUG
  /// Reference renderings of design concepts 2a–2c from "Adaptive Workout Mockups".
  /// Debug builds only, opened from Settings with `--concepts` or from Xcode previews.
  /// They show approved prescriptions from `ownerProgram` inside one labeled sample
  /// scenario. Nothing here saves, starts a workout, selects a replacement or changes
  /// a recommendation; those engine pieces are not integrated yet.
  private enum ConceptScenario {
    static let session = ownerProgram.first { $0.id == "wednesday" }!
    static let previous = ownerProgram.first { $0.id == "tuesday" }!
    static let unavailableSlot = "shoulder_press"
    static let replacementName = "Dumbbell Shoulder Press"
    static let usualMinutes = 60
  }

  private struct ConceptBanner: View {
    var body: some View {
      Label(
        "Design concept with a sample scenario: the shoulder press machine is marked unavailable. Not active in this build.",
        systemImage: "paintbrush"
      ).font(.footnote).foregroundStyle(.secondary)
    }
  }

  private func prescription(_ exercise: ProgramExercise) -> String {
    "\(exercise.sets) × \(exercise.minReps)–\(exercise.maxReps)"
  }

  /// 2a · The next session in plan order, ready on open with its reason.
  struct NextSessionConceptView: View {
    @State private var minutes: Int? = ConceptScenario.usualMinutes
    @State private var choosingLength = false
    @State private var changing: ProgramExercise?
    private let session = ConceptScenario.session
    private let previous = ConceptScenario.previous
    var body: some View {
      List {
        Section { ConceptBanner() }
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text(session.title).font(.largeTitle.bold())
            Text(
              "\(session.day) · \(session.exercises.count) exercises · \(session.exercises.reduce(0) { $0 + $1.sets }) working sets"
            ).foregroundStyle(.secondary)
          }
          Button {
            choosingLength = true
          } label: {
            Label(minutes.map { "\($0) min available" } ?? "No time limit", systemImage: "clock")
          }
          Button("Start workout") {}.buttonStyle(.borderedProminent).disabled(true)
        } header: {
          HStack {
            Text("Next in your plan")
            Spacer()
            Button("Change") {}.disabled(true)
          }
        }
        Section("Why this workout") {
          Text("It’s next in your plan order. You finished \(previous.title) yesterday.")
          Label("Order · follows \(previous.day), \(previous.title)", systemImage: "list.number")
          Label(
            "Equipment · 1 swap: the shoulder press machine is marked unavailable",
            systemImage: "wrench.and.screwdriver")
          Label(
            "Loads · not suggested until baselines are verified", systemImage: "scalemass")
        }
        Section("Exercises") {
          ForEach(Array(session.blocks.enumerated()), id: \.offset) { _, block in
            if block.isSuperset {
              VStack(alignment: .leading, spacing: 4) {
                Text(block.exercises.map(\.name).joined(separator: " + ")).font(.headline)
                Text("Superset · \(block.exercises[0].sets) paired rounds")
                  .font(.subheadline).foregroundStyle(.secondary)
              }
            } else if let exercise = block.exercises.first {
              let swapped = exercise.id == ConceptScenario.unavailableSlot
              Button {
                changing = exercise
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(swapped ? ConceptScenario.replacementName : exercise.name).font(.headline)
                  Text(prescription(exercise) + (swapped ? " · replaces the machine today" : ""))
                    .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              }.foregroundStyle(.primary).accessibilityHint("Opens Change exercise")
            }
          }
        }
      }
      .navigationTitle("Workout")
      .sheet(isPresented: $choosingLength) { SessionLengthConceptSheet(minutes: $minutes) }
      .sheet(item: $changing) { ChangeExerciseConceptSheet(exercise: $0) }
    }
  }

  /// 2b · Session length. Duration is an advisory preference; nothing is removed.
  struct SessionLengthConceptSheet: View {
    @Binding var minutes: Int?
    @State private var choice: Int?
    @Environment(\.dismiss) private var dismiss
    private let options: [Int?] = [30, 45, 60, 75, nil]
    init(minutes: Binding<Int?>) {
      _minutes = minutes
      _choice = State(initialValue: minutes.wrappedValue)
    }
    var body: some View {
      NavigationStack {
        List {
          Section { ConceptBanner() }
          Section {
            ForEach(options, id: \.self) { value in
              Button {
                choice = value
              } label: {
                HStack {
                  Text(label(value))
                  if value == ConceptScenario.usualMinutes {
                    Text("Usual").font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  if choice == value { Image(systemName: "checkmark").accessibilityHidden(true) }
                }.frame(minHeight: 44)
              }.foregroundStyle(.primary)
                .accessibilityAddTraits(choice == value ? .isSelected : [])
            }
          } header: {
            Text("How long do you have today?")
          } footer: {
            Text("Your usual is \(ConceptScenario.usualMinutes) min. Saved on this device.")
          }
          Section {
            Text(
              "Rules for fitting a session into less time aren’t approved yet, so nothing is removed from your plan. The time is saved for when they are."
            ).font(.footnote)
          }
        }
        .navigationTitle("Time available")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .safeAreaInset(edge: .bottom) {
          Button {
            minutes = choice
            dismiss()
          } label: {
            Text("Use \(label(choice))").frame(maxWidth: .infinity, minHeight: 44)
          }.buttonStyle(.borderedProminent).padding()
        }
      }
    }
    private func label(_ value: Int?) -> String { value.map { "\($0) min" } ?? "No time limit" }
  }

  /// 2c · The five approved exception controls from PRODUCT.md. The user reports what
  /// happened; the engine would pick any replacement. Pain is separate and is never a
  /// swap; its wording still needs clinical review.
  struct ChangeExerciseConceptSheet: View {
    let exercise: ProgramExercise
    @State private var reported: String?
    @Environment(\.dismiss) private var dismiss
    private struct Exception: Identifiable {
      let title: String, detail: String, symbol: String
      var id: String { title }
    }
    private let exceptions = [
      Exception(
        title: "Equipment unavailable", detail: "Busy, missing or out of order today",
        symbol: "wrench.and.screwdriver"),
      Exception(
        title: "Cannot perform this movement",
        detail: "The setup or movement doesn’t work for you", symbol: "hand.raised"),
      Exception(
        title: "Replace for today", detail: "Keeps it in your plan for next time",
        symbol: "arrow.triangle.2.circlepath"),
      Exception(
        title: "Do not recommend again", detail: "Adds it to your exclusions in Training setup",
        symbol: "nosign"),
    ]
    var body: some View {
      NavigationStack {
        List {
          Section { ConceptBanner() }
          Section {
            VStack(alignment: .leading, spacing: 4) {
              Text(exercise.name).font(.title2.weight(.semibold))
              Text("\(prescription(exercise)) · no sets recorded").foregroundStyle(.secondary)
            }
          }
          Section("What’s happening?") {
            ForEach(exceptions) { item in
              Button {
                reported = item.title
              } label: {
                Label {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.headline)
                    Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                  }
                } icon: {
                  Image(systemName: item.symbol)
                }.frame(minHeight: 44)
              }.foregroundStyle(.primary)
            }
          }
          Section {
            Button(role: .destructive) {
              reported = "Pain or concerning symptom"
            } label: {
              Label {
                VStack(alignment: .leading, spacing: 2) {
                  Text("Pain or concerning symptom").font(.headline)
                  Text("Stops this exercise. This is not a swap.").font(.subheadline)
                }
              } icon: {
                Image(systemName: "exclamationmark.triangle")
              }.frame(minHeight: 44)
            }
          } footer: {
            Text(
              "Replacements come only from approved alternatives with a verified setup. The reason is shown with the new exercise."
            )
          }
          if let reported {
            Section {
              Text(
                "“\(reported)” would be reported here. Replacements and the pain safety flow are not active in this build, so nothing changed."
              )
            }
          }
        }
        .navigationTitle("Change exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
      }
    }
  }

  #Preview("2a Next session") { NavigationStack { NextSessionConceptView() } }
  #Preview("2b Session length") { SessionLengthConceptSheet(minutes: .constant(60)) }
  #Preview("2c Change exercise") {
    ChangeExerciseConceptSheet(exercise: ownerProgram[2].blocks[0].exercises[0])
  }
#endif
