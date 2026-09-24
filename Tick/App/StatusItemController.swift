import AppKit
import OSLog
import SwiftData
import SwiftUI

/// Owns the menu bar item and its panel (decision D16).
///
/// The title is redrawn on every model save and on a one-second tick. Each redraw fetches the
/// running entry, so CloudKit imports show up too, and duplicate running entries from several
/// Macs are resolved here (decision D12).
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let context: ModelContext
    private var tickTask: Task<Void, Never>?
    private var saveObserver: NSObjectProtocol?

    init(modelContainer: ModelContainer, storageError: String?, onOpenMainWindow: @escaping () -> Void) {
        context = modelContainer.mainContext
        super.init()

        let panel = MenuBarPanel(storageError: storageError) { [weak self] in
            self?.popover.performClose(nil)
            onOpenMainWindow()
        }
        .modelContainer(modelContainer)
        let hostingController = NSHostingController(rootView: panel)
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        popover.behavior = .transient

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }

        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.refresh() }
        }
        startTicking()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                let runningStart = self?.refresh()
                try? await Task.sleep(for: .seconds(MenuBarTitle.delayUntilNextTick(start: runningStart, now: .now)))
            }
        }
    }

    /// Redraws the item and returns the running entry's start, if any.
    private func refresh() -> Date? {
        let service = TimerService(context: context)
        do {
            var running = try service.runningEntries()
            if running.count > 1 {
                try service.resolveDuplicateRunning()
                running = try service.runningEntries()
            }
            show(running.last)
            return running.last?.start
        } catch {
            Log.timer.error("Refreshing the menu bar failed: \(String(describing: error), privacy: .public)")
            show(nil)
            return nil
        }
    }

    private func show(_ entry: TimeEntry?) {
        guard let button = statusItem.button else { return }
        if let entry {
            button.image = .dot(hex: entry.project?.colorHex ?? HexColor.fallback)
            button.title = " " + MenuBarTitle.text(
                projectName: entry.project?.name,
                description: entry.entryDescription,
                elapsed: entry.duration()
            )
        } else {
            let icon = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "Tick")
            icon?.isTemplate = true
            button.image = icon
            button.title = ""
        }
    }
}

nonisolated enum MenuBarTitle {
    static let maxNameLength = 24

    /// "0:42:13 Operation Rollout": the project name, else the description, else just the clock.
    static func text(projectName: String?, description: String, elapsed: TimeInterval) -> String {
        let clock = DurationFormat.clock(elapsed)
        let name = projectName ?? description
        guard !name.isEmpty else { return clock }
        let shortName = name.count > maxNameLength ? name.prefix(maxNameLength - 1) + "…" : name
        return "\(clock) \(shortName)"
    }

    /// Wakes just after the next whole second of elapsed time, so the clock never skips a second.
    static func delayUntilNextTick(start: Date?, now: Date) -> TimeInterval {
        guard let start else { return 1 }
        var fraction = now.timeIntervalSince(start).truncatingRemainder(dividingBy: 1)
        if fraction < 0 { fraction += 1 }
        return 1 - fraction + 0.02
    }
}
