import SwiftUI

/// Local settings, one tab per area (decision D20: a section of the main window rather than a
/// Settings scene). Each tab owns its `@AppStorage` values; defaults come from `AppSettings`.
struct SettingsView: View {
    let onTestPopup: () -> Void

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettingsTab() }
            Tab("Pomodoro", systemImage: "timer") { PomodoroSettingsTab() }
            Tab("Reminders", systemImage: "bell") { ReminderSettingsTab() }
            Tab("Popup", systemImage: "rectangle.inset.filled") { PopupSettingsTab(onTestPopup: onTestPopup) }
            Tab("Shortcuts", systemImage: "keyboard") { ShortcutSettingsTab() }
            Tab("Data", systemImage: "externaldrive") { DataSettingsTab() }
        }
        .padding()
        .navigationTitle("Settings")
    }
}
