import Foundation
import SwiftData
import Testing
@testable import Tick

struct PomodoroCycleTests {
    @Test func longBreakAfterEveryFourthBlock() {
        let phases = (1...8).map { PomodoroCycle.breakPhase(afterCompletedWorkBlocks: $0, longBreakEvery: 4) }
        #expect(phases == [.shortBreak, .shortBreak, .shortBreak, .longBreak,
                           .shortBreak, .shortBreak, .shortBreak, .longBreak])
    }

    @Test func customIntervalAndDegenerateValues() {
        #expect(PomodoroCycle.breakPhase(afterCompletedWorkBlocks: 2, longBreakEvery: 2) == .longBreak)
        #expect(PomodoroCycle.breakPhase(afterCompletedWorkBlocks: 1, longBreakEvery: 0) == .longBreak)
        #expect(PomodoroCycle.breakPhase(afterCompletedWorkBlocks: 0, longBreakEvery: 4) == .shortBreak)
    }

    @Test func durationsFollowSettings() {
        let settings = PomodoroSettings(workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30)
        #expect(settings.duration(of: .work) == 3000)
        #expect(settings.duration(of: .shortBreak) == 600)
        #expect(settings.duration(of: .longBreak) == 1800)
    }
}

final class SpyOverlay: OverlayPresenting {
    var shown: [OverlayRequest] = []
    var dismissed: [String] = []

    func show(_ request: OverlayRequest) { shown.append(request) }
    func dismiss(id: String) { dismissed.append(id) }

    func press(_ title: String) throws {
        let action = try #require(shown.last?.actions.first { $0.title == title })
        action.handler()
    }
}

final class PomodoroServiceTests {
    let container = Persistence.makeInMemoryContainer()
    let overlay = SpyOverlay()
    var settings = PomodoroSettings()
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    lazy var service = PomodoroService(
        context: context, overlay: overlay,
        settings: { [unowned self] in self.settings },
        clock: { [unowned self] in self.now }
    )
    lazy var tracking = TrackingService(context: context, pomodoro: service)

    var context: ModelContext { container.mainContext }
    var timer: TimerService { TimerService(context: context) }

    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let work: TimeInterval = 25 * 60

