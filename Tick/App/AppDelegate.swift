import AppKit
import KeyboardShortcuts
import OSLog
import SwiftData

/// Composition root: builds the services and AppKit controllers, and drives the one-second
/// refresh that updates the menu bar, checks for pomodoro phase ends and evaluates reminders (D23).
final class AppDelegate: NSObject, NSApplicationDelegate {
    let modelContainer: ModelContainer
    private let storageError: String?
    private let overlay = OverlayController()
    private var pomodoro: PomodoroService?
    private var reminders: ReminderService?
    private var statusItemController: StatusItemController?
    private var mainWindowController: MainWindowController?
    private var tickTask: Task<Void, Never>?
    private var saveObserver: NSObjectProtocol?
    private var isRefreshing = false

    override init() {
        AppSettings.registerDefaults()
        let result = Persistence.makeContainer()
        modelContainer = result.container
        storageError = result.error.map { String(describing: $0) }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit test host needs no UI.
        guard !Persistence.isRunningTests else { return }

        let pomodoro = PomodoroService(context: modelContainer.mainContext, overlay: overlay)
        let mainWindowController = MainWindowController(modelContainer: modelContainer, pomodoro: pomodoro) { [overlay] in
            overlay.show(.test())
        }
        let statusItemController = StatusItemController(
            modelContainer: modelContainer,
            pomodoro: pomodoro,
            storageError: storageError,
            onOpenMainWindow: { mainWindowController.show() }
        )
        let reminders = ReminderService(context: modelContainer.mainContext, overlay: overlay, pomodoro: pomodoro)
        reminders.onStartNewTimer = { [weak statusItemController] in statusItemController?.openPanel() }
        self.pomodoro = pomodoro
        self.reminders = reminders
        self.mainWindowController = mainWindowController
        self.statusItemController = statusItemController

        registerShortcuts(pomodoro: pomodoro, statusItemController: statusItemController)

        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.refresh() }
        }
        // Each tick fetches fresh state, so CloudKit imports and wake from sleep need no special handling.
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                let reference = self?.refresh()
                try? await Task.sleep(for: .seconds(MenuBarTitle.delayUntilNextTick(reference: reference, now: .now)))
            }
        }
    }

    /// Start or stop: stops the running timer, or continues the most recent entry (D33).
    private func registerShortcuts(pomodoro: PomodoroService, statusItemController: StatusItemController) {
        let context = modelContainer.mainContext
        KeyboardShortcuts.onKeyUp(for: .toggleTimer) { [weak statusItemController] in
            let timer = TimerService(context: context)
            do {
                if try !timer.runningEntries().isEmpty {
                    try pomodoro.stop()
                } else if let latest = try timer.latestEntry() {
                    let usePomodoro = UserDefaults.standard.bool(forKey: AppSettings.Key.pomodoroEnabled)
                    try pomodoro.continueEntry(latest, usePomodoro: usePomodoro)
                } else {
                    statusItemController?.openPanel()
                }
            } catch {
                Log.timer.error("Shortcut failed: \(String(describing: error), privacy: .public)")
            }
        }
        KeyboardShortcuts.onKeyUp(for: .openPanel) { [weak statusItemController] in
            statusItemController?.openPanel()
        }
    }

    /// Returns the date the menu bar clock counts from or towards, to align the next tick.
    private func refresh() -> Date? {
        // Saves made during a refresh post notifications; the outer refresh already covers them.
        guard !isRefreshing, let pomodoro, let reminders, let statusItemController else { return nil }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date.now
        do {
            let timer = TimerService(context: modelContainer.mainContext)
            try timer.resolveDuplicateRunning()
            let entry = try timer.runningEntries().last
            let session = try pomodoro.update(at: now)
            try reminders.update(at: now, runningEntry: entry, pomodoroActive: session != nil)
            statusItemController.show(entry: entry, session: session, now: now)
            return session?.plannedEnd ?? entry?.start
        } catch {
            Log.timer.error("Refresh failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
