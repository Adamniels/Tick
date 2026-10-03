import AppKit
import SwiftData
import SwiftUI

/// The main window, created on first use and reused afterwards (decision D16).
final class MainWindowController {
    private let modelContainer: ModelContainer
    private let tracking: TrackingService
    private let pomodoro: PomodoroService
    private let errors: ErrorReporter
    private let onTestPopup: () -> Void
    private var window: NSWindow?

    init(
        modelContainer: ModelContainer, tracking: TrackingService, pomodoro: PomodoroService,
        errors: ErrorReporter, onTestPopup: @escaping () -> Void
    ) {
        self.modelContainer = modelContainer
        self.tracking = tracking
        self.pomodoro = pomodoro
        self.errors = errors
        self.onTestPopup = onTestPopup
    }

    /// Shows the window on the current Space and display (#3). The window is ordered in before Tick
    /// activates: activating first switched to the Space the window was last on, and that switch
    /// could leave the system menu bar blank (#6). The popover and the popup use the same order.
    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            window.setFrame(WindowPlacement.frame(window.frame, on: screen.visibleFrame), display: false)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(
            rootView: MainWindow(onTestPopup: onTestPopup)
                .modelContainer(modelContainer)
                .environment(tracking)
                .environment(pomodoro)
                .environment(errors)
        )
        hostingController.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Tick"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.setContentSize(NSSize(width: 820, height: 560))
        window.center()
        window.setFrameAutosaveName("MainWindow")
        return window
    }
}

nonisolated enum WindowPlacement {
    /// Keeps `frame` if its centre is on the display with `visibleFrame`; otherwise centres it there,
    /// shrunk to fit if needed.
    static func frame(_ frame: CGRect, on visibleFrame: CGRect) -> CGRect {
        if visibleFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) { return frame }
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        return CGRect(
            x: visibleFrame.midX - width / 2, y: visibleFrame.midY - height / 2, width: width, height: height
        )
    }
}
