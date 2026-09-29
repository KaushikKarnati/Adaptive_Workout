import CoreText
import SwiftUI
import WorkoutApplication
import WorkoutDomain

/// Colors from the supplied screen HTML, with a separate accessible dark adaptation.
enum Stitch {
  static let amber = adaptive(0x894D00, 0xFFB874)
  static let canvas = adaptive(0xF9F9FF, 0x17181D)
  static let card = adaptive(0xFFFFFF, 0x23242C)
  static let inset = adaptive(0xF3F3FA, 0x2C2D36)
  static let elevated = adaptive(0xEDEDF5, 0x343640)
  static let ink = adaptive(0x1A1B21, 0xF0F0F7)
  static let secondary = adaptive(0x5B5F64, 0xC3C6CD)
  static let peach = adaptive(0xFFDCBF, 0x50351F)
  static let green = adaptive(0x006B2F, 0x95F8A7)
  private static func adaptive(_ light: UInt, _ dark: UInt) -> Color {
    Color(
      uiColor: UIColor { traits in
        let value = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
          red: Double((value >> 16) & 255) / 255,
          green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
      })
  }
  static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .custom(
      weight == .bold || weight == .semibold
        ? "SpaceGrotesk-Light_Bold"
        : weight == .medium ? "SpaceGrotesk-Light_Medium" : "SpaceGrotesk-Light_Regular",
      size: size, relativeTo: .body)
  }
  static func registerFont() {
    if let url = Bundle.main.url(forResource: "SpaceGrotesk", withExtension: "ttf") {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}

struct StitchCard: ViewModifier {
  var padding: CGFloat = 16
  func body(content: Content) -> some View {
    content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
      .background(Stitch.card, in: RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16).stroke(Stitch.elevated.opacity(0.45), lineWidth: 0.5))
  }
}

struct StitchLabel: View {
  let text: String
  var body: some View {
    Text(text.uppercased()).font(Stitch.font(11, .medium)).tracking(0.8)
      .foregroundStyle(Stitch.secondary)
  }
}

struct StitchMetric: View {
  let label: String
  let value: String
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      StitchLabel(text: label)
      Text(value).font(Stitch.font(20, .semibold)).monospacedDigit()
        .foregroundStyle(Stitch.ink).fixedSize(horizontal: false, vertical: true)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct StitchPrimary: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(Stitch.font(18, .semibold))
      .frame(maxWidth: .infinity, minHeight: 54).padding(.horizontal, 16)
      .background(
        Color(red: 137 / 255, green: 77 / 255, blue: 0), in: RoundedRectangle(cornerRadius: 12)
      )
      .foregroundStyle(.white).opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.75 : 1)
  }
}

struct StitchSessionMetrics: View {
  let log: ProgramLog
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      StitchMetric(
        label: "Work sets", value: "\(log.sets.filter { !$0.warmup && !$0.skipped }.count)")
      StitchMetric(label: "Movements", value: "\(log.exercises.count)")
      StitchMetric(
        label: "Elapsed",
        value: timerText(sessionElapsed(start: log.startedAt, end: log.completedAt, now: Date())))
    }.padding(12).background(Stitch.inset, in: RoundedRectangle(cornerRadius: 10))
  }
}

