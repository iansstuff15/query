import XCTest

/// Launches the app against deterministic stub data with no restored windows (`-UITesting`
/// turns window restoration off; `-ApplePersistenceIgnoreState` must not be used, because it
/// stops SwiftUI from opening any window at launch).
enum AppLauncher {
    static func launch(scenario: String = "1", delayMilliseconds: Int = 0, splashMilliseconds: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launchEnvironment = [
            "MOCK_DB": scenario, "MOCK_DB_DELAY_MS": "\(delayMilliseconds)", "SPLASH_MIN_MS": "\(splashMilliseconds)",
        ]
        app.launch()
        app.activate()
        return app
    }
}
