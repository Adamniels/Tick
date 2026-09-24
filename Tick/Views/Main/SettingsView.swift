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
}
