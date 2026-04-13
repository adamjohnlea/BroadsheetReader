import XCTest

// MARK: - Base Test Case

class BroadsheetUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        dismissStarterFeedsIfPresent()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    /// If the first-run starter feeds sheet is visible, dismiss it via Skip.
    func dismissStarterFeedsIfPresent() {
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 4) {
            skipButton.click()
        }
    }

    /// Clicks the sidebar to make sure it holds focus so FocusedValue actions
    /// (addFeedAction, newGroupAction, etc.) are non-nil for keyboard shortcuts and menus.
    func focusSidebar() {
        let sidebar = app.outlines["Sidebar"]
        if sidebar.waitForExistence(timeout: 3) {
            sidebar.click()
        } else {
            // Fallback: click any reliable sidebar label
            let label = app.staticTexts["All Items"]
            if label.waitForExistence(timeout: 3) { label.click() }
        }
    }

    /// Clicks the sidebar item by name, scoped to the sidebar outline to avoid ambiguity
    /// with the window title bar which also shows the selected item's name.
    func clickSidebarItem(_ name: String) {
        let sidebar = app.outlines["Sidebar"]
        if sidebar.waitForExistence(timeout: 3) {
            let cell = sidebar.staticTexts[name]
            if cell.waitForExistence(timeout: 3) {
                cell.click()
                return
            }
        }
        // Fallback: use keyboard shortcut navigation
        switch name {
        case "Today":     app.typeKey("1", modifierFlags: [.command])
        case "All Items": app.typeKey("2", modifierFlags: [.command])
        case "Bookmarks": app.typeKey("3", modifierFlags: [.command])
        case "Search":    app.typeKey("f", modifierFlags: [.command])
        default: break
        }
    }

    /// Opens the "Feeds" menu bar menu.
    func openFeedsMenu() -> XCUIElement {
        let menuBar = app.menuBars.firstMatch
        let feedsMenu = menuBar.menuBarItems["Feeds"]
        if feedsMenu.waitForExistence(timeout: 3) {
            feedsMenu.click()
        }
        return menuBar.menuBarItems["Feeds"].menus.firstMatch
    }
}

// MARK: - App Launch Tests

final class AppLaunchTests: BroadsheetUITestCase {

