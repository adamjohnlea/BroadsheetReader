import SwiftUI
import SwiftData

// MARK: - Starter Feed Definitions

private struct StarterFeed {
    let title: String
    let url: String
    let group: String
}

private let starterFeeds: [StarterFeed] = [
    StarterFeed(title: "Hacker News",        url: "https://news.ycombinator.com/rss",                                          group: "AI / Tech"),
    StarterFeed(title: "Simon Willison",      url: "https://simonwillison.net/atom/everything/",                                group: "AI / Tech"),
    StarterFeed(title: "The Verge AI",        url: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml",         group: "AI / Tech"),
    StarterFeed(title: "MIT Tech Review AI",  url: "https://www.technologyreview.com/feed/",                                    group: "AI / Tech"),
    StarterFeed(title: "ArXiv cs.AI",         url: "https://rss.arxiv.org/rss/cs.AI",                                          group: "Research"),
    StarterFeed(title: "ArXiv cs.LG",         url: "https://rss.arxiv.org/rss/cs.LG",                                          group: "Research"),
    StarterFeed(title: "Interconnects",       url: "https://www.interconnects.ai/feed",                                         group: "Newsletters"),
    StarterFeed(title: "The Batch",           url: "https://www.deeplearning.ai/the-batch/feed/",                               group: "Newsletters"),
    StarterFeed(title: "r/MachineLearning",   url: "https://www.reddit.com/r/MachineLearning.rss",                              group: "Reddit"),
    StarterFeed(title: "r/artificial",        url: "https://www.reddit.com/r/artificial.rss",                                   group: "Reddit"),
]

// MARK: - View

struct StarterFeedsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]
    @AppStorage("hasSeededFeeds") private var hasSeededFeeds = false

    @State private var selected: Set<String> = Set(starterFeeds.map(\.url))
    @State private var isAdding = false
    @State private var addedCount = 0
    @State private var failedCount = 0
    @State private var done = false

    private var groupedFeeds: [(group: String, feeds: [StarterFeed])] {
        let groups = ["AI / Tech", "Research", "Newsletters", "Reddit"]
        return groups.map { g in (group: g, feeds: starterFeeds.filter { $0.group == g }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Broadsheet")
                    .font(.title2).fontWeight(.bold)
                Text("Add some starter feeds to get going, or skip and add your own.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(24)

            Divider()

            if done {
                // Result
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Added \(addedCount) feed\(addedCount == 1 ? "" : "s")")
                        .font(.headline)
                    if failedCount > 0 {
                        Text("\(failedCount) feed\(failedCount == 1 ? "" : "s") couldn't be reached and were skipped.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if isAdding {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Adding feeds…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Feed list
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedFeeds, id: \.group) { section in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.group)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 24)

                                ForEach(section.feeds, id: \.url) { feed in
                                    Toggle(isOn: Binding(
                                        get: { selected.contains(feed.url) },
                                        set: { on in
                                            if on { selected.insert(feed.url) }
                                            else  { selected.remove(feed.url) }
                                        }
                                    )) {
                                        Text(feed.title)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Skip") {
                    hasSeededFeeds = true
                    dismiss()
                }
                .foregroundStyle(.secondary)

                Spacer()

                if done {
                    Button("Get Started") {
                        hasSeededFeeds = true
                        dismiss()
                    }
                    .keyboardShortcut(.return)
                } else {
                    Button("Select All")  { selected = Set(starterFeeds.map(\.url)) }
                    Button("Select None") { selected.removeAll() }

                    Button("Add \(selected.count) Feed\(selected.count == 1 ? "" : "s")") {
                        Task { await addSelected() }
                    }
                    .keyboardShortcut(.return)
                    .disabled(selected.isEmpty || isAdding)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(width: 440, height: 480)
    }

    private func addSelected() async {
        isAdding = true
        var groupCache: [String: FeedGroup] = [:]

        // Pre-create groups in sort order
        let orderedGroups = ["AI / Tech", "Research", "Newsletters", "Reddit"]
        for groupName in orderedGroups {
            if let existing = feedGroups.first(where: { $0.name == groupName }) {
                groupCache[groupName] = existing
            } else {
                let g = FeedGroup(name: groupName, sortOrder: feedGroups.count + groupCache.count)
                modelContext.insert(g)
                groupCache[groupName] = g
            }
        }

        let toAdd = starterFeeds.filter { selected.contains($0.url) }
        for feed in toAdd {
            do {
                _ = try await FeedFetcher.shared.addFeed(
                    urlString: feed.url,
                    group: groupCache[feed.group],
                    context: modelContext
                )
                addedCount += 1
            } catch {
                failedCount += 1
            }
        }

        isAdding = false
        done = true
    }
}
