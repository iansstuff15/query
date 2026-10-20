import XCTest

/// Page object for the first screen (engine grid + recent connections).
struct WelcomeScreen {
    let app: XCUIApplication

    var grid: XCUIElement { app.descendants(matching: .any)["welcome.grid"].firstMatch }
    var search: XCUIElement { app.textFields["welcome.search"] }
    var empty: XCUIElement { app.descendants(matching: .any)["welcome.empty"].firstMatch }

    func engine(_ raw: String) -> XCUIElement { app.buttons["welcome.engine.\(raw)"] }
    func recent(_ index: Int) -> XCUIElement { app.descendants(matching: .any)["welcome.recent.\(index)"].firstMatch }

    @discardableResult
    func waitUntilShown(file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(engine("postgreSQL").waitForExistence(timeout: WorkspaceScreen.timeout), file: file, line: line)
        return self
    }

    func choose(_ raw: String) -> ConnectionSheetScreen {
        engine(raw).click()
        return ConnectionSheetScreen(app: app)
    }

    /// Picks an engine and connects with its defaults (stub data in UI tests).
    func connect(_ raw: String = "postgreSQL") -> WorkspaceScreen {
        let sheet = choose(raw)
        XCTAssertTrue(sheet.connectButton.waitForExistence(timeout: WorkspaceScreen.timeout))
        sheet.connectButton.click()
        return WorkspaceScreen(app: app)
    }
}
