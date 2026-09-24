import Foundation
import SwiftData

@Model nonisolated final class Tag: ColoredLabel {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = HexColor.fallback
    var isArchived: Bool = false
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.tags)
    var entries: [TimeEntry]? = []

    init(name: String, colorHex: String = HexColor.fallback) {
        self.name = name
        self.colorHex = colorHex
    }
}