    private func entries() throws -> [TimeEntry] {
        try context.fetch(FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.start)]))
    }

    private func startWorking(at date: Date? = nil) throws {
        try tracking.start(description: "Mini games", project: nil, tags: [], usePomodoro: true, at: date ?? t0)
    }

    @Test func startingWithPomodoroCreatesAWorkBlockAndAPomodoroEntry() throws {
        try startWorking()

        let session = try #require(try service.activeSession())
        #expect(session.phaseValue == .work)
        #expect(session.plannedEnd == t0 + work)
        #expect(try timer.runningEntries().first?.isPomodoro == true)
    }

    @Test func popupAppearsOnlyAtPlannedEndAndOnlyOnce() throws {
        try startWorking()

        try service.update(at: t0 + work - 1)
        #expect(overlay.shown.isEmpty)

        try service.update(at: t0 + work)
        try service.update(at: t0 + work + 5)
        #expect(overlay.shown.count == 1)
        #expect(overlay.shown.first?.title == "Work block 1 done")
    }

    @Test func startBreakStopsTheEntryAndStartsAShortBreak() throws {
        try startWorking()
        now = t0 + work
        try service.update(at: now)
        try overlay.press("Start break")

        let active = try #require(try service.activeSession())
        #expect(active.phaseValue == .shortBreak)
        #expect(try timer.runningEntries().isEmpty)
        #expect(try service.completedWorkBlocks(inRun: active.runID) == 1)
    }

    @Test func keepEntryRunningSettingLeavesTheTimerOnDuringBreaks() throws {
        settings.keepEntryRunningDuringBreaks = true
        try startWorking()
        try service.startBreak(after: try #require(try service.activeSession()), at: t0 + work)

        #expect(try timer.runningEntries().count == 1)
    }

    @Test func fourthCompletedBlockIsFollowedByALongBreak() throws {
        try startWorking()
        var now = t0
        for _ in 1...3 {
            now += work
            try service.startBreak(after: try #require(try service.activeSession()), at: now)
            #expect(try service.activeSession()?.phaseValue == .shortBreak)
            now += 5 * 60
            try service.startNextBlock(after: try #require(try service.activeSession()), at: now)
        }
        now += work
        try service.startBreak(after: try #require(try service.activeSession()), at: now)

        #expect(try service.activeSession()?.phaseValue == .longBreak)
    }

    @Test func nextBlockContinuesTheEntryAsANewPomodoroEntry() throws {
        try startWorking()
        try service.startBreak(after: try #require(try service.activeSession()), at: t0 + work)
        try service.startNextBlock(after: try #require(try service.activeSession()), at: t0 + work + 300)

        let all = try entries()
        #expect(all.count == 2)
        #expect(all[0].end == t0 + work)
        #expect(all[1].isRunning)
        #expect(all[1].isPomodoro)
        #expect(all[1].entryDescription == "Mini games")
        #expect(try service.activeSession()?.phaseValue == .work)
    }

    @Test func extendMovesThePlannedEndAndClosesThePopup() throws {
        try startWorking()
        now = t0 + work
        try service.update(at: now)
        try overlay.press("5 more min")
        try service.update(at: t0 + work + 1)

        #expect(try service.activeSession()?.plannedEnd == t0 + work + 300)
        #expect(overlay.dismissed.count == 1)
        #expect(overlay.shown.count == 1)

        try service.update(at: t0 + work + 300)
        #expect(overlay.shown.count == 2)
    }

    @Test func endPomodoroStopsTheTimerAndCountsTheBlock() throws {
        try startWorking()
        let session = try #require(try service.activeSession())
        now = t0 + work
        try service.update(at: now)
        try overlay.press("End pomodoro")

        #expect(try service.activeSession() == nil)
        #expect(try timer.runningEntries().isEmpty)
        #expect(session.completed)
    }

    @Test func stoppingEarlyEndsTheRunWithoutCountingTheBlock() throws {
        try startWorking()
        let session = try #require(try service.activeSession())
        try tracking.stop(at: t0 + 60)

        #expect(try service.activeSession() == nil)
        #expect(!session.completed)
    }

    @Test func startingWithoutPomodoroEndsTheRun() throws {
        try startWorking()
        try tracking.start(description: "Email", project: nil, tags: [], usePomodoro: false, at: t0 + 60)

        #expect(try service.activeSession() == nil)
        #expect(try timer.runningEntries().first?.isPomodoro == false)
    }

    @Test func switchingTaskMidBlockKeepsTheBlock() throws {
        try startWorking()
        let block = try #require(try service.activeSession())
        try tracking.start(description: "Other task", project: nil, tags: [], usePomodoro: true, at: t0 + 60)

        #expect(try service.activeSession() == block)
    }

    @Test func startingToWorkDuringABreakStartsTheNextBlock() throws {
        try startWorking()
        try service.startBreak(after: try #require(try service.activeSession()), at: t0 + work)
        try startWorking(at: t0 + work + 60)

        #expect(try service.activeSession()?.phaseValue == .work)
    }

    @Test func popupClosesWhenAnotherMacHandledThePhase() throws {
        try startWorking()
        let session = try #require(try service.activeSession())
        try service.update(at: t0 + work)

        // Simulates the other Mac's synced "Start break".
        session.endedAt = t0 + work + 10
        context.insert(PomodoroSession(runID: session.runID, phase: .shortBreak, start: t0 + work + 10, plannedEnd: t0 + work + 310))
        try service.update(at: t0 + work + 20)

        #expect(overlay.dismissed == [PomodoroService.overlayID(session.id)])
    }

    @Test func duplicateActivePhasesKeepTheNewest() throws {
        let older = PomodoroSession(runID: UUID(), phase: .work, start: t0, plannedEnd: t0 + work)
        let newer = PomodoroSession(runID: UUID(), phase: .work, start: t0 + 30, plannedEnd: t0 + 30 + work)
        context.insert(older)
        context.insert(newer)

        try service.update(at: t0 + 60)

        #expect(try service.activeSession() == newer)
        #expect(older.endedAt == t0 + 30)
    }
}
