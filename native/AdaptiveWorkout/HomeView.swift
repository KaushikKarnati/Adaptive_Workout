import Combine
import SwiftUI
import WorkoutApplication
import WorkoutDomain

struct HomeView: View {
  @ObservedObject var controller: ProgramLogController
  @ObservedObject var model: AppModel
  @State private var tab = 0
  var body: some View {
    TabView(selection: $tab) {
      WorkoutView(controller: controller, model: model, visible: tab == 0)
        .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }.tag(0)
      SettingsView(
        directory: model.directory, notifications: model.notifications,
        exerciseReferences: model.exerciseReferences, appearance: model.appearanceBinding,
        hapticsEnabled: model.hapticsBinding, cue: model.cue
      )
      .tabItem { Label("Settings", systemImage: "gearshape") }.tag(1)
    }
    .onChange(of: tab) { model.cue(.selection) }
    .task { await controller.load() }
    .alert(
      "Appearance unavailable",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("Retry") { model.retryAppearance() }
      Button("OK") { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
  }
}

private struct SetEditorRequest: Identifiable {
  let id = UUID()
  let log: ProgramLog
  let exercise: ProgramExercise
  let index: Int
  let side: LoggedSide
  let warmup: Bool
}

struct WorkoutView: View {
  @ObservedObject var controller: ProgramLogController
  @ObservedObject var model: AppModel
  let visible: Bool
  @Environment(\.scenePhase) private var scenePhase
  @State private var mode = 0
  @State private var historyQuery = ""
  @State private var historyDays = 0
  @State private var historyRepetitionMetrics: [ExerciseSeriesKey: Bool] = [:]
  @State private var editor: SetEditorRequest?
  @State private var choosing = false
  @State private var switchTarget: ProgramSession?
  @State private var deleting: ProgramLog?
  @State private var earlyFinish = false
  @State private var rest = RestCountdown()
  @State private var completionArmed = false
  @State private var now = Date()
  private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  var body: some View {
    NavigationView {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Picker("Workout view", selection: $mode) {
              Text("Log").tag(0)
              Text("History").tag(1)
              Text("Graphs").tag(2)
            }.pickerStyle(.segmented).disabled(controller.locked).id("workout_home")
            if let error = controller.error {
              VStack(alignment: .leading, spacing: 8) {
                if let pending = controller.pendingChange { pendingNotice(pending) }
                Text(error).foregroundColor(.red)
                Button("Retry") {
                  Task {
                    if controller.locked {
                      feedback(await controller.retry())
                    } else {
                      await controller.load()
                    }
                  }
                }
              }.accessibilityElement(children: .contain)
            }
            if controller.busy { ProgressView().accessibilityLabel("Saving") }
            if mode == 0 {
              logger
            } else {
              HistoryView(
                logs: controller.logs, profile: controller.profile, graphs: mode == 2,
                query: $historyQuery, days: $historyDays,
                repetitionMetrics: $historyRepetitionMetrics, cue: model.cue,
                open: { log in
                  controller.select(log.id)
                  mode = 0
                },
                delete: { log in
                  deleting = log
                  model.cue(.warning)
                })
            }
          }.padding().frame(maxWidth: 720)
        }
        .onChange(of: controller.selected?.currentTarget?.id) { _, target in
          withAnimation { proxy.scrollTo(target ?? "workout_home", anchor: .center) }
        }
        .onChange(of: controller.selectedID) { _, id in
          if id == nil { withAnimation { proxy.scrollTo("workout_home", anchor: .top) } }
        }
      }
      .navigationTitle("Workout")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Choose workout") { choosing = true }.disabled(controller.locked)
        }
      }
      .safeAreaInset(edge: .bottom) {
        if let log = controller.selected, mode == 0 { timerPanel(log) }
      }
    }.navigationViewStyle(.stack)
      .sheet(isPresented: $choosing) {
        NavigationView {
          List(ownerProgram) { plan in
            Button {
              choosing = false
              choose(plan)
            } label: {
              VStack(alignment: .leading) {
                Text(plan.day)
                Text(plan.title).font(.subheadline).foregroundColor(.secondary)
              }
            }.accessibilityIdentifier("choose_" + plan.id)
          }.navigationTitle("Today's workout")
            .toolbar {
              ToolbarItem(placement: .cancellationAction) { Button("Cancel") { choosing = false } }
            }
            .safeAreaInset(edge: .bottom) {
              Text("Day names are labels from your original plan. Choose any workout for today.")
                .font(.footnote).padding()
            }
        }.navigationViewStyle(.stack)
      }
      .sheet(item: $editor) { request in
        SetEditor(
          log: request.log, exercise: request.exercise, index: request.index, side: request.side,
          warmup: request.warmup, cue: model.cue
        ) { set in
          Task { feedback(await controller.record(set)) }
        }.interactiveDismissDisabled()
      }
      .alert(
        "Finish current workout early?",
        isPresented: Binding(get: { switchTarget != nil }, set: { if !$0 { switchTarget = nil } })
      ) {
        Button("Keep current workout", role: .cancel) { switchTarget = nil }
        Button("Finish early and continue") {
          guard let target = switchTarget, let draft = controller.draft else { return }
          switchTarget = nil
          controller.select(draft.id)
          Task {
            if await controller.finish(endEarly: true) {
              feedback(await controller.start(target.id))
              mode = 0
            } else {
              model.cue(.error)
            }
          }
        }
      } message: {
        Text(
          "Keep the saved sets and finish the unfinished workout before starting another. Unrecorded sets stay unrecorded."
        )
      }
      .alert("Finish workout early?", isPresented: $earlyFinish) {
        Button("Keep logging", role: .cancel) {}
        Button("Finish early") { Task { feedback(await controller.finish(endEarly: true)) } }
      } message: {
        Text("Saved sets will remain. Unrecorded sets will remain unrecorded.")
      }
      .alert(
        "Delete workout?",
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
      ) {
        Button("Cancel", role: .cancel) { deleting = nil }
        Button("Delete", role: .destructive) {
          if let log = deleting {
            deleting = nil
            Task { feedback(await controller.delete(log)) }
          }
        }
      } message: {
        if let log = deleting {
          Text(
            "Delete \(log.plan.day) · \(log.plan.title), started \(log.startedAt.formatted()), with \(log.sets.count) saved records? This cannot be undone."
          )
        }
      }
      .onChange(of: controller.selectedID) {
        rest.clear()
        model.notifications.clearRest()
        completionArmed = false
      }
      .onChange(of: controller.selected?.completed) { _, complete in
        if complete == true {
          rest.clear()
          model.notifications.clearRest()
          completionArmed = false
        }
      }
      .onChange(of: visible) { arm() }
      .onChange(of: scenePhase) { arm() }
      .onChange(of: mode) {
        model.cue(.selection)
        arm()
        if mode != 0 { Task { await controller.load() } }
      }
      .onReceive(tick) { value in
        guard visible, mode == 0, scenePhase == .active else { return }
        now = value
        if completionArmed, rest.remaining(now: value) == 0 {
          completionArmed = false
          model.cue(.success)
        }
      }
  }
  private func feedback(_ succeeded: Bool) { model.cue(succeeded ? .success : .error) }
  private func arm() {
    now = Date()
    completionArmed =
      visible && mode == 0 && scenePhase == .active && controller.selected?.completed == false
      && rest.remaining(now: now) > 0
  }
  private func choose(_ plan: ProgramSession) {
    if let draft = controller.draft, draft.programId != plan.id {
      switchTarget = plan
      model.cue(.warning)
    } else {
      Task {
        feedback(await controller.start(plan.id))
        mode = 0
      }
    }
  }
  @ViewBuilder private var logger: some View {
    if let log = controller.selected {
      VStack(alignment: .leading, spacing: 8) {
        Text(log.plan.title).font(.title2.bold())
        Text(
          "\(log.plan.day) · \(log.endedEarly ? "Finished early" : log.completed ? "Completed" : "In progress")"
        ).foregroundColor(.secondary)
        Text("Manual records do not establish progression baselines.").font(.footnote)
          .foregroundColor(.secondary)
        if log.sets.contains(where: { $0.validity == .pain }) {
          Text(
            "Pain was recorded. Further sets for that exercise are stopped; remaining sets may be skipped."
          ).foregroundColor(.red)
        }
      }
      ForEach(Array(log.plan.blocks.enumerated()), id: \.offset) { _, block in
        VStack(alignment: .leading, spacing: 16) {
          if block.isSuperset {
            Text("Paired exercises · alternate working rounds").font(.headline)
          }
          ForEach(block.exercises) { exercise in
            VStack(alignment: .leading, spacing: 8) {
              Text(exercise.name).font(.headline)
              Text(
                "\(exercise.sets) × \(exercise.minReps)–\(exercise.maxReps) reps · RIR 2–3\(exercise.eachSide ? " · each side" : "")"
              ).font(.subheadline).foregroundColor(.secondary)
              ForEach(1...exercise.sets, id: \.self) { index in
                ForEach(exercise.eachSide ? [LoggedSide.left, .right] : [.both], id: \.rawValue) {
                  side in
                  setRow(log, exercise, index, side, false)
                }
              }
              ForEach(log.sets.filter { $0.slot == exercise.id && $0.warmup }, id: \.key) { set in
                setRow(log, exercise, set.index, set.side, true)
              }
              if !log.completed {
                ForEach(exercise.eachSide ? [LoggedSide.left, .right] : [.both], id: \.rawValue) {
                  side in
                  Button("Add warm-up\(side == .both ? "" : " · " + side.rawValue)") {
                    let index =
                      (log.sets.filter { $0.slot == exercise.id && $0.warmup && $0.side == side }
                        .map(\.index).max() ?? 0) + 1
                    editor = SetEditorRequest(
                      log: log, exercise: exercise, index: index, side: side, warmup: true)
                  }.disabled(controller.locked)
                }
              }
            }
          }
          if !log.completed {
            Button("Start \(block.restSeconds)s rest") {
              do {
                try rest.start(seconds: block.restSeconds, now: Date())
                model.notifications.startRest(seconds: block.restSeconds)
                arm()
                model.cue(.impact)
              } catch { model.cue(.error) }
            }.disabled(controller.locked)
            Text(
              block.isSuperset
                ? "Start after both exercises."
                : block.exercises.contains(where: \.eachSide)
                  ? "Start after both sides." : "Start after the working set."
            ).font(.caption).foregroundColor(.secondary)
          }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(
          Color(.secondarySystemGroupedBackground)
        ).cornerRadius(16)
      }
      if !log.completed {
        Button("Finish workout") { Task { feedback(await controller.finish()) } }.buttonStyle(
          .borderedProminent
        ).disabled(controller.locked)
        Button("Finish early") {
          earlyFinish = true
          model.cue(.warning)
        }.disabled(controller.locked)
      }
      Button("Delete workout", role: .destructive) {
        deleting = log
        model.cue(.warning)
      }.disabled(controller.locked)
    } else {
      Text("Ready when you are").font(.title2.bold())
      Text("Choose today's workout or resume your saved draft.").foregroundColor(.secondary)
      if let draft = controller.draft {
        Button("Resume \(draft.plan.day)") { controller.select(draft.id) }.buttonStyle(
          .borderedProminent
        ).disabled(controller.locked)
      }
      ForEach(ownerProgram) { plan in
        Button {
          choose(plan)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text("Start \(plan.day)").font(.headline)
            Text(plan.title).foregroundColor(.secondary)
          }.frame(maxWidth: .infinity, alignment: .leading).padding()
        }.buttonStyle(.bordered).disabled(controller.locked).accessibilityIdentifier(
          "start_" + plan.id)
      }
    }
  }
  private func setRow(
    _ log: ProgramLog, _ exercise: ProgramExercise, _ index: Int, _ side: LoggedSide, _ warmup: Bool
  ) -> some View {
    let saved = log.sets.first {
      $0.slot == exercise.id && $0.index == index && $0.side == side && $0.warmup == warmup
    }
    let rowID = "set_\(exercise.id)_\(index)_\(side.rawValue)_\(warmup)"
    let current = log.currentTarget?.id == rowID
    return Button {
      editor = SetEditorRequest(
        log: log, exercise: exercise, index: index, side: side, warmup: warmup)
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        if current {
          Label("Current set", systemImage: "arrow.right.circle.fill").font(.caption.bold())
        }
        Text("\(warmup ? "Warm-up" : "Set") \(index)\(side == .both ? "" : " · " + side.rawValue)")
        Text(saved.map(setSummary) ?? "Not recorded").font(.subheadline).foregroundColor(.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }.disabled(controller.locked || (log.completed && saved == nil))
      .padding(.horizontal, 8)
      .background(current ? Color.accentColor.opacity(0.15) : Color.clear)
      .cornerRadius(10)
      .id(rowID)
      .accessibilityIdentifier(rowID)
  }
  private func pendingNotice(_ change: PendingProgramLogChange) -> some View {
    let title: String
    switch change.kind {
    case .start: title = "Unconfirmed workout start"
    case .set: title = "Unconfirmed entry"
    case .correction: title = "Unconfirmed correction"
    case .finish: title = "Unconfirmed workout finish"
    case .earlyFinish: title = "Unconfirmed early finish"
    case .deletion: title = "Unconfirmed deletion"
    }
    return VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: "exclamationmark.triangle").font(.headline)
      Text("\(change.log.plan.day) · \(change.log.plan.title)").font(.subheadline)
      ForEach(change.submittedSets) { set in
        VStack(alignment: .leading, spacing: 4) {
          Text(change.log.exercises.first { $0.id == set.slot }?.name ?? set.slot).font(
            .subheadline.bold())
          Text(
            "\(set.warmup ? "Warm-up" : "Working set") \(set.index) · \(set.side == .both ? "Both sides" : set.side.rawValue.capitalized)"
          )
          Text("Variation: \(set.variant.replacingOccurrences(of: "_", with: " "))")
          Text("Setup: \(set.setup)")
          Text(conventionLabel(set.convention))
          Text(setSummary(set))
        }.font(.subheadline)
      }
      if change.kind == .start {
        Text("Started \(change.log.startedAt.formatted()).").font(.subheadline)
      } else if change.kind == .finish || change.kind == .earlyFinish {
        if let completedAt = change.log.completedAt {
          Text("Finish time: \(completedAt.formatted()).").font(.subheadline)
        }
        Text("\(change.log.sets.count) recorded sets retained.").font(.subheadline)
      } else if change.kind == .deletion {
        Text(
          "Started \(change.log.startedAt.formatted()) · \(change.log.sets.count) recorded sets."
        ).font(.subheadline)
      }
      Text("This action is not confirmed. Retry uses these same values.").font(.footnote)
    }.padding().frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.orange.opacity(0.12)).cornerRadius(12)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("unconfirmed_workout_action")
  }
  private func timerPanel(_ log: ProgramLog) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(
        "\(log.completed ? "Total time" : "Workout time")  \(timerText(sessionElapsed(start: log.startedAt, end: log.completedAt, now: now)))"
      ).monospacedDigit()
      if !log.completed && rest.started {
        RestNotificationStatus(model: model.notifications)
        HStack {
          Text(
            rest.remaining(now: now) == 0
              ? "Rest complete" : "Rest  \(timerText(rest.remaining(now: now)))"
          ).monospacedDigit()
          Button("Clear rest") {
            rest.clear()
            model.notifications.clearRest()
            completionArmed = false
            model.cue(.selection)
          }
        }
      }
    }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding().background(
      .regularMaterial)
  }
}

func setSummary(_ set: ProgramSet) -> String {
  if set.skipped { return "Skipped" }
  let load =
    set.load.map { formatPounds($0) + (set.convention == .assistance ? " lb support" : " lb") }
    ?? "Bodyweight"
  return
    "\(load) · \(set.reps ?? 0) reps · \(set.rir.map { "RIR \($0)" } ?? "RIR unknown") · \(set.validity.rawValue)"
}
