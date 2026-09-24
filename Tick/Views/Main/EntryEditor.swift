import SwiftData
import SwiftUI

/// Edit an entry, or create a manual one when `entry` is nil. Works on a draft (D28).
struct EntryEditor: View {
    let entry: TimeEntry?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EntryDraft
    @State private var saveError: String?

    init(entry: TimeEntry?) {
        self.entry = entry
        _draft = State(initialValue: entry.map(EntryDraft.init(entry:)) ?? .newManual(now: .now))
    }

    var body: some View {
        let validationError = draft.validationError(now: .now)

        VStack(alignment: .leading, spacing: 0) {
            Form {
                TextField("Description", text: $draft.description, prompt: Text("What did you work on?"))
                ProjectPicker(selection: $draft.project, alwaysInclude: entry?.project)
                LabeledContent("Tags") {
                    TagSelector(selection: $draft.tags)
                }
                DatePicker("Start", selection: $draft.start)
                if let end = draft.end {
                    DatePicker("End", selection: Binding(get: { end }, set: { draft.end = $0 }))
                    LabeledContent("Duration", value: DurationFormat.clock(end.timeIntervalSince(draft.start)))
                } else {
                    LabeledContent("End", value: "Running. Stop it from the menu bar.")
                }
            }
            .formStyle(.grouped)

            HStack {
                if let message = saveError ?? validationError {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(entry == nil ? "Add" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(validationError != nil)
            }
            .padding()
        }
        .frame(width: 460)
    }

    private func save() {
        do {
            try TimerService(context: modelContext).save(draft, to: entry)
            dismiss()
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
