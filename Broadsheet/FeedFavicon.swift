import SwiftUI

struct FeedFavicon: View {
    let urlString: String?

    // Always load over HTTPS — ATS blocks http:// image loads.
    // Existing stored URLs may be http://, so upgrade them here at display time.
    private var secureURL: URL? {
        guard let urlString,
              var components = URLComponents(string: urlString) else { return nil }
        components.scheme = "https"
        return components.url
    }

    var body: some View {
        Group {
            if let url = secureURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFit() }
                    else { fallbackIcon }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: 16, height: 16)
    }

    private var fallbackIcon: some View {
        Image(systemName: "globe").foregroundStyle(.secondary)
    }
}
