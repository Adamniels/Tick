import Foundation

nonisolated enum DurationFormat {
    /// "0:42:13": unpadded hours, padded minutes and seconds. Negative values clamp to zero.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }
}
