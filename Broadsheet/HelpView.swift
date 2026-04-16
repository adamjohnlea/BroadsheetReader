import SwiftUI
import WebKit

// MARK: - Help Window

struct HelpView: View {
    @State private var selectedTopic: HelpTopic? = nil

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.allTopics, selection: $selectedTopic) { topic in
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.system(.body, design: .serif))
                        .fontWeight(.medium)
                    Text(topic.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .tag(topic)
            }
            .listStyle(.sidebar)
            .navigationTitle("Help")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            if let topic = selectedTopic {
                HelpContentView(topic: topic)
            } else {
                HelpLandingView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Landing Page

private struct HelpLandingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper.fill")
                .font(.system(size: 48))
                .foregroundStyle(.accent)
            Text("Broadsheet Reader Help")
                .font(.system(.title2, design: .serif))
                .fontWeight(.bold)
            Text("Select a topic from the sidebar to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Help Content Renderer

private struct HelpContentView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text(topic.title)
                    .font(.system(.title, design: .serif))
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                Text(topic.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)

                // Sections
                ForEach(topic.sections) { section in
                    HelpSectionView(section: section)
                }
            }
            .padding(32)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HelpSectionView: View {
    let section: HelpSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let heading = section.heading {
                Text(heading)
                    .font(.system(.headline, design: .serif))
                    .padding(.top, 16)
                    .padding(.bottom, 2)
            }

            ForEach(section.blocks) { block in
                switch block.kind {
                case .paragraph:
                    Text(LocalizedStringKey(block.text))
                        .font(.callout)
                        .lineSpacing(3)
                        .padding(.bottom, 4)
                case .bullet:
                    HStack(alignment: .top, spacing: 8) {
                        Text("\u{2022}")
                            .foregroundStyle(.accent)
                            .fontWeight(.bold)
                        Text(LocalizedStringKey(block.text))
                            .font(.callout)
                            .lineSpacing(3)
                    }
                    .padding(.leading, 4)
                case .tip:
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.accent)
                            .font(.callout)
                            .padding(.top, 2)
                        Text(LocalizedStringKey(block.text))
                            .font(.callout)
                            .lineSpacing(3)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.vertical, 4)
                case .shortcut:
                    HStack {
                        Text(block.text.components(separatedBy: " — ").first ?? "")
                            .font(.callout.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(block.text.components(separatedBy: " — ").last ?? "")
                            .font(.callout)
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }
}

