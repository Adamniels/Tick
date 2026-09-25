import SwiftData
import SwiftUI

extension View {
    /// Asks before deleting the entry in `entry`, then deletes it. Used by Entries and Calendar
    /// (the panel's right-click delete doesn't ask, D17).
    func confirmsDeletion(of entry: Binding<TimeEntry?>) -> some View {
        modifier(DeleteEntryConfirmation(entry: entry))
    }
}

private struct DeleteEntryConfirmation: ViewModifier {
    @Binding var entry: TimeEntry?

    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorReporter.self) private var errors

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(get: { entry != nil }, set: { if !$0 { entry = nil } }),
            presenting: entry
        ) { entry in
            Button("Delete", role: .destructive) {
                errors.run("Deleting the entry") { try TimerService(context: modelContext).delete(entry) }
            }
        } message: { entry in
            Text("\(entry.displayLabel), \(DurationFormat.clock(entry.duration())). This can't be undone.")
        }
    }
}
