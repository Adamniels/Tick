import Foundation
import SwiftData

/// A tracked stretch of time. `end == nil` means the timer is running.
///
/// Relationships are not set in `init`: assign `project` and `tags` after the entry
/// has been inserted into a context (see `TimerService`).
@Model nonisolated final class TimeEntry {
    var id: UUID = UUID()
    var entryDescription: String = ""
    var start: Date = Date()
    var end: Date? = nil
    var isPomodoro: Bool = false
    var project: Project? = nil
    var tags: [Tag]? = []
    var updatedAt: Date = Date()

    init(entryDescription: String = "", start: Date = .now, end: Date? = nil, isPomodoro: Bool = false) {
        self.entryDescription = entryDescription
        self.start = start
        self.end = end
        self.isPomodoro = isPomodoro
    }

    var isRunning: Bool { end == nil }

    /// Elapsed time, derived from `start`. A running entry is measured up to `now`.
    func duration(at now: Date = .now) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}

extension TimeEntry {
    /// Entries can start long before they overlap a day or period (a forgotten timer), so queries
    /// that filter on `start` reach back this far and clip in memory.
    static let queryLookback: TimeInterval = 7 * 24 * 3600

    /// "Operation Rollout · Mini games", or whichever part exists.
    var displayLabel: String {
        let parts = [project?.name, entryDescription].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Your timer" : parts.joined(separator: " · ")
    }
}
