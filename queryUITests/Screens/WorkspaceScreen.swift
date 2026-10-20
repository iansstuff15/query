import XCTest

/// Page object for the main database window.
struct WorkspaceScreen {
    let app: XCUIApplication
    static let timeout: TimeInterval = 10

    var sidebarSearch: XCUIElement { app.textFields["sidebar.search"] }
    var sidebarSkeleton: XCUIElement { element("sidebar.skeleton") }
    var sidebarEmpty: XCUIElement { element("sidebar.empty") }
    var detailPlaceholder: XCUIElement { element("detail.placeholder") }
    var detailSkeleton: XCUIElement { element("detail.skeleton") }
    var results: XCUIElement { element("detail.results") }
    var detailEmpty: XCUIElement { element("detail.empty") }
    var rowCount: XCUIElement { element("detail.rowCount") }
    var openAnythingButton: XCUIElement { app.buttons["toolbar.openAnything"] }
    var filtersButton: XCUIElement { app.buttons["toolbar.filters"] }
    var disconnectButton: XCUIElement { app.buttons["toolbar.disconnect"] }

    func sidebarRow(_ objectID: String) -> XCUIElement {
        element("sidebar.row.\(objectID)")
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @discardableResult
    func waitForCatalog(file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(sidebarRow("public.customers").waitForExistence(timeout: Self.timeout), file: file, line: line)
        return self
    }

    func searchSidebar(_ text: String) {
        sidebarSearch.click()
        sidebarSearch.typeText(text)
    }

    func open(_ objectID: String) {
        sidebarRow(objectID).click()
    }

    func openAnything() -> OpenAnythingScreen {
        app.typeKey("p", modifierFlags: .command)
        return OpenAnythingScreen(app: app)
    }

    func toggleFilters() -> FilterBarScreen {
        app.typeKey("f", modifierFlags: [.command, .shift])
        return FilterBarScreen(app: app)
    }

    /// The footer text, e.g. "12 rows".
    var rowCountText: String {
        (rowCount.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? rowCount.label
    }

    func waitForRowCount(_ text: String, timeout: TimeInterval = timeout) -> Bool {
        let predicate = NSPredicate { _, _ in self.rowCountText == text }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
