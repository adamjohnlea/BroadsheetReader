import SwiftUI

struct WalkthroughView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages = WalkthroughPage.allPages

    var body: some View {
        VStack(spacing: 0) {
            // Page content — manual paging without TabView's built-in chrome
            pages[currentPage].view
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

            Divider()

            // Navigation bar
            HStack {
                Button("Skip") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Get Started") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .frame(width: 560, height: 520)
    }
}

// MARK: - Page Data

struct WalkthroughPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let features: [(icon: String, text: String)]
    let symbolEffect: WalkthroughSymbolEffect

    enum WalkthroughSymbolEffect {
        case bounce
        case wiggle
        case breathe
        case rotate
        case pulse
    }

    var view: some View {
        WalkthroughPageView(page: self)
    }

    static let allPages: [WalkthroughPage] = [
        WalkthroughPage(
            icon: "newspaper.fill",
            iconColor: .accentColor,
            title: "Welcome to Broadsheet Reader",
            subtitle: "A clean, focused RSS reader for AI and tech news.",
            features: [
                (icon: "text.justify.leading", text: "Read articles in a beautiful three-column layout"),
                (icon: "icloud", text: "Sync your feeds across devices with iCloud"),
                (icon: "keyboard", text: "Full keyboard navigation support"),
            ],
            symbolEffect: .breathe
        ),
        WalkthroughPage(
            icon: "plus.rectangle.on.folder.fill",
            iconColor: .accentColor,
            title: "Organize Your Feeds",
            subtitle: "Add feeds, create groups, and import from other readers.",
            features: [
                (icon: "link", text: "Add feeds by URL with automatic discovery"),
                (icon: "folder", text: "Organize feeds into collapsible groups"),
                (icon: "arrow.up.arrow.down", text: "Drag and drop to reorder"),
                (icon: "doc.text", text: "Import and export feeds via OPML"),
            ],
            symbolEffect: .wiggle
        ),
        WalkthroughPage(
            icon: "doc.richtext",
            iconColor: .accentColor,
            title: "Read Your Way",
            subtitle: "Stay on top of what matters with smart filtering.",
            features: [
                (icon: "circle.fill", text: "Green dots mark unread articles at a glance"),
                (icon: "line.3.horizontal.decrease", text: "Filter between All and Unread articles"),
                (icon: "clock", text: "Automatic background refresh keeps feeds current"),
                (icon: "arrow.up.arrow.down", text: "Navigate articles with Cmd+↑ and Cmd+↓"),
            ],
            symbolEffect: .bounce
        ),
        WalkthroughPage(
            icon: "bookmark.fill",
            iconColor: .accentColor,
            title: "Bookmark & Annotate",
            subtitle: "Save articles and add your own notes.",
            features: [
                (icon: "bookmark", text: "Bookmark articles to save them for later"),
                (icon: "note.text", text: "Add personal notes to any bookmark"),
                (icon: "shield", text: "Bookmarked articles are never auto-deleted"),
            ],
            symbolEffect: .pulse
        ),
        WalkthroughPage(
            icon: "magnifyingglass",
            iconColor: .accentColor,
            title: "Find Anything",
            subtitle: "Search across all your articles instantly.",
            features: [
                (icon: "text.magnifyingglass", text: "Full-text search across titles, content, and feeds"),
                (icon: "square.and.arrow.up", text: "Share articles via AirDrop, Messages, Mail, and more"),
                (icon: "gearshape", text: "Customize refresh intervals, retention, and reading behavior"),
            ],
            symbolEffect: .rotate
        ),
    ]
}

// MARK: - Page View

private struct WalkthroughPageView: View {
    let page: WalkthroughPage
    @State private var animateSymbol = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Hero icon
            Image(systemName: page.icon)
                .font(.system(size: 56))
                .foregroundStyle(page.iconColor)
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2.0)), value: animateSymbol)
                .frame(height: 72)

            // Title + subtitle
            Text(page.title)
                .font(.system(.title2, design: .serif))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            // Feature list
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(page.features.enumerated()), id: \.offset) { _, feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.body)
                            .foregroundStyle(.accent)
                            .frame(width: 24)
                        Text(feature.text)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: 380, alignment: .leading)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
        .onAppear { animateSymbol = true }
    }
}

// MARK: - Preview

#Preview {
    WalkthroughView()
}
