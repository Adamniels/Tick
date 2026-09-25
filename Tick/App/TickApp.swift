import SwiftUI

/// The menu bar item, its panel and the main window are AppKit-managed by `AppDelegate` (D16).
/// An app needs at least one scene, so an empty `Settings` scene fills that slot; the real
/// settings live in the main window (D20).
@main
struct TickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
