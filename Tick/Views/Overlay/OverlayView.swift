import SwiftUI

/// The popup's content on one screen: a dimmed backdrop with a centered card.
struct OverlayView: View {
    let request: OverlayRequest
    let appearance: OverlayAppearance
    let onAction: (OverlayAction) -> Void

    /// Buttons ignore input briefly after appearing, so a click or keypress aimed at another
    /// app can't answer the popup by accident. For the same reason there is no Return shortcut (D19).
    @State private var isArmed = false
    private static let armingDelay: Duration = .milliseconds(600)

    var body: some View {
        ZStack {
            Color.black.opacity(appearance.dimOpacity)
            card.scaleEffect(appearance.cardSize.scale)
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: Self.armingDelay)
            isArmed = true
        }
    }

    private var card: some View {
        VStack(spacing: 18) {
            Image(systemName: request.symbol)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(request.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            if !request.message.isEmpty {
                Text(request.message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                ForEach(request.actions) { action in
                    button(for: action)
                }
            }
            .padding(.top, 8)
            .disabled(!isArmed)
        }
        .padding(36)
        .frame(width: 560)
        .background(.regularMaterial, in: .rect(cornerRadius: 28))
        .shadow(radius: 30)
    }

    @ViewBuilder
    private func button(for action: OverlayAction) -> some View {
        let label = Text(action.title).frame(minWidth: 130)
        switch action.role {
        case .primary:
            Button { onAction(action) } label: { label }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
        case .normal:
            Button { onAction(action) } label: { label }
                .buttonStyle(.bordered)
                .controlSize(.extraLarge)
        case .destructive:
            Button(role: .destructive) { onAction(action) } label: { label }
                .buttonStyle(.bordered)
                .controlSize(.extraLarge)
        }
    }
}
