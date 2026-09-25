import AppKit
import SwiftData
import SwiftUI

/// The main window, created on first use and reused afterwards (decision D16).
final class MainWindowController {
    private let modelContainer: ModelContainer
    private let tracking: TrackingService
    private let pomodoro: PomodoroService
    private let onTestPopup: () -> Void
    private var window: NSWindow?

    init(
        modelContainer: ModelContainer, tracking: TrackingService, pomodoro: PomodoroService,
        onTestPopup: @escaping () -> Void
    ) {
        self.modelContainer = modelContainer
        self.tracking = tracking
        self.pomodoro = pomodoro
        self.onTestPopup = onTestPopup
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(
            rootView: MainWindow(onTestPopup: onTestPopup)
                .modelContainer(modelContainer)
                .environment(tracking)
                .environment(pomodoro)
        )
        hostingController.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Tick"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 820, height: 560))
        window.center()
        window.setFrameAutosaveName("MainWindow")
        return window
    }
}
