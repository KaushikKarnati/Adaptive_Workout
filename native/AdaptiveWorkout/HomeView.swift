import Combine
import SwiftUI
import WorkoutApplication
import WorkoutDomain

struct HomeView: View {
  @ObservedObject var controller: ProgramLogController
  @ObservedObject var model: AppModel
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var tab = 0
  @State private var mode = 0
  @StateObject private var setup: SetupModel
  init(controller: ProgramLogController, model: AppModel) {
    self.controller = controller
    self.model = model
    _setup = StateObject(wrappedValue: SetupModel(directory: model.directory))
  }
  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        WorkoutView(
          controller: controller, model: model, setup: setup,
          visible: tab == 0 || tab == 2, mode: $mode, profile: { tab = 3 }
        )
        .opacity(tab == 0 || tab == 2 ? 1 : 0)
        .allowsHitTesting(tab == 0 || tab == 2)
        .accessibilityHidden(tab != 0 && tab != 2)
        if tab == 1 {
          NavigationStack {
            ScrollView {
              VStack(alignment: .leading, spacing: 16) {
                Text("Your Training Plan").font(Stitch.font(32, .semibold))
                Text("Approved manual prescriptions • Original day labels")
                  .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
                ForEach(ownerProgram, id: \.id) { plan in
                  VStack(alignment: .leading, spacing: 12) {
                    StitchLabel(text: plan.day)
                    Text(plan.title).font(Stitch.font(22, .semibold))
                    ForEach(Array(plan.blocks.enumerated()), id: \.offset) { _, block in
                      ForEach(block.exercises) { exercise in
                        Text(exercise.name).font(Stitch.font(16, .medium))
                        Text(
                          "\(exercise.sets) × \(exercise.minReps)–\(exercise.maxReps) reps • 2–3 RIR\(exercise.eachSide ? " • each side" : "")"
                        )
                        .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
                      }
                      Text(
                        "Rest \(block.restSeconds)s \(block.isSuperset ? "after pair" : block.exercises.contains(where: \.eachSide) ? "after both sides" : "between sets")"
                      )
                      .font(Stitch.font(12)).foregroundStyle(Stitch.amber)
                    }
                  }.modifier(StitchCard())
                }
                Text(
                  "Thursday • Recovery: no lifting, easy walking, optional light mobility; supplied plan target 8,000–10,000 total steps. Alternatives and setup requirements remain in Profile → Your program."
                )
                .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
              }.padding(16).frame(maxWidth: 720)
            }.background(Stitch.canvas).navigationTitle("Plan").navigationBarTitleDisplayMode(
              .inline)
          }
        }
        SettingsView(
          directory: model.directory, notifications: model.notifications,
          exerciseReferences: model.exerciseReferences, setupModel: setup,
          appearance: model.appearanceBinding,
          hapticsEnabled: model.hapticsBinding, cue: model.cue
        ).opacity(tab == 3 ? 1 : 0).allowsHitTesting(tab == 3).accessibilityHidden(tab != 3)
      }
      HStack(spacing: 0) {
        tabButton("Workout", icon: "dumbbell", value: 0)
        tabButton("Plan", icon: "calendar", value: 1)
        tabButton("History", icon: "clock.arrow.circlepath", value: 2)
        tabButton("Profile", icon: "person.crop.circle", value: 3)
      }.padding(.top, 8).background(Stitch.canvas)
    }
    .background(Stitch.canvas)
    .tint(Stitch.amber).foregroundStyle(Stitch.ink).font(Stitch.font(16))
    .onChange(of: mode) { if mode == 0 && tab == 2 { tab = 0 } }
    .onChange(of: tab) {
      UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      if tab == 0 { mode = 0 }
      if tab == 2 { mode = 1 }
      model.cue(.selection)
    }
    .task {
      await controller.load()
      await model.adaptiveController?.load()
    }
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
  private func tabButton(_ title: String, icon: String, value: Int) -> some View {
    Button {
      tab = value
    } label: {
      VStack(spacing: 5) {
        Image(systemName: icon).font(.system(size: 20))
        if !typeSize.isAccessibilitySize {
          Text(title).font(Stitch.font(11, .medium)).tracking(0.5)
        }
      }.frame(maxWidth: .infinity, minHeight: 52)
        .foregroundStyle(tab == value ? Stitch.amber : Stitch.secondary)
        .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(title).accessibilityIdentifier(
      "tab_" + title.lowercased()
    )
    .accessibilityAddTraits(tab == value ? .isSelected : [])
  }

}

