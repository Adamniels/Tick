import AppKit
import OSLog
import SwiftData

/// Idle, forgotten-timer and away reminders (M3). Each Mac decides locally, since presence is
/// local (D25); a popup closes itself once its reason is resolved, for example from another Mac.
final class ReminderService {
    /// Opens the menu bar panel, for the idle popup's "Start new timer".
    var onStartNewTimer: (() -> Void)?

    private let context: ModelContext
    private let overlay: OverlayPresenting
    private let pomodoro: PomodoroService
    private let settings: () -> ReminderSettings
    private let clock: () -> Date
    private let secondsSinceInput: () -> TimeInterval
    private let calendar: Calendar

    private let launchDate: Date
    private var away = AwayTracker()
    private var lastReturn: Date?
    private var idleSnoozedUntil: Date?
    private var forgottenSnoozedUntil: [UUID: Date] = [:]
    private var presentedIdle = false
    private var presentedForgotten: UUID?
    private var presentedAway: UUID?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(
        context: ModelContext,
        overlay: OverlayPresenting,
        pomodoro: PomodoroService,
        settings: @escaping () -> ReminderSettings = { AppSettings.reminders },
        clock: @escaping () -> Date = { .now },
        secondsSinceInput: @escaping () -> TimeInterval = ReminderService.secondsSinceLastInput,
        calendar: Calendar = .current,
        observeSystem: Bool = true
    ) {
        self.context = context
        self.overlay = overlay
        self.pomodoro = pomodoro
        self.settings = settings
        self.clock = clock
        self.secondsSinceInput = secondsSinceInput
        self.calendar = calendar
        launchDate = clock()
        if observeSystem { observeSystemEvents() }
    }

    private var timer: TimerService { TimerService(context: context) }

    // MARK: - Tick

    /// Called every second from the refresh loop.
    func update(at now: Date, runningEntry: TimeEntry?, pomodoroActive: Bool) throws {
        closeResolved(runningEntry: runningEntry, pomodoroActive: pomodoroActive)
        guard !away.isAway else { return }

        let settings = settings()
        let state = ReminderEvaluator.State(
            now: now,
            runningEntryID: runningEntry?.id,
            runningEntryStart: runningEntry?.start,
            pomodoroActive: pomodoroActive,
            lastEntryEnd: try timer.latestEntry()?.end,
            baseline: max(launchDate, lastReturn ?? .distantPast),
            isPresent: secondsSinceInput() < TimeInterval(max(1, settings.presenceMinutes) * 60),
            idleSnoozedUntil: idleSnoozedUntil,
            forgottenSnoozedUntil: runningEntry.flatMap { forgottenSnoozedUntil[$0.id] }
        )

        switch ReminderEvaluator.evaluate(state, settings: settings, calendar: calendar) {
        case .idle where !presentedIdle:
            presentedIdle = true
            overlay.show(idleRequest())
        case .forgotten(let id) where presentedForgotten != id:
            if let runningEntry {
                presentedForgotten = id
                overlay.show(forgottenRequest(for: runningEntry, now: now))
            }
        default:
            break
        }
    }

    // MARK: - Away

    func handle(_ event: AwayTracker.Event, at now: Date) {
        guard let interval = away.handle(event, at: now) else { return }
        lastReturn = interval.end

        let settings = settings()
        guard settings.awayEnabled,
              interval.duration >= TimeInterval(max(1, settings.awayMinimumMinutes) * 60),
              let entry = try? timer.runningEntries().last,
              entry.start < interval.start,
              presentedAway != entry.id
        else { return }
        presentedAway = entry.id
        overlay.show(awayRequest(for: entry, interval: interval))
    }

    // MARK: - Popups

    static let idleOverlayID = "reminder.idle"
    static func forgottenOverlayID(_ id: UUID) -> String { "reminder.forgotten.\(id.uuidString)" }
    static func awayOverlayID(_ id: UUID) -> String { "reminder.away.\(id.uuidString)" }

    private func idleRequest() -> OverlayRequest {
        let snooze = settings().snoozeMinutes
        let quickStarts = recentDistinctEntries(limit: 3).map { entry in
            OverlayAction(title: "▶ \(Self.label(for: entry))", role: .normal) { [weak self] in
                self?.finishIdle()
                self?.perform {
                    try $0.pomodoro.continueEntry(
                        entry, usePomodoro: UserDefaults.standard.bool(forKey: AppSettings.Key.pomodoroEnabled),
                        at: $0.clock()
                    )
                }
            }
        }
        return OverlayRequest(
            id: Self.idleOverlayID,
            symbol: "questionmark.circle.fill",
            title: "What are you working on?",
            message: "No timer is running.",
            actions: quickStarts + [
                OverlayAction(title: "Start new timer", role: .primary) { [weak self] in
                    self?.finishIdle()
                    self?.onStartNewTimer?()
                },
                OverlayAction(title: "Remind me in \(snooze) min") { [weak self] in
                    guard let self else { return }
                    finishIdle()
                    idleSnoozedUntil = clock() + TimeInterval(max(1, snooze) * 60)
                },
            ]
        )
    }

