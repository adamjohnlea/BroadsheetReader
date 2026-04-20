import SwiftUI
import SwiftData

// MARK: - Collapsible Annotations Section

struct AnnotationsSection: View {
    let bookmark: Bookmark
    @Binding var isExpanded: Bool
    @Binding var noteText: String
    var onDeleteHighlight: ((Highlight) -> Void)?

    private var highlights: [Highlight] {
        (bookmark.highlights ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    private var annotationCount: Int {
        var count = highlights.count
        if let note = bookmark.note, !note.isEmpty { count += 1 }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapse/expand header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)

                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.accent)

                    Text("Annotations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if annotationCount > 0 {
                        Text("\(annotationCount)")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.accent.opacity(0.12), in: Capsule())
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // User note editor
                    NoteEntry(noteText: $noteText, bookmark: bookmark)

                    // Highlights
                    ForEach(highlights) { highlight in
                        HighlightEntry(
                            highlight: highlight,
                            onDelete: { onDeleteHighlight?(highlight) }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Note Entry (user's own note, pencil icon)

private struct NoteEntry: View {
    @Binding var noteText: String
    let bookmark: Bookmark
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "pencil")
                .font(.system(size: 11))
                .foregroundStyle(.accent)
                .frame(width: 16)
                .padding(.top, 4)

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty && !isFocused {
                    Text("Add a note…")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                TextEditor(text: $noteText)
                    .font(.callout)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 32, maxHeight: 100)
                    .onChange(of: noteText) { _, newValue in
                        bookmark.note = newValue.isEmpty ? nil : newValue
                    }
            }
        }
    }
}

// MARK: - Highlight Entry (highlighted passage, highlighter icon)

private struct HighlightEntry: View {
    let highlight: Highlight
    var onDelete: (() -> Void)?
    @State private var highlightNote: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "highlighter")
                .font(.system(size: 11))
                .foregroundStyle(.accent)
                .frame(width: 16)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                // Quoted highlighted text
                Text(highlight.selectedText)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .padding(.leading, 8)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(.accent.opacity(0.5))
                            .frame(width: 2)
                    }

                // Inline note for this highlight
                ZStack(alignment: .topLeading) {
                    if highlightNote.isEmpty {
                        Text("Add a note…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                            .padding(.top, 2)
                    }
                    TextEditor(text: $highlightNote)
                        .font(.caption)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 20, maxHeight: 60)
                        .onChange(of: highlightNote) { _, newValue in
                            highlight.note = newValue.isEmpty ? nil : newValue
                        }
                }
            }
        }
        .onAppear { highlightNote = highlight.note ?? "" }
        .contextMenu {
            Button("Delete Highlight", role: .destructive) { onDelete?() }
        }
    }
}
