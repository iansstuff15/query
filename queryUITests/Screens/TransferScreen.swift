import XCTest

/// Page object for connection export / import.
struct TransferScreen {
    let app: XCUIApplication

    var exportButton: XCUIElement { app.buttons["transfer.export"] }
    var importButton: XCUIElement { app.buttons["transfer.import"] }
    var includeSecrets: XCUIElement { app.checkBoxes["transfer.includeSecrets"] }
    var passphrase: XCUIElement { app.secureTextFields["transfer.passphrase"] }
    var confirmation: XCUIElement { app.secureTextFields["transfer.confirmation"] }
    var confirmExport: XCUIElement { app.buttons["transfer.exportConfirm"] }
    var status: XCUIElement { app.descendants(matching: .any)["transfer.status"].firstMatch }
}