private struct SetEditorRequest: Identifiable {
  let id = UUID()
  let log: ProgramLog
  let exercise: ProgramExercise
  let index: Int
  let side: LoggedSide
  let warmup: Bool
  var initialValidity: SetValidity? = nil
  var skipOnly = false
}

struct WorkoutView: View {
  @ObservedObject var controller: ProgramLogController
  @ObservedObject var model: AppModel
  @ObservedObject var setup: SetupModel
  let visible: Bool
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase
  @Binding var mode: Int
  var profile: () -> Void
  @State private var hub = true
  @State private var reviewCompleted = false
  @ScaledMetric(relativeTo: .body) private var focusTileWidth = 105.0
  @State private var historyMode = 0
  @State private var durationSheet = false
  @State private var exception: ProgramExercise?
  @State private var pendingPainExercise: ProgramExercise?
  @State private var expanded: Set<String> = []
  @State private var focusedExercise: String?
  @State private var restDuration = 0
  @State private var historyQuery = ""
  @State private var historyDays = 0
  @State private var historyRepetitionMetrics: [ExerciseSeriesKey: Bool] = [:]
  @State private var editor: SetEditorRequest?
  @State private var completedSummary: ProgramLog?
  @State private var choosing = false
  @State private var switchTarget: ProgramSession?
  @State private var deleting: ProgramLog?
  @State private var earlyFinish = false
  @State private var rest = RestCountdown()
  @State private var completionArmed = false
  @State private var now = Date()
  @State private var engineMode = 0
  private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
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
            if (hub || engineMode == 1) && controller.selected == nil && !choosing {
              Picker("Workout Engine", selection: $engineMode) {
                Text("Manual Plan").tag(0)
                Text("Adaptive Engine").tag(1)
              }
              .pickerStyle(.segmented)
              .accessibilityIdentifier("workout_engine_picker")
              .onChange(of: engineMode) {
                model.cue(.selection)
                if engineMode == 1 {
                  Task { await model.adaptiveController?.load() }
                }
              }
            }
            if engineMode == 1 {
              if let adaptive = model.adaptiveController {
                AdaptiveWorkoutView(
                  adaptiveController: adaptive,
                  model: model,
                  setup: setup,
                  profile: profile,
                  switchToManual: { engineMode = 0 }
                )
              } else {
                Text(
                  "Adaptive recommendations are unavailable while catalog review, explicit setup verification, and consistent input storage are pending. Continue with Manual Plan."
                )
              }
            } else if choosing {
              sessionSelection
            } else if hub {
              if model.adaptiveController?.activeWorkout != nil {
                HStack {
                  Circle().fill(Stitch.green).frame(width: 8, height: 8)
                  StitchLabel(text: "Active adaptive workout")
                  Spacer(minLength: 0)
                  Button("Resume Adaptive →") { engineMode = 1 }
                    .font(Stitch.font(13, .semibold))
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(Stitch.peach, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("resume_adaptive_banner")
                }
                .modifier(StitchCard(padding: 10))
              } else if let adaptive = model.adaptiveController,
                adaptive.latestRecommendation == nil
                  || adaptive.latestRecommendation?.status != .ready
              {
                calibrationMiniBanner(adaptive.calibrationProgress)
              }
              dashboard
            } else if let log = controller.selected ?? completedSummary, log.completed,
              !reviewCompleted
            {
              StitchSummary(
                log: log,
                next: {
                  completedSummary = nil
                  controller.select(nil)
                  hub = true
                },
                corrections: {
                  controller.select(log.id)
                  completedSummary = nil
                  reviewCompleted = true
                })
            } else {
              logger
            }
          } else {
            Picker("History view", selection: $historyMode) {
              Text("Workouts").tag(0)
              Text("Recorded trends").tag(1)
              Text("Last trained").tag(2)
            }.pickerStyle(.segmented).accessibilityIdentifier("history_mode").onChange(
              of: historyMode
            ) { model.cue(.selection) }
            if historyMode == 2 {
              LastTrainedView(
                logs: controller.logs, profile: controller.profile,
                enabled: model.lastTrainedBinding)
            } else {
              HistoryView(
                logs: controller.logs, profile: controller.profile, graphs: historyMode == 1,
                query: $historyQuery, days: $historyDays,
                repetitionMetrics: $historyRepetitionMetrics, cue: model.cue,
                open: { log in
                  controller.select(log.id)
                  mode = 0
                  hub = false
                  reviewCompleted = false
                  choosing = false
                },
                delete: { log in
                  deleting = log
                  model.cue(.warning)
                })
            }
          }
        }.padding().frame(maxWidth: 720)
      }
      .id(
        "\(mode)-\(engineMode)-\(hub)-\(choosing)-\((controller.selected ?? completedSummary)?.completed ?? false)-\(reviewCompleted)"
      )
      .background(Stitch.canvas)
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top, spacing: 0) {
        HStack(spacing: 12) {
          if (!hub && mode == 0 && !choosing) || (engineMode == 1 && mode == 0) {
            Button {
              if engineMode == 1 {
                engineMode = 0
              } else {
                hub = true
              }
            } label: {
              Image(systemName: "chevron.left").font(.system(size: 22))
            }
            .frame(width: 32, height: 44)
            .accessibilityLabel(engineMode == 1 ? "Back to manual plan" : "Back to dashboard")
          }
          Text(
            typeSize.isAccessibilitySize
              ? (mode == 1 ? "History" : engineMode == 1 ? "Adaptive" : "Workout")
              : mode == 1
                ? "History"
                : choosing
                  ? "Choose workout"
                  : engineMode == 1
                    ? (model.adaptiveController?.activeWorkout != nil
                      ? "Active Adaptive Workout" : "Adaptive Engine")
                    : hub
                      ? "Workout"
                      : (controller.selected ?? completedSummary)?.completed == true
                        && !reviewCompleted
                        ? "Workout Summary" : "Active Workout"
          )
          .font(Stitch.font(typeSize.isAccessibilitySize ? 14 : 18, .semibold))
          Spacer(minLength: 0)
          if engineMode == 0 {
            Button {
              choosing.toggle()
              mode = 0
            } label: {
              Image(systemName: choosing ? "checkmark" : "slider.horizontal.3").font(
                .system(size: 20)
              ).frame(
                width: 44, height: 44)
            }.accessibilityLabel(choosing ? "Done" : "Choose workout").disabled(controller.locked)
          }
          Button(action: profile) {
            Image(systemName: "person.crop.circle").font(.system(size: 20))
              .foregroundStyle(.white).frame(width: 34, height: 34)
              .background(Color(red: 137 / 255, green: 77 / 255, blue: 0), in: Circle())
              .frame(width: 44, height: 44)
          }.accessibilityLabel("Profile")
        }.padding(.horizontal, 16).frame(minHeight: 56).background(Stitch.canvas)
      }
      .safeAreaInset(edge: .bottom) {
        if let log = controller.selected, !log.completed, mode == 0, !choosing, !hub {
          timerPanel(log)
        }
      }
    }.navigationViewStyle(.stack)
      .sheet(isPresented: $durationSheet) { DurationSheet(model: setup, cue: model.cue) }
      .sheet(
        item: $exception,
        onDismiss: {
          if let exercise = pendingPainExercise {
            pendingPainExercise = nil
            if let log = controller.selected {
              let slot = manualWorkingSlots(log).first {
                $0.exercise.id == exercise.id && $0.record(in: log) == nil
              }
              if let slot {
                editor = SetEditorRequest(
                  log: log, exercise: exercise, index: slot.index, side: slot.side, warmup: false,
                  initialValidity: .pain)
              }
            }
          }
        }
      ) { exercise in
        ExerciseExceptionSheet(
          exercise: exercise, setup: setup, directory: model.directory, cue: model.cue
        ) {
          pendingPainExercise = exercise
        }
      }
      .sheet(item: $editor) { request in
        SetEditor(
          log: request.log, exercise: request.exercise, index: request.index, side: request.side,
          warmup: request.warmup, initialValidity: request.initialValidity,
          skipOnly: request.skipOnly, cue: model.cue
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
      .onChange(of: controller.selectedID) { previous, current in
        if current == nil, let previous,
          let finished = controller.logs.first(where: { $0.id == previous && $0.completed })
        {
          completedSummary = finished
          reviewCompleted = false
        } else if current != nil {
          completedSummary = nil
        }
        rest.clear()
        model.notifications.clearRest()
        completionArmed = false
        focusedExercise = nil
        expanded = []
      }
      .onChange(of: controller.selected?.completed) { _, complete in
        if complete == true {
          rest.clear()
          model.notifications.clearRest()
          completionArmed = false
          Task { await model.adaptiveController?.load() }
        }
      }
      .onChange(of: hub) { arm() }
      .onChange(of: visible) { arm() }
      .onChange(of: scenePhase) { arm() }
      .onChange(of: mode) {
        model.cue(.selection)
        arm()
        Task {
          await controller.load()
          await model.adaptiveController?.load()
        }
      }
      .onChange(of: model.adaptiveController?.activeWorkout != nil) { _, hasActive in
        if hasActive { engineMode = 1 }
      }
      .onReceive(tick) { value in
        guard visible, mode == 0, !hub, scenePhase == .active else { return }
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
      visible && mode == 0 && !hub && scenePhase == .active
      && controller.selected?.completed == false
      && rest.remaining(now: now) > 0
  }
  private func choose(_ plan: ProgramSession) {
    choosing = false
    hub = false
    reviewCompleted = false
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
        if model.loggingLayout == "focus" {
          Text("Manual log · " + log.plan.title).font(Stitch.font(14)).foregroundStyle(.secondary)
        } else {
          StitchLabel(text: "Manual workout • saved on device")
          Text(log.plan.title).font(Stitch.font(28, .semibold))
        }
        Label(
          log.endedEarly
            ? "Finished early" : log.completed ? "Finished" : "Draft · Each accepted set is saved",
          systemImage: log.completed ? "checkmark.circle" : "circle.dotted"
        )
        .font(Stitch.font(12)).foregroundStyle(.secondary)
        if model.loggingLayout != "focus" {
          Text("Manual records do not establish progression baselines.").font(Stitch.font(12))
            .foregroundStyle(.secondary)
        }
        if log.sets.contains(where: { $0.validity == .pain }) {
          Label(
            "Pain was recorded. Further sets for that exercise are stopped; remaining sets may be skipped.",
            systemImage: "exclamationmark.triangle"
          )
          .foregroundStyle(.red)
        }
      }
      Picker("Logging layout", selection: model.loggingLayoutBinding) {
        Text("Cards").tag("cards")
        Text("Table").tag("table")
        Text("Focus").tag("focus")
      }.pickerStyle(.segmented).accessibilityIdentifier("logging_layout")
      if model.loggingLayout == "focus" {
        focusSession(log)
      } else {
        ForEach(Array(log.plan.blocks.enumerated()), id: \.offset) { blockIndex, block in
          VStack(alignment: .leading, spacing: 16) {
            if block.isSuperset {
              Text("Superset · \(block.exercises.first?.sets ?? 0) paired rounds").font(.headline)
              Text("Rest \(block.restSeconds) sec after both exercises").font(Stitch.font(12))
                .foregroundStyle(.secondary)
            }
            ForEach(Array(block.exercises.enumerated()), id: \.element.id) { index, exercise in
              exerciseCard(
                log, exercise, restSeconds: block.restSeconds,
                prefix: block.isSuperset ? "\(index + 1) · " : "")
            }
            if !log.completed { restButton(block) }
          }
        }
      }
      if !log.completed {
        Button("Finish workout") { Task { feedback(await controller.finish()) } }
          .buttonStyle(StitchPrimary()).frame(minHeight: 52).disabled(controller.locked)
        Button("Finish early") {
          earlyFinish = true
          model.cue(.warning)
        }
        .frame(minHeight: 44).disabled(controller.locked)
      }
      if log.completed {
        Button("Next workout") {
          controller.select(nil)
          focusedExercise = nil
        }
        .buttonStyle(.borderedProminent).frame(minHeight: 52).disabled(controller.locked)
      }
      Button("Delete workout", role: .destructive) {
        deleting = log
        model.cue(.warning)
      }
      .frame(minHeight: 44).disabled(controller.locked)
    } else {
      nextWorkout
    }
  }
  private var nextWorkout: some View { dashboard }
  private func calibrationMiniBanner(_ progress: CalibrationProgress) -> some View {
    Text("Manual logs do not verify starting loads or unlock adaptive recommendations.")
      .font(Stitch.font(12, .medium))
      .foregroundStyle(Stitch.secondary)
      .accessibilityIdentifier("calibration_progress_banner")
  }
  private var dashboard: some View {
    StitchDashboard(
      logs: controller.logs, profile: controller.profile, draft: controller.draft,
      minutes: setup.saved?.preferredMinutes, locked: controller.locked,
      start: { choose(nextManualPlan(controller.logs, profile: controller.profile)) },
      choose: { choosing = true }, duration: { durationSheet = true }, facility: profile,
      open: { log in
        controller.select(log.id)
        hub = false
        reviewCompleted = false
      }
    )
    .onAppear { setup.load() }
  }
  private var sessionSelection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Choose today’s workout").font(.title2.bold())
      Text("Day names are labels from your original plan.").foregroundStyle(.secondary)
      if let draft = controller.draft {
        Button("Resume \(draft.plan.day)") {
          controller.select(draft.id)
          hub = false
          choosing = false
        }
        .buttonStyle(.borderedProminent).frame(minHeight: 52).disabled(controller.locked)
      }
      ForEach(Array(ownerProgram.enumerated()), id: \.element.id) { index, plan in
        Button {
          choose(plan)
        } label: {
          HStack(spacing: 14) {
            Text(String(format: "%02d", index + 1)).font(.caption.bold())
              .padding(10).background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
              Text("Start \(plan.day)").font(.headline)
              Text(plan.title).font(Stitch.font(14)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(Stitch.font(12))
          }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding()
            .background(
              Stitch.card, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).disabled(controller.locked).accessibilityIdentifier(
          "start_" + plan.id)
      }
    }
  }
  private func exerciseCard(
    _ log: ProgramLog, _ exercise: ProgramExercise, restSeconds: Int, prefix: String = ""
  ) -> some View {
    let slots = manualWorkingSlots(log).filter { $0.exercise.id == exercise.id }
    let complete = slots.allSatisfy { $0.record(in: log) != nil }
    let collapsed = model.loggingLayout == "cards" && complete && !expanded.contains(exercise.id)
    return VStack(alignment: .leading, spacing: 12) {
      Button {
        if expanded.contains(exercise.id) {
          expanded.remove(exercise.id)
        } else {
          expanded.insert(exercise.id)
        }
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(prefix + exercise.name).font(Stitch.font(24, .semibold))
            Text("\(slots.filter { $0.record(in: log) != nil }.count) of \(slots.count) recorded")
              .font(Stitch.font(12)).foregroundStyle(.secondary)
          }
          Spacer()
          if complete { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
          if complete && model.loggingLayout == "cards" {
            Image(systemName: collapsed ? "chevron.down" : "chevron.up")
          }
        }.frame(minHeight: 44)
      }.buttonStyle(.plain).accessibilityLabel(
        exercise.name + (collapsed ? ", completed, expand to correct" : ", set details"))
      if collapsed {
        Text(
          slots.compactMap { $0.record(in: log) }.map {
            $0.skipped ? "Skipped" : "\($0.load.map(formatPounds) ?? "BW") × \($0.reps ?? 0)"
          }.joined(separator: " · ")
        )
        .font(Stitch.font(12)).foregroundStyle(.secondary)
      } else {
        HStack(alignment: .top, spacing: 8) {
          StitchMetric(label: "Reps", value: "\(exercise.minReps)–\(exercise.maxReps)")
          StitchMetric(label: "Work sets", value: "\(exercise.sets)")
          StitchMetric(label: "Rest target", value: timerText(Double(restSeconds)))
        }.padding(12).background(Stitch.inset, in: RoundedRectangle(cornerRadius: 10))
        Text(
          "2–3 RIR • Rest \(log.plan.blocks.first { $0.exercises.contains { $0.id == exercise.id } }?.isSuperset == true ? "after pair" : exercise.eachSide ? "after both sides" : "between sets")"
        )
        .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
        lastTime(log, exercise)
        if model.loggingLayout == "table" {
          HStack {
            Text("SET")
            Spacer()
            Text("LOAD · REPS · RIR · QUALITY")
          }.font(.caption2).foregroundStyle(.secondary)
        }
        StitchLabel(text: "Set execution registry")
        ForEach(slots) { slot in setRow(log, exercise, slot.index, slot.side, false) }
        ForEach(log.sets.filter { $0.slot == exercise.id && $0.warmup }, id: \.key) { set in
          setRow(log, exercise, set.index, set.side, true)
        }
        if !log.completed {
          ForEach(exercise.eachSide ? [LoggedSide.left, .right] : [.both], id: \.rawValue) { side in
            Button("Add warm-up\(side == .both ? "" : " · " + side.rawValue)") {
              let index =
                (log.sets.filter { $0.slot == exercise.id && $0.warmup && $0.side == side }.map(
                  \.index
                ).max() ?? 0) + 1
              editor = SetEditorRequest(
                log: log, exercise: exercise, index: index, side: side, warmup: true)
            }.frame(minHeight: 44).disabled(controller.locked)
          }
          Button("Change exercise", systemImage: "arrow.triangle.2.circlepath") {
            exception = exercise
          }
          .frame(minHeight: 44).disabled(controller.locked || complete)
        }
      }
    }.padding().frame(maxWidth: .infinity, alignment: .leading)
      .background(Stitch.card, in: RoundedRectangle(cornerRadius: 20))
  }
  @ViewBuilder private func lastTime(_ log: ProgramLog, _ exercise: ProgramExercise) -> some View {
    let contexts = log.sets.filter { $0.slot == exercise.id && !$0.warmup && !$0.skipped }
    if let context = contexts.last {
      let previous = previousMatchingSets(for: context, in: log, history: controller.logs)
      if let first = previous.first {
        VStack(alignment: .leading, spacing: 4) {
          Label(
            "Last time, same setup · \(first.log.startedAt.formatted(date: .abbreviated, time: .omitted))",
            systemImage: "clock.arrow.circlepath")
          Text(
            "\(context.setup) · \(conventionLabel(context.convention)) · \(context.side.rawValue)")
          Text(previous.map { setSummary($0.set) }.joined(separator: "\n"))
          Text("Your recorded history, not a target.")
        }.font(Stitch.font(12)).foregroundStyle(.secondary)
      } else {
        Text("No previous valid sets for this exact setup.").font(Stitch.font(12)).foregroundStyle(
          .secondary)
      }
    } else {
      let previous = previousExerciseHistory(for: exercise, in: log, history: controller.logs)
      if previous.isEmpty {
        Text("No previous valid sets for this exercise. Record your exact setup when logging.")
          .font(Stitch.font(12)).foregroundStyle(.secondary)
      } else {
        DisclosureGroup("Previous setups · your history") {
          ForEach(previous) { series in
            if let last = series.points.last {
              VStack(alignment: .leading, spacing: 4) {
                Text(series.key.setup).font(.caption.bold())
                Text(
                  "\(conventionLabel(series.key.convention)) · \(series.key.side.rawValue) · \(last.log.startedAt.formatted(date: .abbreviated, time: .omitted))"
                )
                Text(
                  series.points.filter { $0.log.id == last.log.id }.map { setSummary($0.set) }
                    .joined(separator: "\n"))
              }.font(Stitch.font(12)).foregroundStyle(.secondary).padding(.vertical, 4)
            }
          }
          Text("Previous actuals, not targets. Confirm the exact setup when you record a set.")
            .font(Stitch.font(12)).foregroundStyle(.secondary)
        }
      }
    }
  }
  private func focusSession(_ log: ProgramLog) -> some View {
    let slots = manualWorkingSlots(log)
    let next = slots.first { $0.record(in: log) == nil }
    let exercise =
      log.exercises.first { $0.id == focusedExercise } ?? next?.exercise ?? log.exercises[0]
    let index = log.exercises.firstIndex { $0.id == exercise.id } ?? 0
    let block = log.plan.blocks.first { $0.exercises.contains { $0.id == exercise.id } }!
    return VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Exercise \(index + 1) of \(log.exercises.count)").font(Stitch.font(14))
        Spacer()
        Button("All sets") { model.loggingLayoutBinding.wrappedValue = "cards" }.frame(
          minHeight: 44)
      }
      ProgressView(
        value: Double(slots.filter { $0.record(in: log) != nil }.count), total: Double(slots.count)
      )
      .accessibilityLabel("Recorded working sets")
      VStack(alignment: .leading, spacing: 12) {
        Text(exercise.name).font(.title2.bold())
        Text(
          "\(exercise.sets) × \(exercise.minReps)–\(exercise.maxReps) · 2–3 RIR\(exercise.eachSide ? " · each side" : "")"
        )
        .font(Stitch.font(14)).foregroundStyle(.secondary)
        lastTime(log, exercise)
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: focusTileWidth), alignment: .top)],
          alignment: .leading,
          spacing: 12
        ) {
          ForEach(slots.filter { $0.exercise.id == exercise.id }) { slot in
            let saved = slot.record(in: log)
            Button {
              editor = SetEditorRequest(
                log: log, exercise: exercise, index: slot.index, side: slot.side, warmup: false)
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                Text("Set \(slot.index)\(slot.side == .both ? "" : " · " + slot.side.rawValue)")
                  .font(.subheadline.bold())
                Text(saved.map(setSummary) ?? "Not recorded").font(Stitch.font(12))
              }.frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading).padding(12)
                .background(
                  saved == nil
                    ? Color.accentColor.opacity(0.1) : Stitch.card,
                  in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain).disabled(controller.locked || (log.completed && saved == nil))
              .accessibilityIdentifier(
                "set_\(exercise.id)_\(slot.index)_\(slot.side.rawValue)_false")
          }
        }
        if log.completed && log.sets.contains(where: { $0.slot == exercise.id && $0.warmup }) {
          DisclosureGroup("Recorded warm-ups") {
            ForEach(log.sets.filter { $0.slot == exercise.id && $0.warmup }, id: \.key) { set in
              setRow(log, exercise, set.index, set.side, true)
            }
          }
        }
        if !log.completed {
          restButton(block)
          if let target = slots.first(where: {
            $0.exercise.id == exercise.id && $0.record(in: log) == nil
          }) {
            ViewThatFits(in: .horizontal) {
              HStack {
                focusSkip(log, target)
                focusRecord(log, target)
              }
              VStack(alignment: .leading) {
                focusRecord(log, target)
                focusSkip(log, target)
              }
            }
          }
          DisclosureGroup("Warm-ups and exercise options") {
            Text("Manual records do not establish progression baselines.").font(Stitch.font(12))
              .foregroundStyle(.secondary)
            ForEach(log.sets.filter { $0.slot == exercise.id && $0.warmup }, id: \.key) { set in
              setRow(log, exercise, set.index, set.side, true)
            }
            ForEach(exercise.eachSide ? [LoggedSide.left, .right] : [.both], id: \.rawValue) {
              side in
              Button("Add warm-up\(side == .both ? "" : " · " + side.rawValue)") {
                let index =
                  (log.sets.filter { $0.slot == exercise.id && $0.warmup && $0.side == side }.map(
                    \.index
                  ).max() ?? 0) + 1
                editor = SetEditorRequest(
                  log: log, exercise: exercise, index: index, side: side, warmup: true)
              }.frame(minHeight: 44).disabled(controller.locked)
            }
            Button("Change exercise") { exception = exercise }.frame(minHeight: 44)
              .disabled(
                controller.locked
                  || !slots.contains { $0.exercise.id == exercise.id && $0.record(in: log) == nil })
          }
        }
      }
      HStack {
        Button("Previous") { focusedExercise = log.exercises[index - 1].id }
          .disabled(index == 0).frame(minHeight: 44)
        Spacer()
        Button("Next") { focusedExercise = log.exercises[index + 1].id }
          .disabled(index + 1 == log.exercises.count).frame(minHeight: 44)
      }
      if let next, next.exercise.id != exercise.id {
        Button("Next unrecorded · \(next.exercise.name)") { focusedExercise = next.exercise.id }
          .frame(minHeight: 44)
      }
      if index + 1 < log.exercises.count {
        Text("Up next · \(log.exercises[index + 1].name)").font(Stitch.font(12)).foregroundStyle(
          .secondary)
      }
    }
  }
  private func focusRecord(_ log: ProgramLog, _ slot: ManualSetSlot) -> some View {
    Button("Record set \(slot.index)\(slot.side == .both ? "" : " · " + slot.side.rawValue)") {
      editor = SetEditorRequest(
        log: log, exercise: slot.exercise, index: slot.index, side: slot.side, warmup: false)
    }.buttonStyle(StitchPrimary()).controlSize(.large).frame(minHeight: 52).disabled(
      controller.locked)
  }
  private func focusSkip(_ log: ProgramLog, _ slot: ManualSetSlot) -> some View {
    Button("Skip set") {
      editor = SetEditorRequest(
        log: log, exercise: slot.exercise, index: slot.index, side: slot.side, warmup: false,
        skipOnly: true)
    }.buttonStyle(.bordered).controlSize(.large).frame(minHeight: 52).disabled(controller.locked)
  }
  private func restButton(_ block: ProgramBlock) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Button("Start \(block.restSeconds)s rest", systemImage: "timer") {
        do {
          try rest.start(seconds: block.restSeconds, now: Date())
          model.notifications.startRest(seconds: block.restSeconds)
          restDuration = block.restSeconds
          arm()
          model.cue(.impact)
        } catch { model.cue(.error) }
      }.frame(minHeight: 44).disabled(controller.locked)
      Text(
        block.isSuperset
          ? "Start after both exercises."
          : block.exercises.contains(where: \.eachSide)
            ? "Start after both sides." : "Start after the working set."
      )
      .font(Stitch.font(12)).foregroundStyle(.secondary)
    }
  }
  private func setRow(
    _ log: ProgramLog, _ exercise: ProgramExercise, _ index: Int, _ side: LoggedSide, _ warmup: Bool
  ) -> some View {
    let saved = log.sets.first {
      $0.slot == exercise.id && $0.index == index && $0.side == side && $0.warmup == warmup
    }
    let next = manualWorkingSlots(log).first { $0.record(in: log) == nil }
    let active =
      !warmup && next?.exercise.id == exercise.id && next?.index == index && next?.side == side
    return Button {
      editor = SetEditorRequest(
        log: log, exercise: exercise, index: index, side: side, warmup: warmup)
    } label: {
      ViewThatFits(in: .horizontal) {
        if model.loggingLayout == "table" {
          HStack {
            Text("\(warmup ? "Warm-up " : "")\(index)\(side == .both ? "" : " · " + side.rawValue)")
              .font(.subheadline.bold())
            Spacer()
            if let saved, !saved.skipped {
              VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 20) {
                  Text(saved.load.map(formatPounds) ?? "BW").frame(
                    minWidth: 32, alignment: .trailing)
                  Text("\(saved.reps ?? 0)").frame(minWidth: 28, alignment: .trailing)
                  Text(saved.rir.map(String.init) ?? "—").frame(minWidth: 28, alignment: .trailing)
                }.monospacedDigit()
                Text(
                  "\(conventionLabel(saved.convention)) · \(saved.validity.rawValue.capitalized)"
                ).font(.caption2).foregroundStyle(.secondary)
              }
            } else {
              Text(
                saved?.skipped == true
                  ? "Skipped" : active ? "Not recorded · Record" : "Not recorded"
              ).font(Stitch.font(14))
            }
          }
        }
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(
              "\(warmup ? "Warm-up" : "Set") \(index)\(side == .both ? "" : " · " + side.rawValue)"
            ).font(.subheadline.weight(.semibold))
            Spacer()
            Image(
              systemName: saved == nil
                ? "plus.circle"
                : saved?.skipped == true
                  ? "forward.end"
                  : saved?.validity == .valid ? "checkmark.circle" : "exclamationmark.circle")
          }
          Text(saved.map(setSummary) ?? (active ? "Not recorded · Tap to record" : "Not recorded"))
            .font(Stitch.font(14)).foregroundStyle(.secondary)
        }
      }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(10)
        .background(
          active ? Stitch.peach.opacity(0.4) : Stitch.inset,
          in: RoundedRectangle(cornerRadius: 12))
    }.buttonStyle(.plain).disabled(controller.locked || (log.completed && saved == nil))
      .accessibilityIdentifier("set_\(exercise.id)_\(index)_\(side.rawValue)_\(warmup)")
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
      Label(title, systemImage: "exclamationmark.triangle.fill").font(Stitch.font(18, .semibold))
        .foregroundStyle(.red)
      Text("\(change.log.plan.day) · \(change.log.plan.title)").font(Stitch.font(14))
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
        }.font(Stitch.font(14))
      }
      if change.kind == .start {
        Text("Started \(change.log.startedAt.formatted()).").font(Stitch.font(14))
      } else if change.kind == .finish || change.kind == .earlyFinish {
        if let completedAt = change.log.completedAt {
          Text("Finish time: \(completedAt.formatted()).").font(Stitch.font(14))
        }
        Text("\(change.log.sets.count) recorded sets retained.").font(Stitch.font(14))
      } else if change.kind == .deletion {
        Text(
          "Started \(change.log.startedAt.formatted()) · \(change.log.sets.count) recorded sets."
        ).font(Stitch.font(14))
      }
      Text("This action is not confirmed. Retry uses these same values.").font(Stitch.font(12))
    }.padding().frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.orange.opacity(0.12)).cornerRadius(12)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("unconfirmed_workout_action")
  }
  private func timerPanel(_ log: ProgramLog) -> some View {
    WorkoutTimerCapsule(
      elapsed: sessionElapsed(start: log.startedAt, end: log.completedAt, now: now),
      remaining: rest.remaining(now: now), duration: restDuration, started: rest.started,
      completed: log.completed
    ) {
      rest.clear()
      model.notifications.clearRest()
      completionArmed = false
      model.cue(.selection)
    }
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
