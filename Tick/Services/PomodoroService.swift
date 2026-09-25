import Foundation
import Observation
import OSLog
import SwiftData

/// Pomodoro phases on top of the regular timer: transitions, the per-second check and the popup.
/// Starting and stopping tracking goes through `TrackingService` (D38), which calls `beginWorkBlock`
/// and `endRun` here.
///
/// All state lives in synced `PomodoroSession`s. Each Mac calls `update(at:)` every second and
/// derives the popup from the active phase's `plannedEnd` (decision D4), so a popup handled on
/// another Mac closes here once that change syncs. Rules for combining with the timer: D22.
@Observable final class PomodoroService {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let overlay: OverlayPresenting
    @ObservationIgnored private let settings: () -> PomodoroSettings
    /// The time popup buttons act at. Injected so tests can control it.
    @ObservationIgnored private let clock: () -> Date
    /// The phase whose popup this Mac is showing.
    @ObservationIgnored private var presentedSessionID: UUID?

    init(
        context: ModelContext,
        overlay: OverlayPresenting,
        settings: @escaping () -> PomodoroSettings = { AppSettings.pomodoro },
        clock: @escaping () -> Date = { .now }
    ) {
        self.context = context
        self.overlay = overlay
        self.settings = settings
        self.clock = clock
    }

    private var timer: TimerService { TimerService(context: context) }

    // MARK: - Queries

    func activeSession() throws -> PomodoroSession? {
        try activeSessions().last
    }

    func completedWorkBlocks(inRun runID: UUID) throws -> Int {
        let work = PomodoroPhase.work.rawValue
        let descriptor = FetchDescriptor<PomodoroSession>(
            predicate: #Predicate { $0.runID == runID && $0.phase == work && $0.completed }
        )
        return try context.fetchCount(descriptor)
    }

    // MARK: - Runs (called by TrackingService)

    /// Tracking started with pomodoro: keep the current work block (switching task mid-block),
    /// end a break and start the next block, or start a new run.
    func beginWorkBlock(at now: Date) throws {
        let active = try activeSession()
        switch active?.phaseValue {
        case .work:
            return
        case .shortBreak, .longBreak:
            finish(active!, completed: true, at: now)
            insertSession(runID: active!.runID, phase: .work, at: now)
        case nil:
            insertSession(runID: UUID(), phase: .work, at: now)
        }
        try context.save()
    }

    /// Ends the active run, if any. A work block ended at or after its planned end counts as done;
    /// one cut short doesn't.
    func endRun(at now: Date) throws {
        if let active = try activeSession() {
            finish(active, completed: active.phaseValue.isBreak || now >= active.plannedEnd, at: now)
        }
        try context.save()
    }

    // MARK: - Phase transitions (popup buttons and panel)

    func startBreak(after work: PomodoroSession, at now: Date = .now) throws {
        let settings = settings()
        finish(work, completed: true, at: now)
        try context.save()
        let completed = try completedWorkBlocks(inRun: work.runID)
        let phase = PomodoroCycle.breakPhase(afterCompletedWorkBlocks: completed, longBreakEvery: settings.longBreakEvery)
        insertSession(runID: work.runID, phase: phase, at: now)
        if !settings.keepEntryRunningDuringBreaks {
            try timer.stop(at: now)
        }
        try context.save()
    }

    /// Ends the break and starts a work block, continuing the last entry if it was stopped for the break.
    func startNextBlock(after breakSession: PomodoroSession, at now: Date = .now) throws {
        finish(breakSession, completed: true, at: now)
        insertSession(runID: breakSession.runID, phase: .work, at: now)
        if try timer.runningEntries().isEmpty, let last = try timer.latestEntry() {
            try timer.continueEntry(last, isPomodoro: true, at: now)
        }
        try context.save()
    }

    func extend(_ session: PomodoroSession, at now: Date = .now) throws {
        session.plannedEnd = max(session.plannedEnd, now) + settings().extensionDuration
        try context.save()
    }

    /// "End pomodoro" also stops the timer (D22).
    func end(at now: Date = .now) throws {
        try endRun(at: now)
        try timer.stop(at: now)
    }

    // MARK: - Tick

