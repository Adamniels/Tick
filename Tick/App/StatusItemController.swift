import AppKit
import SwiftData
import SwiftUI

/// Owns the menu bar item and its dropdown panel (decisions D16, D24). `AppDelegate` decides when to redraw.
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = MenuBarWindow()
    private var hostingView: NSHostingView<AnyView>?
    private var resignObserver: NSObjectProtocol?
    private var lastClosed = Date.distantPast
    /// Where the open panel's top-left corner is pinned, in screen coordinates.
    private var topLeft: NSPoint?

    init(
        modelContainer: ModelContainer,
        pomodoro: PomodoroService,
        storageError: String?,
        onOpenMainWindow: @escaping () -> Void
    ) {
        super.init()

        let content = MenuBarPanel(storageError: storageError) { [weak self] in
            self?.close()
            onOpenMainWindow()
        }
        .modelContainer(modelContainer)
        .environment(pomodoro)
        .fixedSize()
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
            self?.resize(to: size)
        }
        let hostingView = NSHostingView(rootView: AnyView(content))
        // The window is sized explicitly from the measured content, never by the hosting view.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onEscape = { [weak self] in self?.close() }
        self.hostingView = hostingView

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
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

    @objc private func togglePanel() {
        if panel.isVisible {
            close()
        } else if Date.now.timeIntervalSince(lastClosed) > 0.3 {
            // Guard: a click on the item can first close the panel by taking key status,
            // and must not reopen it in the same click.
            open()
        }
    }

    /// Placed once, like a menu, on the screen whose menu bar was clicked (D24).
    /// While open, only the height changes and the top-left corner stays pinned.
    private func open() {
        guard let button = statusItem.button, let buttonWindow = button.window,
              let screen = buttonWindow.screen, let hostingView else { return }
        let itemFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = hostingView.fittingSize
        topLeft = DropdownLayout.topLeft(below: itemFrame, width: size.width, in: screen.visibleFrame)
        resize(to: size)

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        button.highlight(true)
    }

    private func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        lastClosed = .now
        statusItem.button?.highlight(false)
    }

    /// Sets the whole frame explicitly, so the pinned corner never depends on how AppKit resizes.
    private func resize(to size: CGSize) {
        guard let topLeft, size.width > 0, size.height > 0 else { return }
        panel.setFrame(DropdownLayout.frame(topLeft: topLeft, size: size), display: true)
        panel.invalidateShadow()
    }
}

/// The dropdown under the menu bar item: borderless and menu-like. Positioned by `StatusItemController`.
final class MenuBarWindow: NSPanel {
    var onEscape: (() -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }

    /// Esc closes it, like a menu.
    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

/// Placement of the dropdown, as pure geometry in screen coordinates (origin bottom-left,
/// y up; secondary screens can have negative coordinates).
nonisolated enum DropdownLayout {
    static let screenMargin: CGFloat = 8
    static let gapBelowItem: CGFloat = 4

    /// Just below the menu bar item with left edges aligned, pushed left if it would leave the screen.
    static func topLeft(below itemFrame: NSRect, width: CGFloat, in visibleFrame: NSRect) -> NSPoint {
        let rightmostX = visibleFrame.maxX - screenMargin - width
        let x = max(visibleFrame.minX + screenMargin, min(itemFrame.minX, rightmostX))
        let y = min(itemFrame.minY, visibleFrame.maxY) - gapBelowItem
        return NSPoint(x: x, y: y)
    }

    /// The frame for `size` hanging down from `topLeft`.
    static func frame(topLeft: NSPoint, size: CGSize) -> NSRect {
        NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
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
