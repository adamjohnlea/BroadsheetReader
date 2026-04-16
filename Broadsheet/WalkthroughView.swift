import SwiftUI

struct WalkthroughView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages = WalkthroughPage.allPages

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            pages[currentPage].view
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .id(currentPage)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

            Divider()

            // Navigation bar
            HStack {
                Button("Skip") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                // Tappable page indicator dots
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: index == currentPage ? 10 : 8,
                                   height: index == currentPage ? 10 : 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                            .onTapGesture {
                                withAnimation { currentPage = index }
                            }
                            .accessibilityLabel("Page \(index + 1)")
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
        .frame(width: 580, height: 500)
    }
}

// MARK: - Page Data

struct WalkthroughPage {
    let icon: String
    let title: String
    let subtitle: String
    let features: [(icon: String, label: String, detail: String)]

    var view: some View {
        WalkthroughPageView(page: self)
    }

    static let allPages: [WalkthroughPage] = [
        // Page 1: Welcome
        WalkthroughPage(
            icon: "newspaper.fill",
            title: "Welcome to Broadsheet Reader",
            subtitle: "A clean, focused RSS reader for macOS.\nSubscribe to your favorite sites and read on your terms.",
            features: [
                (icon: "text.justify.leading", label: "Three-column layout", detail: "Sidebar, article list, and detail — just like a newspaper"),
                (icon: "icloud.fill", label: "iCloud sync", detail: "Your feeds, bookmarks, and read state sync across all your Macs"),
                (icon: "keyboard.fill", label: "Keyboard first", detail: "Navigate everything with shortcuts — Cmd+1-4, arrows, and more"),
            ]
        ),
        // Page 2: Reading & Annotations
        WalkthroughPage(
            icon: "highlighter",
            title: "Read, Highlight, Annotate",
            subtitle: "Broadsheet Reader is more than a feed reader —\nit's a tool for thinking.",
            features: [
                (icon: "highlighter", label: "Highlight passages", detail: "Select text in any article to save it as a highlight"),
                (icon: "bookmark.fill", label: "Bookmarks with notes", detail: "Save articles and add your own annotations"),
                (icon: "magnifyingglass", label: "Search everything", detail: "Find articles by title, content, feed name, or highlight text"),
            ]
        ),
        // Page 3: Get Going
        WalkthroughPage(
            icon: "arrow.right.circle.fill",
            title: "Get Going",
            subtitle: "You're ready to start reading.\nHere's how to make it yours.",
            features: [
                (icon: "plus.circle.fill", label: "Add feeds", detail: "Paste any website URL — the feed is discovered automatically"),
                (icon: "doc.text.fill", label: "Import from another reader", detail: "File → Import Feeds from OPML to bring your subscriptions"),
                (icon: "square.and.arrow.up.fill", label: "Share what you find", detail: "Share articles via AirDrop, Messages, Mail, and more"),
            ]
        ),
    ]
}

// MARK: - Page View

private struct WalkthroughPageView: View {
    let page: WalkthroughPage
    @State private var animateSymbol = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero icon with gradient backdrop
            ZStack {
                // Gradient glow behind icon
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: page.icon)
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(.accent)
                    .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 3.0)), value: animateSymbol)
            }
            .padding(.bottom, 20)

            // Title
            Text(page.title)
                .font(.system(.title, design: .serif))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            // Subtitle
            Text(page.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 420)
                .padding(.bottom, 28)

            // Feature list with bold lead-ins
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(page.features.enumerated()), id: \.offset) { index, feature in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(.accent)
                            .frame(width: 28)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.label)
                                .font(.callout)
                                .fontWeight(.semibold)
                            Text(feature.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1 + 0.15), value: appeared)
                }
            }
            .frame(maxWidth: 400, alignment: .leading)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 48)
        .onAppear {
            animateSymbol = true
            appeared = true
        }
        .onDisappear {
            appeared = false
        }
    }
}

// MARK: - Preview

#Preview {
    WalkthroughView()
}
