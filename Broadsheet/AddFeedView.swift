import SwiftUI
import SwiftData

struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]
    @State private var urlText = ""
    @State private var selectedGroup: FeedGroup?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Feed").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Feed or website URL").font(.subheadline).foregroundStyle(.secondary)
                TextField("https://example.com/feed", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                    .onSubmit { Task { await submit() } }
            }

            if !feedGroups.isEmpty {
                Picker("Group", selection: $selectedGroup) {
                    Text("No Group").tag(Optional<FeedGroup>(nil))
                    ForEach(feedGroups) { group in
                        Text(group.name).tag(Optional(group))
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.escape).disabled(isLoading)
                Spacer()
                if isLoading { ProgressView().controlSize(.small).padding(.trailing, 4) }
                Button("Add Feed") { Task { await submit() } }
                    .keyboardShortcut(.return)
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func submit() async {
        var raw = urlText.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        if !raw.lowercased().hasPrefix("http") { raw = "https://\(raw)" }

        isLoading = true
        errorMessage = nil
        do {
            _ = try await FeedFetcher.shared.addFeed(urlString: raw, group: selectedGroup, context: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
