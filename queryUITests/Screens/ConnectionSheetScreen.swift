import XCTest

/// Page object for the connection popup.
struct ConnectionSheetScreen {
    let app: XCUIApplication

    var sheet: XCUIElement { app.descendants(matching: .any)["connection.sheet"].firstMatch }
    var connectionString: XCUIElement { app.textFields["connection.url"] }
    var importButton: XCUIElement { app.buttons["connection.import"] }
    var testButton: XCUIElement { app.buttons["connection.test"] }
    var connectButton: XCUIElement { app.buttons["connection.connect"] }
    var saveButton: XCUIElement { app.buttons["connection.save"] }
    var cancelButton: XCUIElement { app.buttons["connection.cancel"] }
    var status: XCUIElement { app.descendants(matching: .any)["connection.status"].firstMatch }

    func field(_ raw: String) -> XCUIElement {
        let text = app.textFields["connection.field.\(raw)"]
        return text.exists ? text : app.secureTextFields["connection.field.\(raw)"]
    }

    func value(of raw: String) -> String {
        field(raw).value as? String ?? ""
    }

    func importURL(_ url: String) {
        connectionString.click()
        connectionString.typeText(url)
        importButton.click()
    }
}
