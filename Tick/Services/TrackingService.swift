import Foundation
import Observation
import SwiftData

/// The one entry point for starting, stopping and continuing tracking: the panel, global shortcuts,
/// reminders, entries and calendar all go through here (D38). It applies the rules that combine the
/// timer with pomodoro (D22); `TimerService` only knows entries, `PomodoroService` only phases.
@Observable final class TrackingService {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let pomodoro: PomodoroService

    init(context: ModelContext, pomodoro: PomodoroService) {
        self.context = context
        self.pomodoro = pomodoro
    }

    private var timer: TimerService { TimerService(context: context) }

    /// Starts a timer (stopping any running one). With pomodoro, it joins the current run or starts
    /// one (during a break: the next work block); without, any run ends.
    func start(description: String, project: Project?, tags: [Tag], usePomodoro: Bool, at now: Date = .now) throws {
        try timer.start(description: description, project: project, tags: tags, isPomodoro: usePomodoro, at: now)
        if usePomodoro {
            try pomodoro.beginWorkBlock(at: now)
        } else {
            try pomodoro.endRun(at: now)
        }
    }

    func continueEntry(_ entry: TimeEntry, usePomodoro: Bool, at now: Date = .now) throws {
        try start(
            description: entry.entryDescription, project: entry.project, tags: entry.tags ?? [],
            usePomodoro: usePomodoro, at: now
        )
    }

    /// Stopping the timer ends the pomodoro run.
    func stop(at now: Date = .now) throws {
        try timer.stop(at: now)
        try pomodoro.endRun(at: now)
    }
}
