import Foundation

/// Local, per-Mac settings (never synced). The struct defaults are the single source of truth
/// for default values: `registerDefaults()` and the `@AppStorage` properties both use them.
nonisolated struct PomodoroSettings: Equatable {
    var workMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var longBreakEvery = 4
    var extendMinutes = 5
    var keepEntryRunningDuringBreaks = false

    func duration(of phase: PomodoroPhase) -> TimeInterval {
        let minutes = switch phase {
        case .work: workMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
        return TimeInterval(max(1, minutes) * 60)
    }

    var extensionDuration: TimeInterval { TimeInterval(max(1, extendMinutes) * 60) }
}

nonisolated struct ReminderSettings: Equatable {
    var idleEnabled = true
    var idleMinutes = 15
    /// Input within this many minutes (and an unlocked screen) counts as being at the Mac.
    var presenceMinutes = 5
    /// Bit n is Calendar weekday n + 1 (bit 0 = Sunday). Default Monday to Friday.
    var workDaysMask = 0b011_1110
    var workStartMinute = 9 * 60
    var workEndMinute = 17 * 60
    var forgottenEnabled = true
    var forgottenHours = 3
    var awayEnabled = true
    var awayMinimumMinutes = 5
    var snoozeMinutes = 15

    var workHours: WorkHours {
        WorkHours(weekdayMask: workDaysMask, startMinute: workStartMinute, endMinute: workEndMinute)
    }
}

nonisolated enum OverlayCardSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: Self { self }

    var scale: CGFloat {
        switch self {
        case .small: 0.85
        case .medium: 1
        case .large: 1.3
        }
    }
}

nonisolated struct OverlayAppearance {
    var dimOpacity = 0.6
    var cardSize = OverlayCardSize.medium
    /// A system sound name, or "" for no sound.
    var soundName = "Glass"
}

nonisolated enum AppSettings {
    nonisolated enum Key {
        static let pomodoroEnabled = "pomodoro.enabled"
        static let workMinutes = "pomodoro.workMinutes"
        static let shortBreakMinutes = "pomodoro.shortBreakMinutes"
        static let longBreakMinutes = "pomodoro.longBreakMinutes"
        static let longBreakEvery = "pomodoro.longBreakEvery"
        static let extendMinutes = "pomodoro.extendMinutes"
        static let keepEntryRunningDuringBreaks = "pomodoro.keepEntryRunningDuringBreaks"
        static let idleEnabled = "reminders.idleEnabled"
        static let idleMinutes = "reminders.idleMinutes"
        static let presenceMinutes = "reminders.presenceMinutes"
        static let workDaysMask = "reminders.workDaysMask"
        static let workStartMinute = "reminders.workStartMinute"
        static let workEndMinute = "reminders.workEndMinute"
        static let forgottenEnabled = "reminders.forgottenEnabled"
        static let forgottenHours = "reminders.forgottenHours"
        static let awayEnabled = "reminders.awayEnabled"
        static let awayMinimumMinutes = "reminders.awayMinimumMinutes"
        static let snoozeMinutes = "reminders.snoozeMinutes"
        static let overlayDimOpacity = "overlay.dimOpacity"
        static let overlayCardSize = "overlay.cardSize"
        static let overlaySound = "overlay.sound"
    }

    static func registerDefaults() {
        let pomodoro = PomodoroSettings()
        let overlay = OverlayAppearance()
        let reminders = ReminderSettings()
        UserDefaults.standard.register(defaults: [
            Key.idleEnabled: reminders.idleEnabled,
            Key.idleMinutes: reminders.idleMinutes,
            Key.presenceMinutes: reminders.presenceMinutes,
            Key.workDaysMask: reminders.workDaysMask,
            Key.workStartMinute: reminders.workStartMinute,
            Key.workEndMinute: reminders.workEndMinute,
            Key.forgottenEnabled: reminders.forgottenEnabled,
            Key.forgottenHours: reminders.forgottenHours,
            Key.awayEnabled: reminders.awayEnabled,
            Key.awayMinimumMinutes: reminders.awayMinimumMinutes,
            Key.snoozeMinutes: reminders.snoozeMinutes,
            Key.pomodoroEnabled: false,
            Key.workMinutes: pomodoro.workMinutes,
            Key.shortBreakMinutes: pomodoro.shortBreakMinutes,
            Key.longBreakMinutes: pomodoro.longBreakMinutes,
            Key.longBreakEvery: pomodoro.longBreakEvery,
            Key.extendMinutes: pomodoro.extendMinutes,
            Key.keepEntryRunningDuringBreaks: pomodoro.keepEntryRunningDuringBreaks,
            Key.overlayDimOpacity: overlay.dimOpacity,
            Key.overlayCardSize: overlay.cardSize.rawValue,
            Key.overlaySound: overlay.soundName,
        ])
    }

    static var pomodoro: PomodoroSettings {
        let defaults = UserDefaults.standard
        return PomodoroSettings(
            workMinutes: defaults.integer(forKey: Key.workMinutes),
            shortBreakMinutes: defaults.integer(forKey: Key.shortBreakMinutes),
            longBreakMinutes: defaults.integer(forKey: Key.longBreakMinutes),
            longBreakEvery: defaults.integer(forKey: Key.longBreakEvery),
            extendMinutes: defaults.integer(forKey: Key.extendMinutes),
            keepEntryRunningDuringBreaks: defaults.bool(forKey: Key.keepEntryRunningDuringBreaks)
        )
    }

    static var reminders: ReminderSettings {
        let defaults = UserDefaults.standard
        return ReminderSettings(
            idleEnabled: defaults.bool(forKey: Key.idleEnabled),
            idleMinutes: defaults.integer(forKey: Key.idleMinutes),
            presenceMinutes: defaults.integer(forKey: Key.presenceMinutes),
            workDaysMask: defaults.integer(forKey: Key.workDaysMask),
            workStartMinute: defaults.integer(forKey: Key.workStartMinute),
            workEndMinute: defaults.integer(forKey: Key.workEndMinute),
            forgottenEnabled: defaults.bool(forKey: Key.forgottenEnabled),
            forgottenHours: defaults.integer(forKey: Key.forgottenHours),
            awayEnabled: defaults.bool(forKey: Key.awayEnabled),
            awayMinimumMinutes: defaults.integer(forKey: Key.awayMinimumMinutes),
            snoozeMinutes: defaults.integer(forKey: Key.snoozeMinutes)
        )
    }

    static var overlayAppearance: OverlayAppearance {
        let defaults = UserDefaults.standard
        return OverlayAppearance(
            dimOpacity: defaults.double(forKey: Key.overlayDimOpacity),
            cardSize: OverlayCardSize(rawValue: defaults.string(forKey: Key.overlayCardSize) ?? "") ?? .medium,
            soundName: defaults.string(forKey: Key.overlaySound) ?? ""
        )
    }
}