struct StitchDashboard: View {
  let logs: [ProgramLog]
  let profile: String
  let draft: ProgramLog?
  let minutes: Int?
  let locked: Bool
  let start: () -> Void
  let choose: () -> Void
  let duration: () -> Void
  let facility: () -> Void
  let open: (ProgramLog) -> Void
  private var plan: ProgramSession { nextManualPlan(logs, profile: profile) }
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      if let draft {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          HStack {
            Circle().fill(Stitch.green).frame(width: 8, height: 8)
            StitchLabel(text: "Active session")
            Text(timerText(sessionElapsed(start: draft.startedAt, end: nil, now: context.date)))
              .font(Stitch.font(18, .semibold)).monospacedDigit()
            Spacer(minLength: 0)
            Button("Resume →", action: start).font(Stitch.font(13, .semibold))
              .padding(.horizontal, 12).frame(minHeight: 44)
              .background(Stitch.peach, in: RoundedRectangle(cornerRadius: 8))
              .accessibilityIdentifier("resume_workout")
          }.modifier(StitchCard(padding: 10))
        }
      }
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Ready when\nyou are.").font(Stitch.font(28, .semibold))
          Spacer()
          Image(systemName: "bolt").font(.title2).foregroundStyle(Stitch.amber)
        }
        Text(
          Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            + " • Offline ready • On device"
        )
        .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
      }
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Text(draft == nil ? "NEXT IN YOUR PLAN" : "SAVED SESSION")
            .font(Stitch.font(11, .semibold)).tracking(0.8)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Stitch.peach.opacity(0.6), in: Capsule())
          Spacer()
          Image(systemName: "internaldrive").foregroundStyle(Stitch.secondary)
        }
        VStack(alignment: .leading, spacing: 6) {
          Text(plan.title).font(Stitch.font(28, .semibold))
          Text("\(plan.day) • Your approved manual plan").font(Stitch.font(14))
            .foregroundStyle(Stitch.secondary)
        }
        HStack(alignment: .top, spacing: 6) {
          StitchMetric(label: "Movements", value: "\(plan.exercises.count)")
          StitchMetric(label: "Work", value: "\(plan.exercises.reduce(0) { $0 + $1.sets }) Sets")
          Button(action: duration) {
            StitchMetric(label: "Available", value: minutes.map { "\($0) Min" } ?? "Set time")
          }.buttonStyle(.plain).accessibilityIdentifier("duration_button")
        }.padding(12).background(Stitch.inset, in: RoundedRectangle(cornerRadius: 10))
        HStack(spacing: 10) {
          Image(systemName: "bookmark").foregroundStyle(Stitch.amber)
          VStack(alignment: .leading, spacing: 4) {
            StitchLabel(text: draft == nil ? "Manual logging" : "Saved anchor")
            Text(
              draft.map { "\($0.sets.count) saved records • Resume your workout" }
                ?? "Record actuals • Loads require your confirmation"
            )
            .font(Stitch.font(12, .medium))
          }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
          .background(Stitch.elevated, in: RoundedRectangle(cornerRadius: 10))
        Button(action: start) {
          HStack {
            Image(systemName: "bolt.fill")
            Text(draft == nil ? "Start workout" : "Resume workout")
            Spacer()
            Image(systemName: "arrow.right")
          }
        }.buttonStyle(StitchPrimary()).disabled(locked).accessibilityIdentifier(
          "start_next_workout")
      }.padding(24).padding(.top, 6).background(Stitch.card)
        .overlay(alignment: .top) { Rectangle().fill(Stitch.amber).frame(height: 6) }
        .clipShape(RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          StitchLabel(text: "Your training plan")
          Spacer()
          Button("Change", action: choose).font(Stitch.font(12)).frame(minHeight: 44)
        }
        HStack(spacing: 5) {
          ForEach(Array(ownerProgram.enumerated()), id: \.element.id) { index, item in
            VStack(spacing: 10) {
              Text(String(item.day.prefix(3)).uppercased()).font(Stitch.font(11))
              Image(systemName: item.id == plan.id ? "circle.inset.filled" : "circle")
                .foregroundStyle(item.id == plan.id ? Stitch.amber : Stitch.secondary)
              Text("\(index + 1)").font(Stitch.font(12, .semibold))
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
              .background(Stitch.card, in: RoundedRectangle(cornerRadius: 12))
          }
        }
        Text("Plan order • Day names are original labels, not a schedule.")
          .font(Stitch.font(11)).foregroundStyle(Stitch.secondary)
      }
      Button(action: facility) {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Label("FACILITY CONTEXT", systemImage: "dumbbell").font(Stitch.font(11))
            Spacer()
            Text("Change ›").font(Stitch.font(12)).foregroundStyle(Stitch.amber)
          }
          Text("Your gym & equipment").font(Stitch.font(20, .semibold))
          Text("Review your saved location and exact equipment setups.")
            .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
        }.modifier(StitchCard())
      }.buttonStyle(.plain)
      if let last = filterWorkoutHistory(logs, profile: profile).first {
        Button {
          open(last)
        } label: {
          VStack(alignment: .leading, spacing: 16) {
            StitchLabel(text: "Last recorded session")
            Text(last.plan.title).font(Stitch.font(20, .semibold))
            Text(last.startedAt.formatted(date: .abbreviated, time: .shortened)).font(
              Stitch.font(12)
            ).foregroundStyle(Stitch.secondary)
            StitchSessionMetrics(log: last)
          }.modifier(StitchCard())
        }.buttonStyle(.plain)
      }
      Label(
        "Manual records stay separate from progression evidence. Recommendations await reviewed catalog, equipment, baseline and safety checks.",
        systemImage: "flask"
      )
      .font(Stitch.font(12)).foregroundStyle(Stitch.secondary).padding(.horizontal, 8)
    }
  }
}

