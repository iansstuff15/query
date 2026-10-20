import XCTest

/// Launches the app against deterministic stub data with no restored windows.
enum AppLauncher {
    static func launch(scenario: String = "1", delayMilliseconds: Int = 0, splashMilliseconds: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = [
            "MOCK_DB": scenario, "MOCK_DB_DELAY_MS": "\(delayMilliseconds)", "SPLASH_MIN_MS": "\(splashMilliseconds)",
        ]
        app.launch()
        app.activate()
        return app
    }
}
