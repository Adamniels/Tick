import SwiftUI

/// One entry on the timeline: tinted in its project color, like Toggl. The text adapts to the
/// block's height: two lines, one line, or none (the tooltip always has the details).
struct CalendarBlock: View {
    let entry: TimeEntry
    let start: Date
    let end: Date
    let now: Date
    let height: CGFloat
    let isDragging: Bool

    private static let twoLineHeight: CGFloat = 32
    private static let oneLineHeight: CGFloat = 15

    var body: some View {
        let color = Color(hex: entry.project?.colorHex ?? HexColor.fallback)
        let shape = RoundedRectangle(cornerRadius: height < 8 ? 2 : 5)

        HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 3)
            content(color: color)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, height >= Self.twoLineHeight ? 3 : 0)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: height >= Self.twoLineHeight ? .top : .center)
        .background(color.opacity(entry.isRunning ? 0.14 : 0.26), in: shape)
        .overlay {
            if entry.isRunning {
                shape.strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(isDragging ? 0.25 : 0), radius: 6, y: 2)
    }

    @ViewBuilder
    private func content(color: Color) -> some View {
        if height >= Self.twoLineHeight {
            VStack(alignment: .leading, spacing: 1) {
                titleLine(color: color)
                durationText
            }
        } else if height >= Self.oneLineHeight {
            HStack(spacing: 6) {
                titleLine(color: color)
                durationText
            }
        }
    }

    private func titleLine(color: Color) -> some View {
        HStack(spacing: 6) {
            Text(entry.entryDescription.isEmpty ? "No description" : entry.entryDescription)
                .fontWeight(.semibold)
                .foregroundStyle(entry.entryDescription.isEmpty ? .secondary : .primary)
            if let project = entry.project {
                Text(project.name).foregroundStyle(color)
            }
        }
        .lineLimit(1)
    }

    private var durationText: some View {
        Text(isDragging ? timeRange : DurationFormat.clock(entry.isRunning ? entry.duration(at: now) : end.timeIntervalSince(start)))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var timeRange: String {
        "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }
}
