import Combine
import SwiftUI
import WorkoutApplication
import WorkoutDomain

private struct AdaptiveSetRequest: Identifiable {
  let id = UUID()
  let slot: RecommendedSlot
  let target: SetTarget
  let currentSet: ProgramSet?
}

struct AdaptiveWorkoutView: View {
  @ObservedObject var adaptiveController: AdaptiveGenerationController
  @ObservedObject var model: AppModel
  @ObservedObject var setup: SetupModel
  let profile: () -> Void
  var switchToManual: (() -> Void)? = nil

  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase

  @State private var editor: AdaptiveSetRequest?
  @State private var earlyFinishAlert = false
  @State private var rest = RestCountdown()
  @State private var restDuration = 90
  @State private var completionArmed = false
  @State private var now = Date()

  private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if let error = adaptiveController.error {
        VStack(alignment: .leading, spacing: 8) {
          Text(error).foregroundColor(.red).font(Stitch.font(14))
          Button("Retry") {
            Task { await adaptiveController.load() }
          }
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
      }

      if adaptiveController.busy {
        HStack(spacing: 8) {
          ProgressView()
          Text("Processing…").font(Stitch.font(14)).foregroundStyle(Stitch.secondary)
        }
      }

      if let active = adaptiveController.activeWorkout {
        activeWorkoutView(active)
      } else {
        idleView
      }
    }
    .sheet(item: $editor) { request in
      AdaptiveSetEditor(
        slot: request.slot,
        target: request.target,
        currentSet: request.currentSet,
        cue: model.cue,
        save: { set in
          Task {
            let ok = await adaptiveController.record(set)
            model.cue(ok ? .success : .error)
          }
        },
        skip: { set in
          Task {
            let ok = await adaptiveController.record(set)
            model.cue(ok ? .selection : .error)
          }
        }
      )
    }
    .alert("Finish workout early?", isPresented: $earlyFinishAlert) {
      Button("Keep logging", role: .cancel) {}
      Button("Finish early") {
        Task {
          let ok = await adaptiveController.finish(endEarly: true)
          model.cue(ok ? .success : .error)
        }
      }
    } message: {
      Text("Completed sets will remain saved on device. Unrecorded sets will remain unrecorded.")
    }
    .safeAreaInset(edge: .bottom) {
      if let active = adaptiveController.activeWorkout {
        WorkoutTimerCapsule(
          elapsed: sessionElapsed(start: active.occurrence.startedAt, end: nil, now: now),
          remaining: rest.remaining(now: now),
          duration: restDuration,
          started: rest.started,
          completed: false
        ) {
          rest.clear()
          completionArmed = false
          model.cue(.selection)
        }
      }
    }
    .onReceive(tick) { value in
      now = value
      if completionArmed, rest.remaining(now: value) == 0 {
        completionArmed = false
        model.cue(.success)
      }
    }
  }

  // MARK: - Active Workout View

  private func activeWorkoutView(_ active: SavedWorkout) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          StitchLabel(text: "Active session · on-device engine")
          Spacer()
          Circle().fill(Stitch.green).frame(width: 8, height: 8)
        }
        Text(sessionTitle(active.prescription.sessionTemplate))
          .font(Stitch.font(28, .semibold))
        Text(
          "Started \(active.occurrence.startedAt.formatted(date: .omitted, time: .shortened)) • Deterministic progression"
        )
        .font(Stitch.font(12))
        .foregroundStyle(Stitch.secondary)

        if !active.occurrence.stoppedSlots.isEmpty {
          Label(
            "Pain recorded. Further sets for stopped movements are discontinued.",
            systemImage: "exclamationmark.triangle.fill"
          )
          .font(Stitch.font(13))
          .foregroundStyle(.red)
        }
      }

      ForEach(active.prescription.slots) { slot in
        slotCard(slot, active: active)
      }

      VStack(spacing: 12) {
        Button("Finish workout") {
          Task {
            let ok = await adaptiveController.finish(endEarly: false)
            model.cue(ok ? .success : .error)
          }
        }
        .buttonStyle(StitchPrimary())
        .frame(minHeight: 52)
        .disabled(adaptiveController.locked)

        Button("Finish early") {
          earlyFinishAlert = true
          model.cue(.warning)
        }
        .frame(minHeight: 44)
        .disabled(adaptiveController.locked)
      }
    }
  }

  private func slotCard(_ slot: RecommendedSlot, active: SavedWorkout) -> some View {
    let raw = slot.exerciseId
    let variant = raw.hasPrefix("owner_ex_") ? String(raw.dropFirst("owner_ex_".count)) : raw
    let name =
      setupVariationNames[variant] ?? variant.replacingOccurrences(of: "_", with: " ").capitalized
    let stopped = active.occurrence.stoppedSlots.contains(slot.id)
    let workTargets = slot.targets.filter { !$0.warmup }
    let allFinished = workTargets.allSatisfy { target in
      active.occurrence.sets.contains { $0.key == "\(slot.id)_\(target.key)" }
    }

    return VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(name).font(Stitch.font(22, .semibold))
          Text("Setup: \(slot.setupId) • \(conventionLabel(slot.convention))")
            .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
        }
        Spacer()
        if stopped {
          Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        } else if allFinished {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(Stitch.green)
        }
      }

      if stopped {
        Text("Exercise stopped due to recorded pain.")
          .font(Stitch.font(12, .medium)).foregroundStyle(.red)
      } else {
        HStack(alignment: .top, spacing: 8) {
          if let firstWork = workTargets.first {
            StitchMetric(label: "Reps", value: "\(firstWork.minReps)–\(firstWork.maxReps)")
            StitchMetric(label: "Work sets", value: "\(workTargets.count)")
            if let load = firstWork.load, slot.convention != .bodyweight {
              StitchMetric(label: "Target", value: "\(formatPounds(load)) lb")
            } else {
              StitchMetric(label: "Target", value: "Bodyweight")
            }
          }
        }
        .padding(12).background(Stitch.inset, in: RoundedRectangle(cornerRadius: 10))

        StitchLabel(text: "Prescribed Set Targets")

        ForEach(slot.targets, id: \.key) { target in
          setTargetRow(slot: slot, target: target, active: active, stopped: stopped)
        }

        if let restSeconds = slot.targets.first?.restSeconds, restSeconds > 0, !allFinished {
          Button("Start \(restSeconds)s rest", systemImage: "timer") {
            do {
              try rest.start(seconds: restSeconds, now: Date())
              restDuration = restSeconds
              completionArmed = true
              model.cue(.impact)
            } catch {
              model.cue(.error)
            }
          }
          .frame(minHeight: 44)
          .disabled(adaptiveController.locked)
        }
      }
    }
    .modifier(StitchCard())
  }

  private func setTargetRow(
    slot: RecommendedSlot,
    target: SetTarget,
    active: SavedWorkout,
    stopped: Bool
  ) -> some View {
    let saved = active.occurrence.sets.first { $0.key == "\(slot.id)_\(target.key)" }
    let sideText = target.side == .both ? "" : " · \(target.side.rawValue.capitalized)"

    return Button {
      editor = AdaptiveSetRequest(slot: slot, target: target, currentSet: saved)
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(target.warmup ? "Warm-up" : "Set") \(target.index)\(sideText)")
            .font(.subheadline.bold())
          if let saved {
            if saved.skipped {
              Text("Skipped").font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
            } else {
              let loadText = saved.load.map { formatPounds($0) + " lb" } ?? "Bodyweight"
              Text(
                "\(loadText) × \(saved.reps ?? 0) reps · RIR \(saved.rir.map(String.init) ?? "—") · \(saved.validity.rawValue.capitalized)"
              )
              .font(Stitch.font(12)).foregroundStyle(Stitch.ink)
            }
          } else {
            let targetLoad = target.load.map { formatPounds($0) + " lb" } ?? "BW"
            Text("Target: \(targetLoad) × \(target.minReps)–\(target.maxReps) reps")
              .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
          }
        }
        Spacer()
        if let saved {
          if saved.skipped {
            Image(systemName: "forward.end").foregroundStyle(Stitch.secondary)
          } else if saved.validity == .pain {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
          } else {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Stitch.green)
          }
        } else {
          Text("Record").font(Stitch.font(12, .semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Stitch.amber.opacity(0.15), in: Capsule())
            .foregroundStyle(Stitch.amber)
        }
      }
      .padding(10)
      .background(
        saved != nil ? Stitch.inset : Stitch.peach.opacity(0.3),
        in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .disabled(adaptiveController.locked || (stopped && saved == nil))
  }

  // MARK: - Idle Pre-Workout View

  private var idleView: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Deterministic\nEngine.").font(Stitch.font(28, .semibold))
          Spacer()
          Image(systemName: "cpu").font(.title2).foregroundStyle(Stitch.amber)
        }
        Text("Transparent progression receipts • Fail-closed safety gates")
          .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
      }

      Button {
        Task {
          let res = await adaptiveController.generate()
          model.cue(res != nil ? .success : .error)
        }
      } label: {
        HStack {
          Image(systemName: "bolt.fill")
          Text(
            adaptiveController.latestRecommendation == nil
              ? "Generate Today's Workout" : "Regenerate Workout")
          Spacer()
          Image(systemName: "arrow.right")
        }
      }
      .buttonStyle(StitchPrimary())
      .disabled(adaptiveController.locked)
      .accessibilityIdentifier("generate_workout_button")

      if let rec = adaptiveController.latestRecommendation, rec.status == .ready {
        Button {
          Task {
            let res = await adaptiveController.generate()
            model.cue(res != nil ? .success : .error)
          }
        } label: {
          HStack {
            Image(systemName: "bolt.fill")
            Text("Regenerate Workout")
            Spacer()
            Image(systemName: "arrow.right")
          }
        }
        .buttonStyle(StitchPrimary())
        .disabled(adaptiveController.locked)
        .accessibilityIdentifier("generate_workout_button")

        recommendationCard(rec)
      } else {
        calibrationProgressCard

        if let rec = adaptiveController.latestRecommendation {
          recommendationCard(rec)
        } else {
          Button {
            Task {
              let res = await adaptiveController.generate()
              model.cue(res != nil ? .success : .error)
            }
          } label: {
            HStack {
              Image(systemName: "bolt.fill")
              Text("Generate Today's Workout")
              Spacer()
              Image(systemName: "arrow.right")
            }
          }
          .buttonStyle(StitchPrimary())
          .disabled(adaptiveController.locked)
          .accessibilityIdentifier("generate_workout_button")
        }
      }

      if let history = adaptiveController.history, !history.occurrences.isEmpty {
        historySection(history)
      }
    }
  }

  private var calibrationProgressCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Adaptive recommendations unavailable")
        .font(Stitch.font(24, .semibold))
      Text(
        "Manual logs do not confirm equipment, starting loads, rehearsal feedback, or safety. Explicit verification and catalog review are still required."
      )
      .font(Stitch.font(13)).foregroundStyle(Stitch.secondary)
      if let switchToManual {
        Button("Continue with Manual Plan", action: switchToManual)
          .buttonStyle(StitchPrimary())
          .accessibilityIdentifier("switch_to_manual_button")
      }
    }
    .modifier(StitchCard())
  }

  private func recommendationCard(_ rec: RecommendationSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(rec.status == .ready ? "READY TO TRAIN" : "GENERATION BLOCKED")
          .font(Stitch.font(11, .semibold)).tracking(0.8)
          .padding(.horizontal, 10).padding(.vertical, 6)
          .background(
            rec.status == .ready ? Stitch.green.opacity(0.2) : Color.orange.opacity(0.2),
            in: Capsule()
          )
          .foregroundStyle(rec.status == .ready ? Stitch.green : Color.orange)
        Spacer()
        Text(rec.requestedDate.formatted(date: .abbreviated, time: .omitted))
          .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(sessionTitle(rec.sessionTemplate))
          .font(Stitch.font(24, .semibold))
        Text("Target duration: \(rec.preferredMinutes) min • Walk: \(rec.walkSeconds / 60) min")
          .font(Stitch.font(13)).foregroundStyle(Stitch.secondary)
      }

      if rec.status == .ready {
        HStack(alignment: .top, spacing: 6) {
          StitchMetric(label: "Movements", value: "\(rec.slots.count)")
          StitchMetric(
            label: "Work Sets",
            value: "\(rec.slots.reduce(0) { $0 + $1.targets.filter { !$0.warmup }.count })"
          )
        }
        .padding(12).background(Stitch.inset, in: RoundedRectangle(cornerRadius: 10))

        Button {
          Task {
            let ok = await adaptiveController.start(recommendationId: rec.id)
            model.cue(ok ? .success : .error)
          }
        } label: {
          HStack {
            Image(systemName: "play.fill")
            Text("Start Adaptive Workout")
            Spacer()
            Image(systemName: "arrow.right")
          }
        }
        .buttonStyle(StitchPrimary())
        .disabled(adaptiveController.locked)
        .accessibilityIdentifier("start_adaptive_workout")
      } else {
        VStack(alignment: .leading, spacing: 12) {
          Label("Generation Blocked: Baselines Required", systemImage: "info.circle.fill")
            .font(Stitch.font(14, .semibold)).foregroundStyle(Color.orange)

          Text(
            "Starting setup & baselines required. You can complete the 7 manual logs shown above or configure equipment manually in Settings."
          )
          .font(Stitch.font(13)).foregroundStyle(Stitch.secondary)

          if !rec.reasons.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              ForEach(rec.reasons, id: \.self) { reason in
                Text("• Reason: \(reason.replacingOccurrences(of: "_", with: " "))")
                  .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
              }
            }
          }

          Button(action: profile) {
            HStack {
              Text("Or configure manually in Profile ›")
                .font(Stitch.font(13, .medium)).foregroundStyle(Stitch.amber)
              Spacer()
            }
            .frame(minHeight: 36)
          }
          .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
      }
    }
    .modifier(StitchCard())
  }

  private func historySection(_ history: GeneratedHistory) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      StitchLabel(text: "Recent Adaptive Sessions")

      ForEach(history.occurrences.suffix(3).reversed()) { occ in
        let template =
          history.recommendations.first { $0.id == occ.recommendationId }?.sessionTemplate
          ?? "session"
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(sessionTitle(template)).font(Stitch.font(16, .semibold))
            Text(
              "\(occ.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(occ.sets.count) recorded sets"
            )
            .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
          }
          Spacer()
          Text(occ.status.rawValue.capitalized)
            .font(Stitch.font(11, .medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Stitch.inset, in: Capsule())
            .foregroundStyle(occ.status == .completed ? Stitch.green : Stitch.secondary)
        }
        .padding(12)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: 12))
      }
    }
  }

  private func sessionTitle(_ template: String) -> String {
    let clean = template.replacingOccurrences(of: "_", with: " ")
    return clean.capitalized
  }
}
