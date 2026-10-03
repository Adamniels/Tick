import SwiftUI

/// The active pomodoro phase, with time left and its actions (panel and main window).
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
