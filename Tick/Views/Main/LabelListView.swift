import SwiftData
import SwiftUI

/// Create, rename, recolor and archive projects or tags.
struct LabelListView<Item: ColoredLabel>: View {
    let title: String
    let noun: String

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showArchived = false
    @FocusState private var focusedItem: PersistentIdentifier?

    var body: some View {
        let sorted = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let active = sorted.filter { !$0.isArchived }
        let archived = sorted.filter(\.isArchived)

        List {
            if active.isEmpty {
                Text("No \(noun)s yet. Add one with +.").foregroundStyle(.secondary)
            }
            ForEach(active) { item in
                LabelRow(item: item, focusedItem: $focusedItem)
            }
            if showArchived && !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { item in
                        LabelRow(item: item, focusedItem: $focusedItem)
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            Toggle("Show archived", isOn: $showArchived)
            Button("New \(noun)", systemImage: "plus", action: add)
        }
    }

    private func add() {
        let item = Item(name: "", colorHex: HexColor.fallback)
        modelContext.insert(item)
        focusedItem = item.persistentModelID
    }
}

private struct LabelRow<Item: ColoredLabel>: View {
    @Bindable var item: Item
    var focusedItem: FocusState<PersistentIdentifier?>.Binding

    var body: some View {
        HStack {
            ColorPicker("Color", selection: color, supportsOpacity: false)
                .labelsHidden()
            TextField("Name", text: $item.name)
                .textFieldStyle(.plain)
                .focused(focusedItem, equals: item.persistentModelID)
                .foregroundStyle(item.isArchived ? .secondary : .primary)
            Spacer()
            Button(item.isArchived ? "Unarchive" : "Archive") { item.isArchived.toggle() }
                .buttonStyle(.borderless)
        }
    }

    private var color: Binding<Color> {
        Binding(
            get: { Color(hex: item.colorHex) },
            set: { item.colorHex = $0.hexString }
        )
    }
}
