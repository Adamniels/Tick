import Charts
import SwiftData
import SwiftUI

/// Statistics for a chosen period (M5). All numbers come from `Statistics.compute`.
struct StatsView: View {
    @State private var kind: StatsPeriodKind = .week
    /// 0 is the current period, -1 the one before (#1).
    @State private var offset = 0
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    @State private var customEnd = Date.now

    var body: some View {
        // Every minute, so the period, its label and its query follow midnight even while the
        // window is closed (it's kept alive, D16).
        TimelineView(.everyMinute) { context in
            let now = context.date
            let period = StatsPeriod.make(
                kind, offset: offset, customStart: customStart, customEnd: customEnd, now: now, calendar: .current
            )
            let fetchRange = DateInterval(start: period.fetchStart, end: period.full.end)
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
                        } else {
                            PeriodStepper(kind: kind, full: period.full, now: now, offset: $offset)
                        }
                        Spacer()
                    }
                    .onChange(of: kind) { offset = 0 }

                    StatsContent(
                        kind: kind, offset: offset, customStart: customStart, customEnd: customEnd, fetchRange: fetchRange
                    )
                    // The query's range is fixed when StatsContent is created, so a new range needs a new view.
                    .id(fetchRange)
                }
                .padding(20)
            }
        }
        .navigationTitle("Statistics")
    }
}

/// ‹ › through days, weeks or months, the period shown, and a way back to the current one (#1).
private struct PeriodStepper: View {
    let kind: StatsPeriodKind
    let full: DateInterval
    let now: Date
    @Binding var offset: Int

    var body: some View {
        HStack(spacing: 8) {
            Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                .help("Previous \(kind.title.lowercased())")
            Button { offset += 1 } label: { Image(systemName: "chevron.right") }
                .help("Next \(kind.title.lowercased())")
                .disabled(offset >= 0)
            Text(label)
                .monospacedDigit()
            if offset != 0 {
                Button(kind.currentTitle) { offset = 0 }
            }
        }
    }

    private var label: String {
        let calendar = Calendar.current
        let lastDay = calendar.date(byAdding: .day, value: -1, to: full.end)!
        let otherYear = calendar.component(.year, from: lastDay) != calendar.component(.year, from: now)
        switch kind {
        case .day:
            let style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
            return full.start.formatted(otherYear ? style.year() : style)
        case .week:
            let week = calendar.component(.weekOfYear, from: full.start)
            let style = Date.IntervalFormatStyle().day().month(.abbreviated)
            return "Week \(week) · " + (full.start..<lastDay).formatted(otherYear ? style.year() : style)
        case .month:
            return full.start.formatted(.dateTime.month(.wide).year())
        case .custom:
            return ""
        }
    }
}

private struct StatsContent: View {
    let kind: StatsPeriodKind
    let offset: Int
    let customStart: Date
    let customEnd: Date

    @Query private var entries: [TimeEntry]
    @Query private var workBlocks: [PomodoroSession]

    init(kind: StatsPeriodKind, offset: Int, customStart: Date, customEnd: Date, fetchRange: DateInterval) {
        self.kind = kind
        self.offset = offset
        self.customStart = customStart
        self.customEnd = customEnd
        let from = fetchRange.start
        let to = fetchRange.end
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
            let period = StatsPeriod.make(
                kind, offset: offset, customStart: customStart, customEnd: customEnd, now: now, calendar: .current
            )
            let stats = Statistics.compute(
                entries: entries, completedWorkBlockStarts: workBlocks.map(\.start),
                period: period, now: now, calendar: .current
            )

            VStack(alignment: .leading, spacing: 20) {
                Header(stats: stats, kind: kind, isCurrent: offset == 0)
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
    let isCurrent: Bool

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
        let reference = switch (kind, isCurrent) {
        case (.day, true): "yesterday at this time"
        case (.day, false): "the day before"
        case (.week, true): "last week at this point"
        case (.week, false): "the week before"
        case (.month, true): "last month at this point"
        case (.month, false): "the month before"
        case (.custom, _): "the same length before"
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
