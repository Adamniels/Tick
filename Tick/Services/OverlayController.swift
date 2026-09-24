import AppKit
import OSLog
import SwiftUI

struct OverlayAction: Identifiable {
    enum Role { case primary, normal, destructive }

    let id = UUID()
    let title: String
    var role: Role = .normal
    let handler: () -> Void
}

/// What the popup shows. `id` identifies the reason for the popup, so a request can be
/// dismissed from elsewhere (for example when another Mac handled it) and isn't queued twice.
struct OverlayRequest: Identifiable {
    let id: String
    var symbol = "bell.fill"
    let title: String
    let message: String
    let actions: [OverlayAction]

    static func test() -> OverlayRequest {
        OverlayRequest(
            id: "test",
            title: "This is the popup",
            message: "It stays on every screen and Space until you choose a button.",
            actions: [OverlayAction(title: "Close", role: .primary) {}]
        )
    }
}

protocol OverlayPresenting: AnyObject {
    func show(_ request: OverlayRequest)
    func dismiss(id: String)
}

/// The popup that can't be missed: one full-screen panel per screen, above everything,
/// on every Space. It closes only through one of its buttons, or `dismiss(id:)`.
/// One popup at a time; later requests queue.
final class OverlayController: OverlayPresenting {
    private var panels: [OverlayPanel] = []
    private var current: OverlayRequest?
    private var queue: [OverlayRequest] = []
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIfShown() }
        }
    }

    func show(_ request: OverlayRequest) {
        guard current?.id != request.id, !queue.contains(where: { $0.id == request.id }) else { return }
        if current == nil {
            present(request)
        } else {
            queue.append(request)
        }
    }

    func dismiss(id: String) {
        queue.removeAll { $0.id == id }
        guard current?.id == id else { return }
        closePanels()
        current = nil
        presentNext()
    }

    private func present(_ request: OverlayRequest) {
        current = request
        buildPanels(for: request)
        SystemSound.play(AppSettings.overlayAppearance.soundName)
    }

    private func presentNext() {
        guard current == nil, !queue.isEmpty else { return }
        present(queue.removeFirst())
    }

    private func perform(_ action: OverlayAction) {
        guard current != nil else { return }
        closePanels()
        current = nil
        action.handler()
        presentNext()
    }

    private func rebuildIfShown() {
        if let current { buildPanels(for: current) }
    }

    private func buildPanels(for request: OverlayRequest) {
        closePanels()
        let appearance = AppSettings.overlayAppearance
        panels = NSScreen.screens.map { screen in
            let panel = OverlayPanel(screen: screen)
            let hostingView = NSHostingView(
                rootView: OverlayView(request: request, appearance: appearance) { [weak self] action in
                    self?.perform(action)
                }
            )
            // The panel is sized to its screen, never to the SwiftUI content.
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            return panel
        }
        // Activate so the buttons respond to the first click.
        NSApp.activate()
        (panels.first { $0.screen == NSScreen.main } ?? panels.first)?.makeKey()
    }

    private func closePanels() {
        panels.forEach { $0.close() }
        panels = []
    }
}

final class OverlayPanel: NSPanel {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }

    /// Esc must not close the popup.
    override func cancelOperation(_ sender: Any?) {}
}

nonisolated enum SystemSound {
    static var names: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? []
        return files.map { ($0 as NSString).deletingPathExtension }.sorted()
    }

    @MainActor static func play(_ name: String) {
        guard !name.isEmpty else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
