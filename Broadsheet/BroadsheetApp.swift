import SwiftUI
import SwiftData

@main
struct BroadsheetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FeedGroup.self, Feed.self, FeedItem.self, Bookmark.self])
        let storeURL = URL.applicationSupportDirectory.appending(path: "Broadsheet.store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema changed — wipe all store files (main + WAL) and start fresh.
            let fm = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            BroadsheetCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
