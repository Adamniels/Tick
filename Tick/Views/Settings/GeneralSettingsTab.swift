import SwiftUI

struct GeneralSettingsTab: View {
    @Environment(ErrorReporter.self) private var errors
    @State private var launchAtLogin = LaunchAtLogin.State.disabled

    var body: some View {
        Form {
            Section {
                Toggle("Open Tick at login", isOn: Binding(
                    get: { launchAtLogin != .disabled },
                    set: { enabled in
                        errors.run("Changing launch at login") { try LaunchAtLogin.setEnabled(enabled) }
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
        .onAppear { launchAtLogin = LaunchAtLogin.state }
    }
}
