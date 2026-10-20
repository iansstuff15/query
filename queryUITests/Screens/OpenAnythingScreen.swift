import XCTest

/// Page object for the ⌘P palette.
struct OpenAnythingScreen {
    let app: XCUIApplication

    var panel: XCUIElement { app.descendants(matching: .any)["openAnything.panel"].firstMatch }
    var searchField: XCUIElement { app.textFields["openAnything.search"] }
    var empty: XCUIElement { app.descendants(matching: .any)["openAnything.empty"].firstMatch }

    func result(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any)["openAnything.result.\(index)"].firstMatch
    }

    func type(_ text: String) {
        searchField.typeText(text)
    }

    func pressDown() {
        searchField.typeKey(.downArrow, modifierFlags: [])
    }

    func confirm() {
        searchField.typeKey(.return, modifierFlags: [])
    }

    func dismiss() {
        searchField.typeKey(.escape, modifierFlags: [])
    }
}