    private func forgottenRequest(for entry: TimeEntry, now: Date) -> OverlayRequest {
        let hours = settings().forgottenHours
        let input = OverlayDateInput(label: "Stopped at", range: entry.start...now, date: now)
        let id = entry.id
        return OverlayRequest(
            id: Self.forgottenOverlayID(id),
            symbol: "hourglass",
            title: "Still working?",
            message: "\(Self.label(for: entry)) has been running for \(DurationFormat.spoken(entry.duration(at: now))).",
            dateInput: input,
            actions: [
                OverlayAction(title: "Still working", role: .primary) { [weak self] in
                    guard let self else { return }
                    presentedForgotten = nil
                    forgottenSnoozedUntil[id] = clock() + TimeInterval(max(1, hours) * 3600)
                },
                OverlayAction(title: "Stop at selected time") { [weak self] in
                    self?.presentedForgotten = nil
                    self?.perform { try $0.pomodoro.stop(at: input.date) }
                },
                OverlayAction(title: "Stop now", role: .destructive) { [weak self] in
                    self?.presentedForgotten = nil
                    self?.perform { try $0.pomodoro.stop(at: $0.clock()) }
                },
            ]
        )
    }

    private func awayRequest(for entry: TimeEntry, interval: DateInterval) -> OverlayRequest {
        let left = interval.start.formatted(date: .omitted, time: .shortened)
        let back = interval.end.formatted(date: .omitted, time: .shortened)
        return OverlayRequest(
            id: Self.awayOverlayID(entry.id),
            symbol: "moon.zzz.fill",
            title: "Welcome back",
            message: "You were away for \(DurationFormat.spoken(interval.duration)) (\(left)–\(back)) "
                + "while \(Self.label(for: entry)) kept running.",
            actions: [
                OverlayAction(title: "Remove away time", role: .primary) { [weak self] in
                    self?.presentedAway = nil
                    // Split around the gap: end at departure, continue as a new entry from now.
                    self?.perform {
                        try $0.timer.stop(at: interval.start)
                        try $0.timer.continueEntry(entry, isPomodoro: entry.isPomodoro, at: $0.clock())
                    }
                },
                OverlayAction(title: "Keep the time") { [weak self] in
                    self?.presentedAway = nil
                },
                OverlayAction(title: "Stop at \(left)", role: .destructive) { [weak self] in
                    self?.presentedAway = nil
                    self?.perform { try $0.pomodoro.stop(at: interval.start) }
                },
            ]
        )
    }

    // MARK: - Private

    /// Closes popups whose reason no longer holds (a timer started, or the entry was stopped elsewhere).
    private func closeResolved(runningEntry: TimeEntry?, pomodoroActive: Bool) {
        if presentedIdle && (runningEntry != nil || pomodoroActive) {
            finishIdle()
            overlay.dismiss(id: Self.idleOverlayID)
        }
        if let id = presentedForgotten, runningEntry?.id != id {
            presentedForgotten = nil
            overlay.dismiss(id: Self.forgottenOverlayID(id))
        }
        if let id = presentedAway, runningEntry?.id != id {
            presentedAway = nil
            overlay.dismiss(id: Self.awayOverlayID(id))
        }
    }

    private func finishIdle() {
        presentedIdle = false
    }

    /// The most recent entries with distinct project and description, for quick starts.
    private func recentDistinctEntries(limit: Int) -> [TimeEntry] {
        var descriptor = FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        descriptor.fetchLimit = 50
        let recent = (try? context.fetch(descriptor)) ?? []
        var seen = Set<String>()
        var result: [TimeEntry] = []
        for entry in recent where entry.project != nil || !entry.entryDescription.isEmpty {
            let key = "\(entry.project?.id.uuidString ?? "-")|\(entry.entryDescription)"
            if seen.insert(key).inserted { result.append(entry) }
            if result.count == limit { break }
        }
        return result
    }

    /// "Operation Rollout · Mini games", or whichever part exists.
    static func label(for entry: TimeEntry) -> String {
        let parts = [entry.project?.name, entry.entryDescription].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Your timer" : parts.joined(separator: " · ")
    }

    private func perform(_ action: (ReminderService) throws -> Void) {
        do {
            try action(self)
        } catch {
            Log.timer.error("Reminder action failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let events: [(NotificationCenter, Notification.Name, AwayTracker.Event)] = [
            (workspace, NSWorkspace.willSleepNotification, .sleep),
            (workspace, NSWorkspace.didWakeNotification, .wake),
            (workspace, NSWorkspace.screensDidSleepNotification, .displaysSleep),
            (workspace, NSWorkspace.screensDidWakeNotification, .displaysWake),
            (distributed, Notification.Name("com.apple.screenIsLocked"), .lock),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), .unlock),
        ]
        for (center, name, event) in events {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.handle(event, at: self.clock())
                }
            }
            observers.append((center, token))
        }
    }

    /// Seconds since the last keyboard, mouse or trackpad input in this login session.
    nonisolated static func secondsSinceLastInput() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .flagsChanged, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
    }
}
