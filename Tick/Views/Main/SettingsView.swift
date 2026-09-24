import KeyboardShortcuts
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var launchAtLogin = LaunchAtLogin.State.disabled
    @Environment(\.modelContext) private var modelContext
    @State private var exportFile: ExportFile?
    @State private var exportType = UTType.json
    @State private var exportName = ""
    @State private var exportSummary = ""
    @State private var exportMessage: String?

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { general }
            Tab("Pomodoro", systemImage: "timer") { pomodoroSettings }
            Tab("Reminders", systemImage: "bell") { reminderSettings }
            Tab("Popup", systemImage: "rectangle.inset.filled") { popupSettings }
            Tab("Shortcuts", systemImage: "keyboard") { shortcutSettings }
            Tab("Data", systemImage: "externaldrive") { dataSettings }
        }
        .padding()
        .navigationTitle("Settings")
        .onAppear { launchAtLogin = LaunchAtLogin.state }
    }

    private var general: some View {
        Form {
            Section {
                Toggle("Open Tick at login", isOn: Binding(
                    get: { launchAtLogin != .disabled },
                    set: { enabled in
                        LaunchAtLogin.setEnabled(enabled)
                        launchAtLogin = LaunchAtLogin.state
                    }
                ))
                if launchAtLogin == .requiresApproval {
                    HStack {
                        Text("macOS needs your approval in Login Items.")
                            .foregroundStyle(.secondary)
                        Button("Open Login Items…", action: LaunchAtLogin.openSystemSettings)
                    }
                }
            } footer: {
                Text("Turn this on in the copy of Tick in Applications, not in a build run from Xcode.")
            }
        }
        .formStyle(.grouped)
    }

    private var pomodoroSettings: some View {
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

    private var reminderSettings: some View {
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

    private var popupSettings: some View {
        Form {
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
        .formStyle(.grouped)
    }

    private var shortcutSettings: some View {
        Form {
            Section {
                LabeledContent("Start or stop timer") {
                    KeyboardShortcuts.Recorder(for: .toggleTimer)
                }
                LabeledContent("Open Tick panel") {
                    KeyboardShortcuts.Recorder(for: .openPanel)
                }
                LabeledContent("Open Tick window") {
                    KeyboardShortcuts.Recorder(for: .openMainWindow)
                }
            } footer: {
                Text("Start or stop: stops the running timer, or continues your most recent entry when none is running.")
            }
        }
        .formStyle(.grouped)
    }

    /// Export (D35). Import (Toggl CSV, restoring a Tick export) belongs here too, in M8.
    private var dataSettings: some View {
        Form {
            Section {
                Button("Export all data (JSON)…") { prepareExport(csv: false) }
                Button("Export time entries (CSV)…") { prepareExport(csv: true) }
                if let exportMessage {
                    Text(exportMessage).foregroundStyle(.secondary)
                }
            } header: {
                Text("Export")
            } footer: {
                Text("JSON contains everything, times exact to the millisecond: projects, tags, entries, pomodoro sessions and these settings. "
                    + "Use it to move to a new app or database. CSV has one row per time entry, for spreadsheets or "
                    + "another time tracker.")
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
            document: exportFile,
            contentType: exportType,
            defaultFilename: exportName
        ) { result in
            switch result {
            case .success(let url): exportMessage = "Exported \(exportSummary) to \(url.lastPathComponent)."
            case .failure(let error): exportMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func prepareExport(csv: Bool) {
        do {
            let archive = try DataExport.archive(context: modelContext, settings: DataExport.currentSettings, now: .now)
            let day = Date.now.formatted(.iso8601.year().month().day())
            exportSummary = "\(archive.entries.count) entries"
                + (csv ? "" : ", \(archive.projects.count) projects, \(archive.tags.count) tags")
            exportName = csv ? "Tick entries \(day)" : "Tick export \(day)"
            exportType = csv ? .commaSeparatedText : .json
            exportFile = ExportFile(data: csv ? Data(DataExport.csv(archive).utf8) : try DataExport.json(archive))
            exportMessage = nil
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
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
