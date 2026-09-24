import Foundation

/// Work hours as recurring windows. A window belongs to the weekday it starts on; an end at or
/// before the start means it runs past midnight (equal start and end means a full day).
nonisolated struct WorkHours: Equatable {
    var weekdayMask: Int
    var startMinute: Int
    var endMinute: Int

    func includes(weekday: Int) -> Bool {
        weekdayMask & (1 << (weekday - 1)) != 0
    }

    /// The start of the work window containing `date`, or nil outside work hours.
    func windowStart(containing date: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  includes(weekday: calendar.component(.weekday, from: day)),
                  let start = time(startMinute, on: day, calendar: calendar),
                  let end = windowEnd(startingOn: day, calendar: calendar)
            else { continue }
            if date >= start && date < end { return start }
        }
        return nil
    }

    private func windowEnd(startingOn day: Date, calendar: Calendar) -> Date? {
        let endDay = endMinute <= startMinute ? calendar.date(byAdding: .day, value: 1, to: day) : day
        return endDay.flatMap { time(endMinute, on: $0, calendar: calendar) }
    }

    /// Wall-clock time on `day`, so daylight saving changes keep 9:00 at 9:00.
    private func time(_ minute: Int, on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
    }
}

/// Tracks whether the Mac is "away": asleep, locked, or with its displays asleep.
/// Reports the whole away period once the last of those conditions clears.
nonisolated struct AwayTracker {
    enum Event {
        case sleep, wake, lock, unlock, displaysSleep, displaysWake
    }

    private(set) var awaySince: Date?
    private var asleep = false
    private var locked = false
    private var displaysAsleep = false

    var isAway: Bool { asleep || locked || displaysAsleep }

    mutating func handle(_ event: Event, at now: Date) -> DateInterval? {
        let wasAway = isAway
        switch event {
        case .sleep: asleep = true
        case .wake: asleep = false
        case .lock: locked = true
        case .unlock: locked = false
        case .displaysSleep: displaysAsleep = true
        case .displaysWake: displaysAsleep = false
        }
        if !wasAway && isAway {
            awaySince = now
        } else if wasAway && !isAway, let since = awaySince {
            awaySince = nil
            return DateInterval(start: since, end: max(since, now))
        }
        return nil
    }
}

nonisolated enum Reminder: Equatable {
    case idle
    case forgotten(entryID: UUID)
}

/// Decides which reminder is due, as a pure function of the current state (see D25).
nonisolated enum ReminderEvaluator {
    struct State {
        var now: Date
        var runningEntryID: UUID?
        var runningEntryStart: Date?
        var pomodoroActive = false
        var lastEntryEnd: Date?
        /// App launch or the latest return from being away: idle time never counts from before it.
        var baseline: Date
        var isPresent: Bool
        var idleSnoozedUntil: Date?
        var forgottenSnoozedUntil: Date?
    }

    static func evaluate(_ state: State, settings: ReminderSettings, calendar: Calendar) -> Reminder? {
        if let id = state.runningEntryID, let start = state.runningEntryStart {
            guard settings.forgottenEnabled,
                  state.now.timeIntervalSince(start) >= TimeInterval(max(1, settings.forgottenHours) * 3600),
                  state.now >= (state.forgottenSnoozedUntil ?? .distantPast)
            else { return nil }
            return .forgotten(entryID: id)
        }

        // A pomodoro break is deliberate time without a timer.
        guard settings.idleEnabled, !state.pomodoroActive, state.isPresent,
              state.now >= (state.idleSnoozedUntil ?? .distantPast),
              let windowStart = settings.workHours.windowStart(containing: state.now, calendar: calendar)
        else { return nil }

        let idleSince = max(state.lastEntryEnd ?? .distantPast, state.baseline, windowStart)
        let isIdle = state.now.timeIntervalSince(idleSince) >= TimeInterval(max(1, settings.idleMinutes) * 60)
        return isIdle ? .idle : nil
    }
}
