import Foundation

/// An editable copy of an entry. The editor changes the draft; nothing is saved until
/// `TimerService.save(_:to:)`, so Cancel really cancels.
nonisolated struct EntryDraft {
    var description = ""
    var project: Project?
    var tags: [Tag] = []
    var start: Date
    /// `nil` only for the running entry, whose end isn't edited here (stopping goes through the panel, D22).
    var end: Date?

    init(description: String = "", project: Project? = nil, tags: [Tag] = [], start: Date, end: Date?) {
        self.description = description
        self.project = project
        self.tags = tags
        self.start = start
        self.end = end
    }

    init(entry: TimeEntry) {
        self.init(
            description: entry.entryDescription, project: entry.project, tags: entry.tags ?? [],
            start: entry.start, end: entry.end
        )
    }

    /// A new manual entry: the last hour, ending at the current minute.
    static func newManual(now: Date, calendar: Calendar = .current) -> EntryDraft {
        let end = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        return EntryDraft(start: end - 3600, end: end)
    }

    var isRunning: Bool { end == nil }

    /// Why the draft can't be saved, or nil if it can.
    func validationError(now: Date) -> String? {
        if let end {
            return end > start ? nil : "The end must be after the start."
        }
        return start <= now ? nil : "A running timer can't start in the future."
    }
}

nonisolated enum EntryAnalysis {
    /// Ids of entries that overlap at least one other entry. A running entry lasts until `now`.
    /// Touching entries (one ends exactly when the next starts) don't overlap.
    ///
    /// One pass over the entries sorted by start, tracking the latest end so far: an entry starting
    /// before that end overlaps the entry that holds it. O(n log n).
    static func overlappingIDs(in entries: [TimeEntry], now: Date) -> Set<UUID> {
        let sorted = entries.sorted { $0.start < $1.start }
        var result = Set<UUID>()
        var latest: (end: Date, id: UUID)?
        for entry in sorted {
            let end = entry.end ?? now
            if let current = latest, entry.start < current.end {
                result.insert(entry.id)
                result.insert(current.id)
            }
            if end > (latest?.end ?? .distantPast) {
                latest = (end, entry.id)
            }
        }
        return result
    }

    struct Day: Identifiable {
        let start: Date
        let entries: [TimeEntry]
        let total: TimeInterval

        var id: Date { start }
    }

    /// Entries grouped by the day they start, newest day and newest entry first.
    static func days(of entries: [TimeEntry], now: Date, calendar: Calendar) -> [Day] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.start) }
            .map { start, entries in
                Day(
                    start: start,
                    entries: entries.sorted { $0.start > $1.start },
                    total: entries.reduce(0) { $0 + $1.duration(at: now) }
                )
            }
            .sorted { $0.start > $1.start }
    }
}
