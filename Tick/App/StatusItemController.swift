import AppKit
import SwiftData
import SwiftUI

/// Owns the menu bar item and its panel (decision D16). `AppDelegate` decides when to redraw.
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(
        modelContainer: ModelContainer,
        pomodoro: PomodoroService,
        storageError: String?,
        onOpenMainWindow: @escaping () -> Void
    ) {
        super.init()

        let panel = MenuBarPanel(storageError: storageError) { [weak self] in
            self?.popover.performClose(nil)
            onOpenMainWindow()
        }
        .modelContainer(modelContainer)
        .environment(pomodoro)
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
        show(entry: nil, session: nil, now: .now)
    }

    func show(entry: TimeEntry?, session: PomodoroSession?, now: Date) {
        guard let button = statusItem.button else { return }
        let name = entry?.project?.name ?? entry?.entryDescription

        if let session {
            button.image = session.phaseValue == .work ? .dot(hex: entry?.project?.colorHex ?? HexColor.fallback) : nil
            button.title = (button.image == nil ? "" : " ") + MenuBarTitle.pomodoroText(
                phase: session.phaseValue, remaining: session.plannedEnd.timeIntervalSince(now), name: name
            )
        } else if let entry {
            button.image = .dot(hex: entry.project?.colorHex ?? HexColor.fallback)
            button.title = " " + MenuBarTitle.text(
                projectName: entry.project?.name, description: entry.entryDescription, elapsed: entry.duration(at: now)
            )
        } else {
            let icon = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "Tick")
            icon?.isTemplate = true
            button.image = icon
            button.title = ""
        }
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
}

nonisolated enum MenuBarTitle {
    static let maxNameLength = 24

    /// "0:42:13 Operation Rollout": the project name, else the description, else just the clock.
    static func text(projectName: String?, description: String, elapsed: TimeInterval) -> String {
        let name = projectName ?? description
        return join(DurationFormat.clock(elapsed), name)
    }

    /// "🍅 18:42 Operation Rollout" during work, "☕ 4:12" during a break.
    static func pomodoroText(phase: PomodoroPhase, remaining: TimeInterval, name: String?) -> String {
        let countdown = DurationFormat.countdown(remaining)
        return phase == .work ? join("🍅 \(countdown)", name ?? "") : "☕ \(countdown)"
    }

    /// Wakes just after the next whole second relative to `reference` (a start to count from or
    /// an end to count towards), so the displayed seconds never skip.
    static func delayUntilNextTick(reference: Date?, now: Date) -> TimeInterval {
        guard let reference else { return 1 }
        var fraction = now.timeIntervalSince(reference).truncatingRemainder(dividingBy: 1)
        if fraction < 0 { fraction += 1 }
        return 1 - fraction + 0.02
    }

    private static func join(_ prefix: String, _ name: String) -> String {
        guard !name.isEmpty else { return prefix }
        let shortName = name.count > maxNameLength ? name.prefix(maxNameLength - 1) + "…" : name
        return "\(prefix) \(shortName)"
    }
}
