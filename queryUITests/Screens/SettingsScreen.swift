import XCTest

/// Page object for the Settings (⌘,) window.
struct SettingsScreen {
    let app: XCUIApplication

    static func open(in app: XCUIApplication) -> SettingsScreen {
        app.typeKey(",", modifierFlags: .command)
        return SettingsScreen(app: app)
    }

    var matchingStrategy: XCUIElement { app.descendants(matching: .any)["settings.matchingStrategy"].firstMatch }
    /// The first tab, Language.
    var languagePicker: XCUIElement { app.descendants(matching: .any)["setup.languagePicker"].firstMatch }
}