struct StitchSummary: View {
  let log: ProgramLog
  let next: () -> Void
  let corrections: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(
        log.endedEarly ? "SESSION ENDED EARLY" : "SESSION CONCLUDED", systemImage: "circle.fill"
      )
      .font(Stitch.font(11)).foregroundStyle(Stitch.green)
      Text(log.endedEarly ? "Workout\nFinished Early" : "Workout\nCompleted")
        .font(Stitch.font(40, .bold)).tracking(-1)
      HStack(alignment: .top, spacing: 12) {
        StitchMetric(
          label: "Duration",
          value: timerText(sessionElapsed(start: log.startedAt, end: log.completedAt, now: Date()))
        )
        .modifier(StitchCard())
        StitchMetric(label: "Saved records", value: "\(log.sets.count)")
          .modifier(StitchCard())
      }
      VStack(alignment: .leading, spacing: 14) {
        StitchLabel(text: "Working-set records")
        Text(
          "\(manualWorkingSlots(log).filter { $0.record(in: log) != nil }.count) / \(manualWorkingSlots(log).count) Sets"
        )
        .font(Stitch.font(28, .semibold))
        ProgressView(
          value: Double(manualWorkingSlots(log).filter { $0.record(in: log) != nil }.count),
          total: Double(max(1, manualWorkingSlots(log).count)))
        Text("Includes explicit skips. Unrecorded sets remain unrecorded.")
          .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
      }.modifier(StitchCard())
      HStack {
        Text("Execution Breakdown").font(Stitch.font(20, .semibold))
        Spacer()
        StitchLabel(text: "\(log.exercises.count) movements")
      }.padding(.top, 8)
      VStack(spacing: 0) {
        ForEach(Array(log.exercises.enumerated()), id: \.element.id) { index, exercise in
          HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)").font(Stitch.font(14, .semibold)).frame(width: 32, height: 32)
              .background(index == 0 ? Stitch.peach : Stitch.elevated, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
              Text(exercise.name).font(Stitch.font(18, .semibold))
              Text(
                "\(log.sets.filter { $0.slot == exercise.id && !$0.warmup && !$0.skipped }.count) work records • \(log.sets.filter { $0.slot == exercise.id && $0.warmup }.count) warm-ups"
              )
              .font(Stitch.font(12)).foregroundStyle(Stitch.secondary)
            }
            Spacer(minLength: 0)
          }.padding(16)
          if index + 1 < log.exercises.count { Divider().overlay(Stitch.elevated) }
        }
      }.background(Stitch.card, in: RoundedRectangle(cornerRadius: 16))
      Label(
        "Saved on this device. Elapsed time includes rest and time away; no active-time, tonnage or PR estimate is inferred.",
        systemImage: "internaldrive"
      )
      .font(Stitch.font(12)).foregroundStyle(Stitch.secondary).modifier(StitchCard())
      Button("Done · Back to Workout", action: next).buttonStyle(StitchPrimary())
        .accessibilityIdentifier("summary_done")
      Button("Review / correct saved sets", action: corrections).font(Stitch.font(16, .semibold))
        .frame(maxWidth: .infinity, minHeight: 52).background(
          Stitch.card, in: RoundedRectangle(cornerRadius: 12))
    }.accessibilityIdentifier("workout_summary")
  }
}
