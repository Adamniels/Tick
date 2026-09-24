import Foundation
import SwiftData

@Model nonisolated final class Project: ColoredLabel {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = HexColor.fallback
    var isArchived: Bool = false
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.project)
    var entries: [TimeEntry]? = []

    init(name: String, colorHex: String = HexColor.fallback) {
        self.name = name
        self.colorHex = colorHex
    }
}
