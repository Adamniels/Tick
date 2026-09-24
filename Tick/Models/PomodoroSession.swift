import Foundation
import SwiftData

/// One pomodoro phase. Used from M2; part of the schema now so the first CloudKit deploy covers it.
@Model nonisolated final class PomodoroSession {
    var id: UUID = UUID()
    var phase: String = "work"      // work, shortBreak, longBreak
    var start: Date = Date()
    var plannedEnd: Date = Date()
    var completed: Bool = false

    init(phase: String = "work", start: Date = .now, plannedEnd: Date = .now) {
        self.phase = phase
        self.start = start
        self.plannedEnd = plannedEnd
    }
}
