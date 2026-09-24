import SwiftUI

/// Local settings (decision D20: a section of the main window rather than a Settings scene).
struct SettingsView: View {
    let onTestPopup: () -> Void

    private typealias Key = AppSettings.Key
    private static let pomodoro = PomodoroSettings()
    private static let overlay = OverlayAppearance()

    @AppStorage(Key.workMinutes) private var workMinutes = pomodoro.workMinutes
    @AppStorage(Key.shortBreakMinutes) private var shortBreakMinutes = pomodoro.shortBreakMinutes
    @AppStorage(Key.longBreakMinutes) private var longBreakMinutes = pomodoro.longBreakMinutes
    @AppStorage(Key.longBreakEvery) private var longBreakEvery = pomodoro.longBreakEvery
    @AppStorage(Key.extendMinutes) private var extendMinutes = pomodoro.extendMinutes
    @AppStorage(Key.keepEntryRunningDuringBreaks) private var keepEntryRunning = pomodoro.keepEntryRunningDuringBreaks
    private static let reminders = ReminderSettings()
    @AppStorage(Key.idleEnabled) private var idleEnabled = reminders.idleEnabled
    @AppStorage(Key.idleMinutes) private var idleMinutes = reminders.idleMinutes
    @AppStorage(Key.presenceMinutes) private var presenceMinutes = reminders.presenceMinutes
    @AppStorage(Key.workDaysMask) private var workDaysMask = reminders.workDaysMask
    @AppStorage(Key.workStartMinute) private var workStartMinute = reminders.workStartMinute
    @AppStorage(Key.workEndMinute) private var workEndMinute = reminders.workEndMinute
    @AppStorage(Key.forgottenEnabled) private var forgottenEnabled = reminders.forgottenEnabled
    @AppStorage(Key.forgottenHours) private var forgottenHours = reminders.forgottenHours
    @AppStorage(Key.awayEnabled) private var awayEnabled = reminders.awayEnabled
    @AppStorage(Key.awayMinimumMinutes) private var awayMinimumMinutes = reminders.awayMinimumMinutes
    @AppStorage(Key.snoozeMinutes) private var snoozeMinutes = reminders.snoozeMinutes

    @AppStorage(Key.overlayDimOpacity) private var dimOpacity = overlay.dimOpacity
    @AppStorage(Key.overlayCardSize) private var cardSize = overlay.cardSize
    @AppStorage(Key.overlaySound) private var sound = overlay.soundName

    private let soundNames = SystemSound.names

    var body: some View {
        Form {
            Section("Pomodoro") {
                Stepper("Work block: \(workMinutes) min", value: $workMinutes, in: 1...180)
                Stepper("Short break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...60)
                Stepper("Long break: \(longBreakMinutes) min", value: $longBreakMinutes, in: 1...120)
                Stepper("Long break after every \(longBreakEvery) blocks", value: $longBreakEvery, in: 1...12)
                Stepper("\"More time\" adds \(extendMinutes) min", value: $extendMinutes, in: 1...60)
                Toggle("Keep the time entry running during breaks", isOn: $keepEntryRunning)
            }

            Section("Work hours") {
                WeekdayPicker(mask: $workDaysMask)
                DatePicker("Start", selection: minuteOfDay($workStartMinute), displayedComponents: .hourAndMinute)
                DatePicker("End", selection: minuteOfDay($workEndMinute), displayedComponents: .hourAndMinute)
            }

            Section("Reminders") {
                Toggle("Remind me when no timer is running during work hours", isOn: $idleEnabled)
                Stepper("After \(idleMinutes) min without a timer", value: $idleMinutes, in: 1...240)
                    .disabled(!idleEnabled)
                Stepper("Only if I used the Mac in the last \(presenceMinutes) min", value: $presenceMinutes, in: 1...60)
                    .disabled(!idleEnabled)
                Stepper("\"Remind me later\" waits \(snoozeMinutes) min", value: $snoozeMinutes, in: 1...240)
                    .disabled(!idleEnabled)
                Toggle("Ask when a timer has run for a long time", isOn: $forgottenEnabled)
                Stepper("After \(forgottenHours) h", value: $forgottenHours, in: 1...24)
                    .disabled(!forgottenEnabled)
                Toggle("Ask about time away (sleep, lock) while a timer ran", isOn: $awayEnabled)
                Stepper("When away at least \(awayMinimumMinutes) min", value: $awayMinimumMinutes, in: 1...120)
                    .disabled(!awayEnabled)
            }

            Section("Popup") {
                Slider(value: $dimOpacity, in: 0.2...0.95) {
                    Text("Background dimming")
                }
                Picker("Card size", selection: $cardSize) {
                    ForEach(OverlayCardSize.allCases) { size in
                        Text(size.rawValue.capitalized).tag(size)
                    }
                }
                Picker("Sound", selection: $sound) {
                    Text("None").tag("")
                    ForEach(soundNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .onChange(of: sound) { _, name in SystemSound.play(name) }
                Button("Test popup", action: onTestPopup)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    /// Edits minutes since midnight through a time-of-day picker.
    private func minuteOfDay(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now
                ) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

/// Monday-first weekday toggles over a bitmask (bit n = Calendar weekday n + 1).
private struct WeekdayPicker: View {
    @Binding var mask: Int

    private static let mondayFirst = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        HStack {
            Text("Days")
            Spacer()
            ForEach(Self.mondayFirst, id: \.self) { weekday in
                let bit = 1 << (weekday - 1)
                Toggle(Calendar.current.veryShortWeekdaySymbols[weekday - 1], isOn: Binding(
                    get: { mask & bit != 0 },
                    set: { mask = $0 ? mask | bit : mask & ~bit }
                ))
                .toggleStyle(.button)
            }
        }
    }
}
