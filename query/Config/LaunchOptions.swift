import Foundation

/// Launch arguments / environment that switch the app to deterministic stub data.
nonisolated struct LaunchOptions: Sendable {
    let stubScenario: StubScenario?
    let stubDelay: Duration
    /// Minimum time the splash stays up (`SPLASH_MIN_MS`); zero under UI tests by default.
    let splashMinimum: Duration
    /// Launched as the host of unit / integration tests (Xcode sets `XCTestConfigurationFilePath`).
    let isHostingTests: Bool

    init(arguments: [String], environment: [String: String]) {
        let isUITesting = arguments.contains("-UITesting")
        let requested = environment["MOCK_DB"].flatMap(StubScenario.init(rawValue:))
        stubScenario = requested ?? (isUITesting ? .sample : nil)
        let milliseconds = environment["MOCK_DB_DELAY_MS"].flatMap(Int.init) ?? 0
        stubDelay = .milliseconds(max(milliseconds, 0))
        let splash = environment["SPLASH_MIN_MS"].flatMap(Int.init) ?? (isUITesting ? 0 : AppConfig.splashMinimumMilliseconds)
        splashMinimum = .milliseconds(max(splash, 0))
        isHostingTests = environment["XCTestConfigurationFilePath"] != nil
    }

    /// Stub data, UI tests or a test host: keep away from the user's Keychain, clipboard and
    /// saved connections, so test runs never prompt or change real data.
    var isIsolated: Bool { stubScenario != nil || isHostingTests }

    static var current: LaunchOptions {
        LaunchOptions(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }
}
