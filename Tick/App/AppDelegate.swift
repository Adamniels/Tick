import AppKit
import OSLog
import SwiftData

/// Composition root: builds the services and AppKit controllers, and drives the one-second
/// refresh that updates the menu bar and checks for pomodoro phase ends (decision D23).
final class AppDelegate: NSObject, NSApplicationDelegate {
    let modelContainer: ModelContainer
    private let storageError: String?
    private let overlay = OverlayController()
    private var pomodoro: PomodoroService?
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
        let mainWindowController = MainWindowController(modelContainer: modelContainer) { [overlay] in
            overlay.show(.test())
        }
        self.pomodoro = pomodoro
        self.mainWindowController = mainWindowController
        statusItemController = StatusItemController(
            modelContainer: modelContainer,
            pomodoro: pomodoro,
            storageError: storageError,
            onOpenMainWindow: { mainWindowController.show() }
        )

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

    /// Returns the date the menu bar clock counts from or towards, to align the next tick.
    private func refresh() -> Date? {
        // Saves made during a refresh post notifications; the outer refresh already covers them.
        guard !isRefreshing, let pomodoro, let statusItemController else { return nil }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date.now
        do {
            let timer = TimerService(context: modelContainer.mainContext)
            try timer.resolveDuplicateRunning()
            let entry = try timer.runningEntries().last
            let session = try pomodoro.update(at: now)
            statusItemController.show(entry: entry, session: session, now: now)
            return session?.plannedEnd ?? entry?.start
        } catch {
            Log.timer.error("Refresh failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
