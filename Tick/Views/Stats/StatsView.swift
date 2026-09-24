import Charts
import SwiftData
import SwiftUI

/// Statistics for a chosen period (M5). All numbers come from `Statistics.compute`.
struct StatsView: View {
    @State private var kind: StatsPeriodKind = .week
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    @State private var customEnd = Date.now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Picker("Period", selection: $kind) {
                        ForEach(StatsPeriodKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    if kind == .custom {
                        DatePicker("From", selection: $customStart, displayedComponents: .date)
                        DatePicker("To", selection: $customEnd, displayedComponents: .date)
                    }
                    Spacer()
                }

                StatsContent(kind: kind, customStart: customStart, customEnd: customEnd)
                    // A new period needs a new query.
                    .id("\(kind)|\(Calendar.current.startOfDay(for: customStart))|\(Calendar.current.startOfDay(for: customEnd))")
            }
            .padding(20)
        }
        .navigationTitle("Statistics")
    }
}

private struct StatsContent: View {
    let kind: StatsPeriodKind
    let customStart: Date
    let customEnd: Date

    @Query private var entries: [TimeEntry]
    @Query private var workBlocks: [PomodoroSession]

    init(kind: StatsPeriodKind, customStart: Date, customEnd: Date) {
        self.kind = kind
        self.customStart = customStart
        self.customEnd = customEnd
        let period = StatsPeriod.make(kind, customStart: customStart, customEnd: customEnd, now: .now, calendar: .current)
        let from = period.fetchStart
        let to = period.full.end
        _entries = Query(filter: #Predicate<TimeEntry> { $0.start >= from && $0.start < to })
        let work = PomodoroPhase.work.rawValue
        _workBlocks = Query(filter: #Predicate<PomodoroSession> {
            $0.completed && $0.phase == work && $0.start >= from && $0.start < to
        })
    }

    var body: some View {
        // Refreshes so a running timer is included.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let period = StatsPeriod.make(kind, customStart: customStart, customEnd: customEnd, now: now, calendar: .current)
            let stats = Statistics.compute(
                entries: entries, completedWorkBlockStarts: workBlocks.map(\.start),
                period: period, now: now, calendar: .current
            )

            VStack(alignment: .leading, spacing: 20) {
                Header(stats: stats, kind: kind)
                if stats.total == 0 {
                    Text("No time tracked in this period.")
                        .foregroundStyle(.secondary)
                } else {
                    ChartCard(title: "Time per project") { SliceChart(slices: stats.projects) }
                    ChartCard(
                        title: "Time per tag",
                        footnote: "An entry with several tags counts toward each, so tag totals can exceed the total."
                    ) {
                        SliceChart(slices: stats.tags)
                    }
                    ChartCard(title: "Time per day") { DayChart(stats: stats) }
                }
                ChartCard(title: "Pomodoros per day") { PomodoroChart(counts: stats.pomodorosPerDay) }
            }
        }
    }
}

private struct Header: View {
    let stats: Statistics
    let kind: StatsPeriodKind

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DurationFormat.clock(stats.total))
                .font(.system(size: 40, weight: .semibold))
                .monospacedDigit()
            Text(comparison)
                .foregroundStyle(.secondary)
            if stats.overlapSeconds > 0 {
                Label(
                    "Includes \(DurationFormat.spoken(stats.overlapSeconds)) of overlapping time from "
                        + "\(stats.overlappingEntryCount) entries. They're marked in Entries.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
                .font(.callout)
            }
        }
    }

    private var comparison: String {
        let delta = stats.total - stats.previousTotal
        let sign = delta >= 0 ? "+" : "−"
        let reference = switch kind {
        case .today: "yesterday at this time"
        case .week: "last week at this point"
        case .month: "last month at this point"
        case .custom: "the same length before"
        }
        guard stats.previousTotal > 0 else { return "Nothing tracked \(reference)" }
        let percent = Int((abs(delta) / stats.previousTotal * 100).rounded())
        return "\(sign)\(DurationFormat.clock(abs(delta))) (\(sign)\(percent) %) vs \(reference)"
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                content
                if let footnote {
                    Text(footnote).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(8)
        } label: {
            Text(title).font(.headline)
        }
    }
}

/// Horizontal bars in each project's or tag's own color, largest first.
private struct SliceChart: View {
    let slices: [Statistics.Slice]

    var body: some View {
        Chart(slices) { slice in
            BarMark(x: .value("Hours", slice.seconds / 3600), y: .value("Name", slice.name))
                .foregroundStyle(Color(hex: slice.colorHex))
                .annotation(position: .trailing) {
                    Text(DurationFormat.clock(slice.seconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
        }
        .chartXAxisLabel("Hours")
        .chartYScale(domain: slices.map(\.name))
        .frame(height: CGFloat(slices.count) * 30 + 40)
    }
}

/// Stacked bars per day, colored by project.
private struct DayChart: View {
    let stats: Statistics

    var body: some View {
        Chart(stats.days) { slice in
            BarMark(x: .value("Day", slice.day, unit: .day), y: .value("Hours", slice.seconds / 3600))
                .foregroundStyle(by: .value("Project", slice.name))
        }
        .chartForegroundStyleScale(
            domain: stats.projects.map(\.name),
            range: stats.projects.map { Color(hex: $0.colorHex) }
        )
        .chartYAxisLabel("Hours")
        .frame(height: 220)
    }
}

private struct PomodoroChart: View {
    let counts: [Statistics.DayCount]

    var body: some View {
        if counts.allSatisfy({ $0.count == 0 }) {
            Text("No completed pomodoros in this period.")
                .foregroundStyle(.secondary)
        } else {
            Chart(counts) { day in
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Pomodoros", day.count))
                    .foregroundStyle(.red.gradient)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(minimumStride: 1)) { AxisGridLine(); AxisValueLabel() }
            }
            .frame(height: 160)
        }
    }
}
