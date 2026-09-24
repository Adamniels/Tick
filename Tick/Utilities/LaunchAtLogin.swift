import OSLog
import ServiceManagement

/// Launch at login through the system's login items for this app (`SMAppService.mainApp`).
enum LaunchAtLogin {
    enum State {
        case enabled, disabled
        /// Registered, but the user must allow it in System Settings → General → Login Items.
        case requiresApproval
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.storage.error("Changing launch at login failed: \(String(describing: error), privacy: .public)")
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