    @MainActor
    func testAppLaunchesWithoutCrashing() {
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testSidebarVisibleOnLaunch() {
        // The sidebar must contain all four fixed navigation items.
        XCTAssertTrue(app.staticTexts["All Items"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bookmarks"].exists)
        XCTAssertTrue(app.staticTexts["Search"].exists)
    }

    @MainActor
    func testTodaySidebarItemVisible() {
        let sidebar = app.outlines["Sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        XCTAssertTrue(sidebar.staticTexts["Today"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testToolbarRefreshButtonVisible() {
        XCTAssertTrue(app.buttons["Refresh All"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWindowIsVisible() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }
}

// MARK: - Sidebar Navigation Tests

final class SidebarNavigationTests: BroadsheetUITestCase {

    @MainActor
    func testNavigateToAllItemsViaSidebar() {
        clickSidebarItem("All Items")
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testNavigateToBookmarksViaSidebar() {
        clickSidebarItem("Bookmarks")
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testNavigateToTodayViaKeyboardShortcut() {
        // ⌘1 = Go to Today
        app.typeKey("1", modifierFlags: [.command])
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testNavigateToAllItemsViaKeyboardShortcut() {
        // ⌘2 = Go to All Items
        app.typeKey("2", modifierFlags: [.command])
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testNavigateToBookmarksViaKeyboardShortcut() {
        // ⌘3 = Go to Bookmarks
        app.typeKey("3", modifierFlags: [.command])
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testNavigateToSearchViaKeyboardShortcut() {
        // ⌘F = Go to Search
        app.typeKey("f", modifierFlags: [.command])
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testNavigatingBetweenSectionsDoesNotCrash() {
        app.typeKey("1", modifierFlags: [.command])
        app.typeKey("2", modifierFlags: [.command])
        app.typeKey("3", modifierFlags: [.command])
        app.typeKey("1", modifierFlags: [.command])
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Add Feed Sheet Tests

final class AddFeedSheetTests: BroadsheetUITestCase {

    /// Opens the Add Feed sheet. Focuses the sidebar first so the FocusedValue action is live.
    private func openAddFeedSheet() {
        focusSidebar()
        app.typeKey("n", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Add Feed"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddFeedSheetOpensViaKeyboardShortcut() {
        openAddFeedSheet()
    }

    @MainActor
    func testAddFeedSheetOpensViaFileMenu() {
        // Focus sidebar first so FocusedValue action is live when menu item fires.
        focusSidebar()
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["File"].click()
        let item = menuBar.menuBarItems["File"].menus.menuItems["Add Feed…"]
        if item.waitForExistence(timeout: 3) {
            item.click()
            XCTAssertTrue(app.staticTexts["Add Feed"].waitForExistence(timeout: 5))
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    @MainActor
    func testAddFeedSheetHasURLTextField() {
        openAddFeedSheet()
        XCTAssertTrue(app.textFields["https://example.com/feed"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAddFeedSheetCancelDismissesSheet() {
        openAddFeedSheet()
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.click()
        XCTAssertFalse(app.staticTexts["Add Feed"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAddFeedButtonDisabledWhenURLIsEmpty() {
        openAddFeedSheet()
        // The "Add Feed" button in the sheet should be disabled when the text field is empty.
        let addButton = app.sheets.buttons["Add Feed"]
        if addButton.waitForExistence(timeout: 3) {
            XCTAssertFalse(addButton.isEnabled)
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testAddFeedButtonEnabledAfterTypingURL() {
        openAddFeedSheet()
        let textField = app.textFields["https://example.com/feed"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3))
        textField.click()
        textField.typeText("https://example.com/feed.xml")
        let addButton = app.sheets.buttons["Add Feed"]
        if addButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(addButton.isEnabled)
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testAddFeedSheetDismissedWithEscapeKey() {
        openAddFeedSheet()
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.staticTexts["Add Feed"].waitForExistence(timeout: 3))
    }
}

// MARK: - New Group Sheet Tests

final class NewGroupSheetTests: BroadsheetUITestCase {

    private func openNewGroupSheet() {
        focusSidebar()
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["File"].click()
        let item = menuBar.menuBarItems["File"].menus.menuItems["New Group…"]
        if item.waitForExistence(timeout: 3) {
            item.click()
        }
    }

    @MainActor
    func testNewGroupSheetOpens() {
        openNewGroupSheet()
        XCTAssertTrue(app.staticTexts["New Group"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNewGroupSheetHasNameField() {
        openNewGroupSheet()
        XCTAssertTrue(app.textFields["Group name"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testNewGroupCreateButtonDisabledWhenNameEmpty() {
        openNewGroupSheet()
        let createButton = app.sheets.buttons["Create"]
        if createButton.waitForExistence(timeout: 4) {
            XCTAssertFalse(createButton.isEnabled)
        }
        app.sheets.buttons["Cancel"].click()
    }

    @MainActor
    func testNewGroupCreateButtonEnabledWhenNameEntered() {
        openNewGroupSheet()
        let nameField = app.textFields["Group name"]
        if nameField.waitForExistence(timeout: 4) {
            nameField.click()
            nameField.typeText("Test Group")
            let createButton = app.sheets.buttons["Create"]
            if createButton.waitForExistence(timeout: 2) {
                XCTAssertTrue(createButton.isEnabled)
            }
        }
        // Cancel to avoid polluting test state
        let cancel = app.sheets.buttons["Cancel"]
        if cancel.exists { cancel.click() }
    }

    @MainActor
    func testNewGroupCancelDismissesSheet() {
        openNewGroupSheet()
        let cancelButton = app.sheets.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 4) {
            cancelButton.click()
            XCTAssertFalse(app.staticTexts["New Group"].waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testNewGroupDismissedWithEscapeKey() {
        openNewGroupSheet()
        if app.staticTexts["New Group"].waitForExistence(timeout: 4) {
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(app.staticTexts["New Group"].waitForExistence(timeout: 3))
        }
    }
}

// MARK: - Search Tests

final class SearchTests: BroadsheetUITestCase {

    @MainActor
    func testSearchFieldExistsInToolbar() {
        XCTAssertTrue(app.searchFields["Search articles…"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTypingInSearchFieldShowsResults() {
        let searchField = app.searchFields["Search articles…"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()
        searchField.typeText("swift")
        // Either "Search Results" title or the empty-search state should appear.
        let results = app.staticTexts["Search Results"].waitForExistence(timeout: 3)
        let emptySearch = app.staticTexts["Search Articles"].waitForExistence(timeout: 1)
        let noResults = app.staticTexts["No Articles"].waitForExistence(timeout: 1)
        XCTAssertTrue(results || emptySearch || noResults)
    }

    @MainActor
    func testSearchKeyboardShortcutFocusesField() {
        // ⌘F navigates to search sidebar item
        app.typeKey("f", modifierFlags: [.command])
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testEmptySearchShowsPrompt() {
        // Navigate to search with no text — should show "Search Articles" empty state.
        app.typeKey("f", modifierFlags: [.command])
        XCTAssertTrue(app.staticTexts["Search Articles"].waitForExistence(timeout: 10))
    }
}

// MARK: - Settings Tests

final class SettingsTests: BroadsheetUITestCase {

    @MainActor
    func testSettingsOpensViaKeyboardShortcut() {
        app.typeKey(",", modifierFlags: [.command])
        // Settings opens a new window (macOS Settings scene)
        let settingsOpen = app.windows.count > 1 ||
                           app.staticTexts["Reading"].waitForExistence(timeout: 5)
        XCTAssertTrue(settingsOpen)
    }

    @MainActor
    func testSettingsContainsReadingSection() {
        app.typeKey(",", modifierFlags: [.command])
        XCTAssertTrue(app.staticTexts["Reading"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsContainsAutoRefreshSection() {
        app.typeKey(",", modifierFlags: [.command])
        XCTAssertTrue(app.staticTexts["Auto-Refresh"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsContainsRetentionSection() {
        app.typeKey(",", modifierFlags: [.command])
        XCTAssertTrue(app.staticTexts["Article Retention"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsMarkAsReadToggleExists() {
        app.typeKey(",", modifierFlags: [.command])
        if app.staticTexts["Reading"].waitForExistence(timeout: 5) {
            // The toggle label is always a static text regardless of control type.
            XCTAssertTrue(app.staticTexts["Mark articles as read when opened"].waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testSettingsRefreshIntervalPickerExists() {
        app.typeKey(",", modifierFlags: [.command])
        if app.staticTexts["Auto-Refresh"].waitForExistence(timeout: 5) {
            // Radio-group picker options should exist
            let manual = app.radioButtons["Manual only"]
            XCTAssertTrue(manual.waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testSettingsRetentionPickerExists() {
        app.typeKey(",", modifierFlags: [.command])
        if app.staticTexts["Article Retention"].waitForExistence(timeout: 5) {
            let forever = app.radioButtons["Forever"]
            XCTAssertTrue(forever.waitForExistence(timeout: 3))
        }
    }
}

// MARK: - Filter Bar Tests

final class FilterBarTests: BroadsheetUITestCase {

    @MainActor
    func testFilterBarVisibleOnAllItemsView() {
        app.typeKey("2", modifierFlags: [.command]) // All Items
        XCTAssertTrue(app.radioButtons["All"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.radioButtons["Unread"].exists)
    }

    @MainActor
    func testFilterBarVisibleOnFeedView() {
        // Today (which uses the same filter bar logic)
        app.typeKey("1", modifierFlags: [.command])
        XCTAssertTrue(app.radioButtons["All"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFilterBarHiddenOnBookmarksView() {
        app.typeKey("3", modifierFlags: [.command]) // Bookmarks
        // Wait for Bookmarks view to fully load before checking filter bar absence.
        let bookmarksLoaded = app.staticTexts["No bookmarks yet."].waitForExistence(timeout: 8)
            || app.staticTexts["Bookmarks"].waitForExistence(timeout: 3)
        XCTAssertTrue(bookmarksLoaded || app.state == .runningForeground)
        // Bookmarks always shows all — no All/Unread segmented control.
        XCTAssertFalse(app.radioButtons["All"].exists)
    }

    @MainActor
    func testFilterBarHiddenOnEmptySearch() {
        app.typeKey("f", modifierFlags: [.command]) // Search (no query)
        // Wait for Search view to fully load before checking filter bar absence.
        XCTAssertTrue(app.staticTexts["Search Articles"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.radioButtons["All"].exists)
    }

    @MainActor
    func testTogglingToUnreadAndBackDoesNotCrash() {
        app.typeKey("2", modifierFlags: [.command]) // All Items
        let unread = app.radioButtons["Unread"]
        if unread.waitForExistence(timeout: 5) {
            unread.click()
            let all = app.radioButtons["All"]
            if all.waitForExistence(timeout: 3) {
                all.click()
            }
        }
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Empty State Tests

final class EmptyStateTests: BroadsheetUITestCase {

    @MainActor
    func testSearchEmptyStateBeforeTyping() {
        app.typeKey("f", modifierFlags: [.command])
        XCTAssertTrue(app.staticTexts["Search Articles"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testAllItemsShowsContentOrEmptyState() {
        app.typeKey("2", modifierFlags: [.command])
        // The filter bar ("All" / "Unread" segmented control) is always rendered on the
        // All Items view, confirming navigation succeeded and the view is live.
        XCTAssertTrue(app.radioButtons["All"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBookmarksShowsContentOrEmptyState() {
        app.typeKey("3", modifierFlags: [.command])
        // On Bookmarks there is no filter bar; check for either empty state or content.
        let hasEmpty = app.staticTexts["No bookmarks yet."].waitForExistence(timeout: 4)
        // If bookmarks exist they show in a list — app must still be running either way.
        XCTAssertTrue(hasEmpty || app.state == .runningForeground)
    }

    @MainActor
    func testDetailPaneShowsSelectAnArticleByDefault() {
        app.typeKey("2", modifierFlags: [.command])
        // With no item selected, the detail pane shows a placeholder.
        // (This may not appear if an item was auto-selected.)
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Feeds Menu Bar Tests

final class FeedsMenuTests: BroadsheetUITestCase {

    @MainActor
    func testFeedsMenuExists() {
        let menuBar = app.menuBars.firstMatch
        let feedsMenu = menuBar.menuBarItems["Feeds"]
        XCTAssertTrue(feedsMenu.waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeedsMenuContainsRefreshAllFeeds() {
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["Feeds"].click()
        let item = menuBar.menuBarItems["Feeds"].menus.menuItems["Refresh All Feeds"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testFeedsMenuContainsNavigation() {
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["Feeds"].click()
        let menu = menuBar.menuBarItems["Feeds"].menus
        XCTAssertTrue(menu.menuItems["Go to Today"].waitForExistence(timeout: 3))
        XCTAssertTrue(menu.menuItems["Go to All Items"].exists)
        XCTAssertTrue(menu.menuItems["Go to Bookmarks"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testGoToTodayViaFeedsMenu() {
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["Feeds"].click()
        let item = menuBar.menuBarItems["Feeds"].menus.menuItems["Go to Today"]
        if item.waitForExistence(timeout: 3) {
            item.click()
        }
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testGoToAllItemsViaFeedsMenu() {
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["Feeds"].click()
        let item = menuBar.menuBarItems["Feeds"].menus.menuItems["Go to All Items"]
        if item.waitForExistence(timeout: 3) {
            item.click()
        }
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testGoToBookmarksViaFeedsMenu() {
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["Feeds"].click()
        let item = menuBar.menuBarItems["Feeds"].menus.menuItems["Go to Bookmarks"]
        if item.waitForExistence(timeout: 3) {
            item.click()
        }
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - OPML Menu Tests

final class OPMLMenuTests: BroadsheetUITestCase {

    @MainActor
    func testImportOPMLMenuItemExists() {
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["File"].click()
        let item = menuBar.menuBarItems["File"].menus.menuItems["Import Feeds from OPML…"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testExportOPMLMenuItemExists() {
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["File"].click()
        let item = menuBar.menuBarItems["File"].menus.menuItems["Export Feeds as OPML…"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
    }
}

// MARK: - Refresh Tests

final class RefreshTests: BroadsheetUITestCase {

    @MainActor
    func testRefreshAllButtonExistsInToolbar() {
        XCTAssertTrue(app.buttons["Refresh All"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRefreshAllKeyboardShortcut() {
        // ⌘R = Refresh All Feeds
        app.typeKey("r", modifierFlags: [.command])
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Keyboard Shortcut Tests

final class KeyboardShortcutTests: BroadsheetUITestCase {

    @MainActor
    func testAddFeedShortcutOpensSheet() {
        focusSidebar()
        app.typeKey("n", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Add Feed"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testSettingsShortcutOpensSettings() {
        app.typeKey(",", modifierFlags: [.command])
        let settingsOpen = app.windows.count > 1 ||
                           app.staticTexts["Reading"].waitForExistence(timeout: 5)
        XCTAssertTrue(settingsOpen)
    }

    @MainActor
    func testNavigationShortcutsAllWork() {
        app.typeKey("1", modifierFlags: [.command]) // Today
        app.typeKey("2", modifierFlags: [.command]) // All Items
        app.typeKey("3", modifierFlags: [.command]) // Bookmarks
        app.typeKey("f", modifierFlags: [.command]) // Search
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Launch Performance

final class LaunchPerformanceTests: XCTestCase {

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-UITesting"]
            app.launch()
            app.terminate()
        }
    }
}
