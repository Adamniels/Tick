import SwiftUI

struct PomodoroSettingsTab: View {
    private typealias Key = AppSettings.Key
    private static let defaults = PomodoroSettings()

    @AppStorage(Key.workMinutes) private var workMinutes = defaults.workMinutes
    @AppStorage(Key.shortBreakMinutes) private var shortBreakMinutes = defaults.shortBreakMinutes
    @AppStorage(Key.longBreakMinutes) private var longBreakMinutes = defaults.longBreakMinutes
    @AppStorage(Key.longBreakEvery) private var longBreakEvery = defaults.longBreakEvery
    @AppStorage(Key.extendMinutes) private var extendMinutes = defaults.extendMinutes
    @AppStorage(Key.keepEntryRunningDuringBreaks) private var keepEntryRunning = defaults.keepEntryRunningDuringBreaks

    var body: some View {
        Form {
            Stepper("Work block: \(workMinutes) min", value: $workMinutes, in: 1...180)
            Stepper("Short break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...60)
            Stepper("Long break: \(longBreakMinutes) min", value: $longBreakMinutes, in: 1...120)
            Stepper("Long break after every \(longBreakEvery) blocks", value: $longBreakEvery, in: 1...12)
            Stepper("\"More time\" adds \(extendMinutes) min", value: $extendMinutes, in: 1...60)
            Toggle("Keep the time entry running during breaks", isOn: $keepEntryRunning)
        }
        .formStyle(.grouped)
    }
}
