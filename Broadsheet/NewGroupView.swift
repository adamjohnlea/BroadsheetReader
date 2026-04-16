import SwiftUI
import SwiftData

struct NewGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Group").font(.headline)
            TextField("Group name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Create") { save() }
                    .keyboardShortcut(.return)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(FeedGroup(name: trimmed, sortOrder: feedGroups.count))
        dismiss()
    }
}
