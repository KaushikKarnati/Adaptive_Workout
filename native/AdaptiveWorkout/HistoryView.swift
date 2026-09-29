import SwiftUI
import WorkoutApplication
import WorkoutDomain

struct HistoryView: View {
  let logs: [ProgramLog]
  let profile: String
  let graphs: Bool
  @Binding var query: String
  @Binding var days: Int
  @Binding var repetitionMetrics: [ExerciseSeriesKey: Bool]
  var cue: (AppModel.Cue) -> Void = { _ in }
  let open: (ProgramLog) -> Void
  let delete: (ProgramLog) -> Void
  private var filtered: [ProgramLog] {
    filterWorkoutHistory(
      logs, profile: profile, query: query,
      since: days == 0 ? nil : Date().addingTimeInterval(-Double(days) * 86_400))
  }
  private var groupedHistory: [(date: Date, logs: [ProgramLog])] {
    Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.startedAt) }
      .map { (date: $0.key, logs: $0.value) }
      .sorted { $0.date > $1.date }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "magnifyingglass").foregroundStyle(Stitch.secondary)
        TextField("Search exercises, setups, workouts…", text: $query)
          .accessibilityIdentifier("history_search")
      }.padding(12).background(Stitch.card, in: RoundedRectangle(cornerRadius: 12))
      Picker("Date range", selection: $days) {
        Text("All time").tag(0)
        Text("30 days").tag(30)
        Text("90 days").tag(90)
        Text("365 days").tag(365)
      }.pickerStyle(.menu).accessibilityIdentifier("history_range").onChange(of: days) {
        cue(.selection)
      }
      if filtered.isEmpty {
        Text("No finished workouts match these filters.").foregroundColor(.secondary)
      }
      if graphs {
        Text(
          "Valid working sets only. Warm-ups, skipped and pain-affected sets are excluded. These graphs do not enable weight recommendations."
        ).font(.footnote).foregroundColor(.secondary)
        let series = exerciseHistory(filtered)
        if !filtered.isEmpty && series.isEmpty {
          Text("No comparable valid working sets to graph.")
        }
        ForEach(series) { item in
          VStack(alignment: .leading, spacing: 10) {
            StitchLabel(text: "Recorded working sets")
            Text(item.name).font(Stitch.font(22, .semibold))
            Text(
              "\(item.key.variant.replacingOccurrences(of: "_", with: " ")) · \(item.key.setup) · \(item.key.side.rawValue)"
            ).font(.subheadline).foregroundColor(.secondary)
            Text(conventionLabel(item.key.convention)).font(.caption)
            if item.key.convention == .assistance {
              Text("Assistance is support provided, not weight lifted.").font(.caption)
            }
            if item.key.convention != .bodyweight {
              Picker(
                "Metric",
                selection: Binding(
                  get: { repetitionMetrics[item.key] ?? false },
                  set: { value in
                    guard value != (repetitionMetrics[item.key] ?? false) else { return }
                    repetitionMetrics[item.key] = value
                    cue(.selection)
                  })
              ) {
                Text("Load").tag(false)
                Text("Reps").tag(true)
              }.pickerStyle(.segmented).accessibilityIdentifier("graph_metric_" + item.key.slot)
            }
            let useLoad =
              !(repetitionMetrics[item.key] ?? false) && item.key.convention != .bodyweight
            let values = item.points.map {
              useLoad ? Double($0.set.load ?? 0) / 1_000_000 : Double($0.set.reps ?? 0)
            }
            Text(
              "Latest: \(values.last.map { String(format: useLoad ? "%.2f" : "%.0f", $0) } ?? "—") \(useLoad ? "lb" : "reps")"
            ).font(Stitch.font(28, .semibold)).monospacedDigit().accessibilityIdentifier(
              "graph_latest_" + item.key.slot)
            HistoryLine(values: values, sessionIDs: item.points.map { $0.log.id })
              .frame(height: 150).padding(8).background(
                Stitch.inset, in: RoundedRectangle(cornerRadius: 10)
              ).accessibilityHidden(true)
            HStack {
              Text(item.points.first!.log.startedAt.formatted(date: .abbreviated, time: .omitted))
              Spacer()
              Text(item.points.last!.log.startedAt.formatted(date: .abbreviated, time: .omitted))
            }.font(.caption)
            if item.points.count == 1 {
              Text("One recorded set. More records will build the graph.").font(.caption)
            }
            Text(
              "\(useLoad ? (item.key.convention == .assistance ? "Support (lb)" : "Load (lb)") : "Repetitions") · horizontal axis: recorded set order. Dashed dividers separate workouts."
            ).font(.caption)
            DisclosureGroup("Exact values (\(item.points.count) sets)") {
              ForEach(item.points.reversed()) { point in
                Button {
                  open(point.log)
                } label: {
                  VStack(alignment: .leading) {
                    Text(point.log.startedAt.formatted(date: .abbreviated, time: .shortened))
                    Text("Set \(point.set.index) · \(setSummary(point.set))").font(.subheadline)
                  }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                }
              }
            }
          }.modifier(StitchCard())
        }
      } else {
        Text("Recent Sessions").font(Stitch.font(22, .semibold))
        ForEach(groupedHistory, id: \.date) { group in
          VStack(alignment: .leading, spacing: 10) {
            Text(group.date.formatted(date: .complete, time: .omitted))
              .font(Stitch.font(11, .medium)).foregroundStyle(Stitch.secondary)
              .accessibilityAddTraits(.isHeader)
            ForEach(group.logs, id: \.id) { log in
              VStack(alignment: .leading, spacing: 8) {
                Button {
                  open(log)
                } label: {
                  VStack(alignment: .leading, spacing: 8) {
                    Text("\(log.plan.day) · \(log.plan.title)").font(Stitch.font(20, .semibold))
                      .foregroundStyle(.primary)
                    Text(log.startedAt.formatted(date: .omitted, time: .shortened))
                      .font(.subheadline).foregroundStyle(.secondary)
                    Label(
                      log.endedEarly
                        ? "Finished early" : log.hasSkips ? "Finished with skips" : "Finished",
                      systemImage: log.endedEarly || log.hasSkips
                        ? "checkmark.circle" : "checkmark.circle.fill"
                    ).font(Stitch.font(11, .semibold)).foregroundStyle(
                      log.endedEarly ? Stitch.amber : Stitch.green)
                    StitchSessionMetrics(log: log)
                    Text(log.exercises.prefix(2).map(\.name).joined(separator: " • "))
                      .font(Stitch.font(11)).foregroundStyle(Stitch.secondary)

                  }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("history_workout_" + log.id)
                Button("Delete", role: .destructive) { delete(log) }
                  .frame(minHeight: 44).buttonStyle(.borderless)
              }.modifier(StitchCard())
            }
          }
        }
      }
    }
  }
}
private struct HistoryLine: View {
  let values: [Double]
  let sessionIDs: [String]
  var body: some View {
    Canvas { context, size in
      guard !values.isEmpty else { return }
      let maximum = values.max() ?? 0
      let top = maximum == 0 ? 1 : maximum * 1.1
      let left = 58.0
      let width = max(0, size.width - 66)
      let height = max(0, size.height - 20)
      for index in 0...2 {
        let fraction = Double(index) / 2
        let y = 8 + height * fraction
        var grid = Path()
        grid.move(to: CGPoint(x: left, y: y))
        grid.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(grid, with: .color(.secondary.opacity(0.25)), lineWidth: 1)
        context.draw(
          Text(String(format: "%.1f", top * (1 - fraction))).font(.caption2).foregroundColor(
            .secondary), at: CGPoint(x: left - 6, y: y), anchor: .trailing)
      }
      let points = values.enumerated().map { index, value in
        CGPoint(
          x: left
            + (values.count == 1 ? width / 2 : width * Double(index) / Double(values.count - 1)),
          y: 8 + height * (1 - value / top))
      }
      for index in points.indices.dropFirst()
      where sessionIDs[index] != sessionIDs[index - 1] {
        let x = (points[index - 1].x + points[index].x) / 2
        var boundary = Path()
        boundary.move(to: CGPoint(x: x, y: 8))
        boundary.addLine(to: CGPoint(x: x, y: 8 + height))
        context.stroke(
          boundary, with: .color(.secondary.opacity(0.6)),
          style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
      }
      var path = Path()
      path.addLines(points)
      context.stroke(path, with: .color(.accentColor), lineWidth: 2)
      for point in points {
        context.fill(
          Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
          with: .color(.accentColor))
      }
    }
  }
}
