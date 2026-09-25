import KeyboardShortcuts
import SwiftUI

/// Global shortcuts (D33), stored by KeyboardShortcuts itself.
struct ShortcutSettingsTab: View {
    var body: some View {
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
}
