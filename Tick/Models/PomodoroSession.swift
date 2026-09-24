import Foundation
import SwiftData

/// One pomodoro phase. The active phase has `endedAt == nil`; the popup is derived from `plannedEnd`
/// on each Mac and never sent through the database (decision D4).
@Model nonisolated final class PomodoroSession {
    var id: UUID = UUID()
    /// Groups the work blocks and breaks of one pomodoro run (decision D21).
    var runID: UUID = UUID()
    var phase: String = PomodoroPhase.work.rawValue
    var start: Date = Date()
    var plannedEnd: Date = Date()
    /// When the phase was handled (next phase started, or the run ended). `nil` while active.
    var endedAt: Date? = nil
    /// The phase ran its full length. Completed work blocks are the ones counted in statistics.
    var completed: Bool = false

    init(runID: UUID, phase: PomodoroPhase, start: Date, plannedEnd: Date) {
        self.runID = runID
        self.phase = phase.rawValue
        self.start = start
        self.plannedEnd = plannedEnd
    }

    var phaseValue: PomodoroPhase { PomodoroPhase(rawValue: phase) ?? .work }
}

nonisolated enum PomodoroPhase: String, CaseIterable {
    case work, shortBreak, longBreak

    var isBreak: Bool { self != .work }

    var title: String {
        switch self {
        case .work: "Work block"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}
