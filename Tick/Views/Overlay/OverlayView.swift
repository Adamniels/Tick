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
            if let input = request.dateInput {
                DateInputField(input: input)
            }
            // More than three choices stack vertically so every label stays readable.
            Group {
                if request.actions.count > 3 {
                    VStack(spacing: 10) {
                        ForEach(request.actions) { button(for: $0, fullWidth: true) }
                    }
                } else {
                    HStack(spacing: 12) {
                        ForEach(request.actions) { button(for: $0, fullWidth: false) }
                    }
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
    private func button(for action: OverlayAction, fullWidth: Bool) -> some View {
        let label = Text(action.title).frame(minWidth: 130, maxWidth: fullWidth ? .infinity : nil)
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

private struct DateInputField: View {
    @Bindable var input: OverlayDateInput

    var body: some View {
        // Include the date only when the range spans more than one day.
        let spansDays = !Calendar.current.isDate(input.range.lowerBound, inSameDayAs: input.range.upperBound)
        DatePicker(
            input.label,
            selection: $input.date,
            in: input.range,
            displayedComponents: spansDays ? [.date, .hourAndMinute] : [.hourAndMinute]
        )
        .font(.title3)
        .fixedSize()
    }
}
