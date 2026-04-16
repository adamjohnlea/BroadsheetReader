import SwiftUI
import SwiftData
import OSLog
import UserNotifications
import AppKit

private let log = Logger(subsystem: "com.adamjohnlea.Broadsheet", category: "Storage")

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { granted, error in
            if let error {
                log.warning("Badge authorization error: \(error.localizedDescription, privacy: .public)")
            }
            // Once authorization resolves, apply the last-known count.
            // This handles the race where setBadgeCount is called before auth resolves.
            let count = UserDefaults.standard.integer(forKey: "lastUnreadCount")
            Task { @MainActor in
                try? await UNUserNotificationCenter.current().setBadgeCount(count)
                NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
            }
        }
    }
}

@main
struct BroadsheetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// True when the active ModelContainer is backed by CloudKit sync.
    static private(set) var iCloudSyncActive = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FeedGroup.self, Feed.self, FeedItem.self, Bookmark.self, Highlight.self])

        // Prefer CloudKit-backed store for sync across devices.
        let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            BroadsheetApp.iCloudSyncActive = true
            log.info("✅ iCloud sync active (CloudKit container: iCloud.com.adamjohnlea.Broadsheet)")
            return container
        } catch {
            log.warning("⚠️ CloudKit unavailable — falling back to local storage: \(error.localizedDescription, privacy: .public)")
        }

        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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

        Window("Broadsheet Reader Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 700, height: 500)
    }
}
