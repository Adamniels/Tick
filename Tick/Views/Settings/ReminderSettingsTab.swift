import SwiftUI

/// Work hours and the idle, long-running and away reminders (M3).
struct ReminderSettingsTab: View {
    private typealias Key = AppSettings.Key
    private static let defaults = ReminderSettings()

    @AppStorage(Key.idleEnabled) private var idleEnabled = defaults.idleEnabled
    @AppStorage(Key.idleMinutes) private var idleMinutes = defaults.idleMinutes
    @AppStorage(Key.presenceMinutes) private var presenceMinutes = defaults.presenceMinutes
    @AppStorage(Key.workDaysMask) private var workDaysMask = defaults.workDaysMask
    @AppStorage(Key.workStartMinute) private var workStartMinute = defaults.workStartMinute
    @AppStorage(Key.workEndMinute) private var workEndMinute = defaults.workEndMinute
    @AppStorage(Key.forgottenEnabled) private var forgottenEnabled = defaults.forgottenEnabled
    @AppStorage(Key.forgottenHours) private var forgottenHours = defaults.forgottenHours
    @AppStorage(Key.awayEnabled) private var awayEnabled = defaults.awayEnabled
    @AppStorage(Key.awayMinimumMinutes) private var awayMinimumMinutes = defaults.awayMinimumMinutes
    @AppStorage(Key.snoozeMinutes) private var snoozeMinutes = defaults.snoozeMinutes

    var body: some View {
        Form {
            Section("Work hours") {
                WeekdayPicker(mask: $workDaysMask)
                DatePicker("Start", selection: minuteOfDay($workStartMinute), displayedComponents: .hourAndMinute)
                DatePicker("End", selection: minuteOfDay($workEndMinute), displayedComponents: .hourAndMinute)
            }
            Section("Not tracking") {
                Toggle("Remind me when no timer is running during work hours", isOn: $idleEnabled)
                Stepper("After \(idleMinutes) min without a timer", value: $idleMinutes, in: 1...240)
                    .disabled(!idleEnabled)
                Stepper("Only if I used the Mac in the last \(presenceMinutes) min", value: $presenceMinutes, in: 1...60)
                    .disabled(!idleEnabled)
                Stepper("\"Remind me later\" waits \(snoozeMinutes) min", value: $snoozeMinutes, in: 1...240)
                    .disabled(!idleEnabled)
            }
            Section("Long-running timer") {
                Toggle("Ask when a timer has run for a long time", isOn: $forgottenEnabled)
                Stepper("After \(forgottenHours) h", value: $forgottenHours, in: 1...24)
                    .disabled(!forgottenEnabled)
            }
            Section("Time away") {
                Toggle("Ask about time away (sleep, lock) while a timer ran", isOn: $awayEnabled)
                Stepper("When away at least \(awayMinimumMinutes) min", value: $awayMinimumMinutes, in: 1...120)
                    .disabled(!awayEnabled)
            }
        }
        .formStyle(.grouped)
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
