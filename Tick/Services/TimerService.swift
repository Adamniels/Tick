import Foundation
import SwiftData

/// Starts, stops and continues timers. The single place that changes which entry is running.
struct TimerService {
    let context: ModelContext

    func runningEntries() throws -> [TimeEntry] {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.end == nil },
            sortBy: [SortDescriptor(\.start)]
        )
        return try context.fetch(descriptor)
    }

    /// Only one timer runs at a time: anything running is stopped at `now` first.
    @discardableResult
    func start(
        description: String, project: Project?, tags: [Tag], isPomodoro: Bool = false, at now: Date = .now
    ) throws -> TimeEntry {
        try stopRunning(at: now)
        let entry = TimeEntry(entryDescription: description, start: now, isPomodoro: isPomodoro)
        context.insert(entry)
        entry.project = project
        entry.tags = tags
        try context.save()
        return entry
    }

    func stop(at now: Date = .now) throws {
        try stopRunning(at: now)
        try context.save()
    }

    /// Starts a new timer with the same description, project and tags as `entry`.
    @discardableResult
    func continueEntry(_ entry: TimeEntry, isPomodoro: Bool = false, at now: Date = .now) throws -> TimeEntry {
        try start(
            description: entry.entryDescription, project: entry.project, tags: entry.tags ?? [],
            isPomodoro: isPomodoro, at: now
        )
    }

    /// The most recently started entry, running or not.
    func latestEntry() throws -> TimeEntry? {
        var descriptor = FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Saves an edited draft to `entry`, or creates a new manual entry when `entry` is nil.
    /// The caller validates the draft first (`EntryDraft.validationError`).
    @discardableResult
    func save(_ draft: EntryDraft, to entry: TimeEntry?) throws -> TimeEntry {
        let target = entry ?? TimeEntry(start: draft.start, end: draft.end)
        if entry == nil {
            context.insert(target)
        }
        target.entryDescription = draft.description.trimmingCharacters(in: .whitespaces)
        target.project = draft.project
        target.tags = draft.tags
        target.start = draft.start
        if !target.isRunning {
            target.end = draft.end
        }
        target.updatedAt = .now
        try context.save()
        return target
    }

    /// Deleting the running entry stops tracking.
    func delete(_ entry: TimeEntry) throws {
        context.delete(entry)
        try context.save()
    }

    /// Resolves several running entries, e.g. after starting timers on two Macs (decision D6).
    func resolveDuplicateRunning() throws {
        if Self.resolveDuplicateRunning(try runningEntries()) {
            try context.save()
        }
    }

    /// Keeps the newest running entry and ends each older one where the next newer one starts.
    /// Ordering is deterministic (start, then id), so two Macs resolving concurrently write the same values.
    /// Returns whether anything changed.
    static func resolveDuplicateRunning(_ entries: [TimeEntry]) -> Bool {
        let running = entries
            .filter(\.isRunning)
            .sorted { ($0.start, $0.id.uuidString) < ($1.start, $1.id.uuidString) }
        guard running.count > 1 else { return false }
        for (older, newer) in zip(running, running.dropFirst()) {
            older.end = newer.start
            older.updatedAt = .now
        }
        return true
    }

    private func stopRunning(at now: Date) throws {
        for entry in try runningEntries() {
            // Guards against a start slightly in the future from another Mac's clock.
            entry.end = max(now, entry.start)
            entry.updatedAt = now
        }
    }
}
