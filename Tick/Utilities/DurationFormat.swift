import Foundation

nonisolated enum DurationFormat {
    /// "0:42:13": unpadded hours, padded minutes and seconds. Negative values clamp to zero.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }

    /// "18:42" counting down, "1:02:03" from an hour up. Rounds up, so a fresh 25-minute
    /// block shows 25:00 and 0:00 appears only when time is up.
    static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        guard total < 3600 else { return clock(TimeInterval(total)) }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
