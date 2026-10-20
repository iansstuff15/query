import XCTest

/// Page object for the row filter bar.
struct FilterBarScreen {
    let app: XCUIApplication

    var bar: XCUIElement { app.descendants(matching: .any)["filter.bar"].firstMatch }
    var addButton: XCUIElement { app.buttons["filter.add"] }
    var applyButton: XCUIElement { app.buttons["filter.apply"] }
    var clearButton: XCUIElement { app.buttons["filter.clear"] }
    var sqlPreview: XCUIElement { app.descendants(matching: .any)["filter.sqlPreview"].firstMatch }

    func valueField(_ index: Int) -> XCUIElement { app.textFields["filter.rule.\(index).value"] }
    func removeButton(_ index: Int) -> XCUIElement { app.buttons["filter.rule.\(index).remove"] }

    func filter(_ index: Int = 0, by value: String) {
        let field = valueField(index)
        field.click()
        field.typeText(value)
        field.typeKey(.return, modifierFlags: [])
    }
}
