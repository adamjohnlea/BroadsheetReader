import SwiftUI
import SwiftData

struct ArticleRow: View {
    let item: FeedItem

    // Newspaper-style dateline: "13 APR 2026" for older, "2:34 PM" for today
    private static let datelineFormatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = false
        return f
    }()

    private static func datelineFormatter(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            datelineFormatter.dateFormat = "h:mm a"
        } else if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
            datelineFormatter.dateFormat = "d MMM"
        } else {
            datelineFormatter.dateFormat = "d MMM yyyy"
        }
        return datelineFormatter.string(from: date)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Unread indicator dot
            Circle()
                .fill(item.isRead ? .clear : .accent)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                // Source + date
                HStack(spacing: 4) {
                    FeedFavicon(urlString: item.feed?.faviconURL)
                    Text(item.feed?.title ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if let date = item.publishedAt {
                        Text(Self.datelineFormatter(for: date))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                    }
                }

                // Title — serif font gives the list an editorial, newspaper feel
                Text(item.title)
                    .font(.system(.subheadline, design: .serif))
                    .fontWeight(item.isRead ? .regular : .semibold)
                    .foregroundStyle(item.isRead ? .secondary : .primary)
                    .lineLimit(2)

                // Summary
                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Bookmark indicator
                if item.bookmark != nil {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.accent)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
