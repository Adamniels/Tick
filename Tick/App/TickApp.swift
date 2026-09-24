import SwiftUI

/// The menu bar item, its panel and the main window are AppKit-managed by `AppDelegate`
/// (decision D16), so the only SwiftUI scene is a placeholder until M2 adds real settings.
@main
struct TickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
