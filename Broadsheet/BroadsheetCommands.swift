import SwiftUI

// MARK: - FocusedValues keys

private struct RefreshActionKey: FocusedValueKey {
    typealias Value = () async -> Void
}
private struct AddFeedActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct NewGroupActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct NavigateActionKey: FocusedValueKey {
    typealias Value = (SidebarItem) -> Void
}
private struct ImportOPMLActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct ExportOPMLActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct NextArticleActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct PreviousArticleActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct ShowWalkthroughActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
private struct ShowHelpActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var refreshAction: (() async -> Void)? {
        get { self[RefreshActionKey.self] }
        set { self[RefreshActionKey.self] = newValue }
    }
    var addFeedAction: (() -> Void)? {
        get { self[AddFeedActionKey.self] }
        set { self[AddFeedActionKey.self] = newValue }
    }
    var newGroupAction: (() -> Void)? {
        get { self[NewGroupActionKey.self] }
        set { self[NewGroupActionKey.self] = newValue }
    }
    var navigateAction: ((SidebarItem) -> Void)? {
        get { self[NavigateActionKey.self] }
        set { self[NavigateActionKey.self] = newValue }
    }
    var importOPMLAction: (() -> Void)? {
        get { self[ImportOPMLActionKey.self] }
        set { self[ImportOPMLActionKey.self] = newValue }
    }
    var exportOPMLAction: (() -> Void)? {
        get { self[ExportOPMLActionKey.self] }
        set { self[ExportOPMLActionKey.self] = newValue }
    }
    var nextArticleAction: (() -> Void)? {
        get { self[NextArticleActionKey.self] }
        set { self[NextArticleActionKey.self] = newValue }
    }
    var previousArticleAction: (() -> Void)? {
        get { self[PreviousArticleActionKey.self] }
        set { self[PreviousArticleActionKey.self] = newValue }
    }
    var showWalkthroughAction: (() -> Void)? {
        get { self[ShowWalkthroughActionKey.self] }
        set { self[ShowWalkthroughActionKey.self] = newValue }
    }
    var showHelpAction: (() -> Void)? {
        get { self[ShowHelpActionKey.self] }
        set { self[ShowHelpActionKey.self] = newValue }
    }
}

// MARK: - Commands

struct BroadsheetCommands: Commands {
    @FocusedValue(\.refreshAction)    var refreshAction
    @FocusedValue(\.addFeedAction)    var addFeedAction
    @FocusedValue(\.newGroupAction)   var newGroupAction
    @FocusedValue(\.navigateAction)   var navigate
    @FocusedValue(\.importOPMLAction)    var importOPML
    @FocusedValue(\.exportOPMLAction)    var exportOPML
    @FocusedValue(\.nextArticleAction)      var nextArticle
    @FocusedValue(\.previousArticleAction) var previousArticle
    @FocusedValue(\.showWalkthroughAction) var showWalkthrough
    @FocusedValue(\.showHelpAction)        var showHelp

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Feed…") { addFeedAction?() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("New Group…") { newGroupAction?() }
        }

        CommandGroup(after: .importExport) {
            Divider()
            Button("Import Feeds from OPML…") { importOPML?() }
            Button("Export Feeds as OPML…")   { exportOPML?() }
        }

        CommandMenu("Feeds") {
            Button("Refresh All Feeds") { Task { await refreshAction?() } }
                .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Go to Today")     { navigate?(.today) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Go to All Items") { navigate?(.allItems) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Go to Bookmarks") { navigate?(.bookmarks) }
                .keyboardShortcut("3", modifiers: .command)
            Button("Search")          { navigate?(.search) }
                .keyboardShortcut("f", modifiers: .command)

            Divider()

            Button("Next Article")     { nextArticle?() }
                .keyboardShortcut(.downArrow, modifiers: .command)
            Button("Previous Article") { previousArticle?() }
                .keyboardShortcut(.upArrow, modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Broadsheet Reader Help") { showHelp?() }
                .keyboardShortcut("?", modifiers: .command)
            Divider()
            Button("Welcome to Broadsheet Reader") { showWalkthrough?() }
        }
    }
}
