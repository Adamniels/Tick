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
        static let overlayDimOpacity = "overlay.dimOpacity"
        static let overlayCardSize = "overlay.cardSize"
        static let overlaySound = "overlay.sound"
    }

    static func registerDefaults() {
        let pomodoro = PomodoroSettings()
        let overlay = OverlayAppearance()
        UserDefaults.standard.register(defaults: [
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

    static var overlayAppearance: OverlayAppearance {
        let defaults = UserDefaults.standard
        return OverlayAppearance(
            dimOpacity: defaults.double(forKey: Key.overlayDimOpacity),
            cardSize: OverlayCardSize(rawValue: defaults.string(forKey: Key.overlayCardSize) ?? "") ?? .medium,
            soundName: defaults.string(forKey: Key.overlaySound) ?? ""
        )
    }
}
