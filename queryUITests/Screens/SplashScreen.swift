import XCTest

/// Page object for the launch splash.
struct SplashScreen {
    let app: XCUIApplication

    var window: XCUIElement { app.descendants(matching: .any)["splash.window"].firstMatch }
    var progress: XCUIElement { app.descendants(matching: .any)["splash.progress"].firstMatch }
    var version: XCUIElement { app.descendants(matching: .any)["splash.version"].firstMatch }

    func check(_ raw: String) -> XCUIElement { app.descendants(matching: .any)["splash.check.\(raw)"].firstMatch }
}