    /// Called every second and after saves. Resolves duplicate active phases, closes a popup that
    /// was handled elsewhere, and shows the popup once the active phase has reached its end.
    @discardableResult
    func update(at now: Date = .now) throws -> PomodoroSession? {
        try resolveDuplicateActive()
        let active = try activeSession()

        if let presented = presentedSessionID {
            let stillDue = active.map { $0.id == presented && now >= $0.plannedEnd } ?? false
            if !stillDue {
                overlay.dismiss(id: Self.overlayID(presented))
                presentedSessionID = nil
            }
        }
        if let active, now >= active.plannedEnd, presentedSessionID != active.id {
            presentedSessionID = active.id
            overlay.show(request(for: active))
        }
        return active
    }

    static func overlayID(_ sessionID: UUID) -> String { "pomodoro.\(sessionID.uuidString)" }

    // MARK: - Private

    private func activeSessions() throws -> [PomodoroSession] {
        let descriptor = FetchDescriptor<PomodoroSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.start)]
        )
        return try context.fetch(descriptor)
            .sorted { ($0.start, $0.id.uuidString) < ($1.start, $1.id.uuidString) }
    }

    /// Two Macs can start a run at the same time. Like running entries (D6): keep the newest,
    /// end each older one where the next starts. Deterministic, so concurrent resolution agrees.
    private func resolveDuplicateActive() throws {
        let active = try activeSessions()
        guard active.count > 1 else { return }
        for (older, newer) in zip(active, active.dropFirst()) {
            older.endedAt = max(newer.start, older.start)
        }
        try context.save()
    }

    private func finish(_ session: PomodoroSession, completed: Bool, at now: Date) {
        session.endedAt = max(now, session.start)
        session.completed = completed
    }

    private func insertSession(runID: UUID, phase: PomodoroPhase, at now: Date) {
        let session = PomodoroSession(
            runID: runID, phase: phase, start: now, plannedEnd: now + settings().duration(of: phase)
        )
        context.insert(session)
    }

    private func request(for session: PomodoroSession) -> OverlayRequest {
        let settings = settings()
        let completed = (try? completedWorkBlocks(inRun: session.runID)) ?? 0
        let extendTitle = "\(settings.extendMinutes) more min"

        switch session.phaseValue {
        case .work:
            let next = PomodoroCycle.breakPhase(
                afterCompletedWorkBlocks: completed + 1, longBreakEvery: settings.longBreakEvery
            )
            let minutes = Int(settings.duration(of: next) / 60)
            return OverlayRequest(
                id: Self.overlayID(session.id),
                symbol: "checkmark.circle.fill",
                title: "Work block \(completed + 1) done",
                message: "Time for a \(next == .longBreak ? "long" : "short") break (\(minutes) min).",
                actions: [
                    OverlayAction(title: "Start break", role: .primary) { [weak self] in
                        self?.perform { try $0.startBreak(after: session, at: $0.clock()) }
                    },
                    OverlayAction(title: extendTitle) { [weak self] in
                        self?.perform { try $0.extend(session, at: $0.clock()) }
                    },
                    OverlayAction(title: "End pomodoro", role: .destructive) { [weak self] in
                        self?.perform { try $0.end(at: $0.clock()) }
                    },
                ]
            )
        case .shortBreak, .longBreak:
            return OverlayRequest(
                id: Self.overlayID(session.id),
                symbol: "cup.and.saucer.fill",
                title: "Break's over",
                message: "Ready for work block \(completed + 1)?",
                actions: [
                    OverlayAction(title: "Start next block", role: .primary) { [weak self] in
                        self?.perform { try $0.startNextBlock(after: session, at: $0.clock()) }
                    },
                    OverlayAction(title: "Extend break \(settings.extendMinutes) min") { [weak self] in
                        self?.perform { try $0.extend(session, at: $0.clock()) }
                    },
                    OverlayAction(title: "End", role: .destructive) { [weak self] in
                        self?.perform { try $0.end(at: $0.clock()) }
                    },
                ]
            )
        }
    }

    private func perform(_ action: (PomodoroService) throws -> Void) {
        do {
            try action(self)
        } catch {
            Log.pomodoro.error("Pomodoro action failed: \(String(describing: error), privacy: .public)")
        }
    }
}
