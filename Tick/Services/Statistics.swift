import Foundation

nonisolated enum StatsPeriodKind: String, CaseIterable, Identifiable {
    case today, week, month, custom

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .week: "This week"
        case .month: "This month"
        case .custom: "Custom"
        }
    }
}

/// The period to show and the one to compare with (D32).
nonisolated struct StatsPeriod: Equatable {
    /// The whole period, for example Monday 00:00 to next Monday 00:00.
    let full: DateInterval
    /// The part of `full` up to now: what's measured.
    let current: DateInterval
    /// The previous period up to the same point in time.
    let previous: DateInterval
    /// Start of each day in `full`, for per-day charts.
    let days: [Date]

    /// Where a fetch for this period (and the previous one) starts; see `TimeEntry.queryLookback`.
    var fetchStart: Date { previous.start - TimeEntry.queryLookback }

    static func make(
        _ kind: StatsPeriodKind, customStart: Date, customEnd: Date, now: Date, calendar: Calendar
    ) -> StatsPeriod {
        let full: DateInterval
        let previousStart: Date
        switch kind {
        case .today, .week, .month:
            let unit: Calendar.Component = kind == .today ? .day : kind == .week ? .weekOfYear : .month
            full = calendar.dateInterval(of: unit, for: now)!
            previousStart = calendar.date(byAdding: unit, value: -1, to: full.start)!
        case .custom:
            let first = calendar.startOfDay(for: min(customStart, customEnd))
            let last = calendar.startOfDay(for: max(customStart, customEnd))
            full = DateInterval(start: first, end: calendar.date(byAdding: .day, value: 1, to: last)!)
            previousStart = full.start - full.duration
        }

        let elapsed = min(max(0, now.timeIntervalSince(full.start)), full.duration)
        let previousEnd = min(previousStart + elapsed, full.start)
        var days: [Date] = []
        var day = full.start
        while day < full.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return StatsPeriod(
            full: full,
            current: DateInterval(start: full.start, duration: elapsed),
            previous: DateInterval(start: previousStart, end: max(previousStart, previousEnd)),
            days: days
        )
    }
}

/// Everything the statistics page shows, computed from entries as pure data (D30, D31).
nonisolated struct Statistics {
    struct Slice: Identifiable, Equatable {
        let id: String
        let name: String
        let colorHex: String
        let seconds: TimeInterval
    }

    struct DaySlice: Identifiable, Equatable {
        let day: Date
        let name: String
        let seconds: TimeInterval

        var id: String { "\(day.timeIntervalSinceReferenceDate)|\(name)" }
    }

    struct DayCount: Identifiable, Equatable {
        let day: Date
        let count: Int

        var id: Date { day }
    }

    let total: TimeInterval
    let previousTotal: TimeInterval
    /// Largest first. "No project" included when it has time.
    let projects: [Slice]
    /// Largest first. An entry counts toward each of its tags; "No tag" included when it has time.
    let tags: [Slice]
    /// Time per day and project, entries split at midnight.
    let days: [DaySlice]
    let pomodorosPerDay: [DayCount]
    /// Summed time minus the time actually covered, and how many entries overlap.
    let overlapSeconds: TimeInterval
    let overlappingEntryCount: Int

    static let noProjectID = "no-project"
    static let noTagID = "no-tag"

    static func compute(
        entries: [TimeEntry], completedWorkBlockStarts: [Date], period: StatsPeriod, now: Date, calendar: Calendar
    ) -> Statistics {
        let inPeriod = entries.compactMap { entry -> (entry: TimeEntry, interval: DateInterval)? in
            clip(entry, to: period.current, now: now).map { (entry, $0) }
        }
        let total = inPeriod.reduce(0) { $0 + $1.interval.duration }
        let previousTotal = entries.reduce(0) { $0 + (clip($1, to: period.previous, now: now)?.duration ?? 0) }

        var projectTotals: [String: (name: String, colorHex: String, seconds: TimeInterval)] = [:]
        var tagTotals: [String: (name: String, colorHex: String, seconds: TimeInterval)] = [:]
        for (entry, interval) in inPeriod {
            let key = projectKey(entry)
            projectTotals[key.id, default: (key.name, key.colorHex, 0)].seconds += interval.duration
            let tags = entry.tags ?? []
            if tags.isEmpty {
                tagTotals[noTagID, default: ("No tag", HexColor.fallback, 0)].seconds += interval.duration
            }
            for tag in tags {
                tagTotals[tag.id.uuidString, default: (tag.name, tag.colorHex, 0)].seconds += interval.duration
            }
        }

        var daySlices: [DaySlice] = []
        for day in period.days {
            let dayInterval = DateInterval(start: day, end: calendar.date(byAdding: .day, value: 1, to: day)!)
            var perProject: [String: TimeInterval] = [:]
            for (entry, interval) in inPeriod {
                if let part = interval.intersection(with: dayInterval), part.duration > 0 {
                    perProject[projectKey(entry).name, default: 0] += part.duration
                }
            }
            daySlices += perProject.map { DaySlice(day: day, name: $0.key, seconds: $0.value) }
                .sorted { $0.name < $1.name }
        }

        let pomodoros = period.days.map { day in
            DayCount(day: day, count: completedWorkBlockStarts.filter {
                calendar.isDate($0, inSameDayAs: day) && period.current.contains($0)
            }.count)
        }

        let overlapping = EntryAnalysis.overlappingIDs(in: inPeriod.map(\.entry), now: now)
        let covered = coveredDuration(of: inPeriod.map(\.interval))

        return Statistics(
            total: total,
            previousTotal: previousTotal,
            projects: slices(projectTotals),
            tags: slices(tagTotals),
            days: daySlices,
            pomodorosPerDay: pomodoros,
            overlapSeconds: max(0, total - covered),
            overlappingEntryCount: overlapping.count
        )
    }

    /// The part of `entry` inside `interval`; a running entry lasts until `now`.
    static func clip(_ entry: TimeEntry, to interval: DateInterval, now: Date) -> DateInterval? {
        let start = max(entry.start, interval.start)
        let end = min(entry.end ?? now, interval.end)
        return end > start ? DateInterval(start: start, end: end) : nil
    }

    /// Length of the union of intervals.
    static func coveredDuration(of intervals: [DateInterval]) -> TimeInterval {
        var covered: TimeInterval = 0
        var current: DateInterval?
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let open = current, interval.start <= open.end {
                current = DateInterval(start: open.start, end: max(open.end, interval.end))
            } else {
                covered += current?.duration ?? 0
                current = interval
            }
        }
        return covered + (current?.duration ?? 0)
    }

    private static func projectKey(_ entry: TimeEntry) -> (id: String, name: String, colorHex: String) {
        guard let project = entry.project else { return (noProjectID, "No project", HexColor.fallback) }
        return (project.id.uuidString, project.name, project.colorHex)
    }

    private static func slices(_ totals: [String: (name: String, colorHex: String, seconds: TimeInterval)]) -> [Slice] {
        totals.map { Slice(id: $0.key, name: $0.value.name, colorHex: $0.value.colorHex, seconds: $0.value.seconds) }
            .sorted { ($0.seconds, $1.name) > ($1.seconds, $0.name) }
    }
}
