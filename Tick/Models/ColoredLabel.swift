import SwiftData

/// The shape shared by `Project` and `Tag`, so the management UI can treat them alike.
nonisolated protocol ColoredLabel: PersistentModel {
    var name: String { get set }
    var colorHex: String { get set }
    var isArchived: Bool { get set }

    init(name: String, colorHex: String)
}
