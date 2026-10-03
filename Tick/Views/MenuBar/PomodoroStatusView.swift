import SwiftUI

/// The active pomodoro phase in the panel, with time left and its actions.
struct PomodoroStatusView: View {
    let session: PomodoroSession
    let onStartBreak: () -> Void
    let onStartNextBlock: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = session.plannedEnd.timeIntervalSince(context.date)
                Text("\(session.phaseValue == .work ? "🍅" : "☕") \(session.phaseValue.title) · \(DurationFormat.countdown(remaining)) left")
                    .monospacedDigit()
            }
            Spacer()
            if session.phaseValue.isBreak {
                Button("Start next block", action: onStartNextBlock)
            } else {
                Button("Start break", action: onStartBreak)
            }
            Button("End pomodoro", action: onEnd)
        }
        .font(.callout)
        .buttonStyle(.borderless)
    }
}
