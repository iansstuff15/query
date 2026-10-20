import Testing
@testable import query

@Suite("LaunchOptions")
struct LaunchOptionsTests {
    @Test func normalLaunchUsesRealDatabase() {
        let options = LaunchOptions(arguments: [], environment: [:])
        #expect(options.stubScenario == nil)
        #expect(options.stubDelay == .zero)
    }

    @Test func uiTestingDefaultsToSampleData() {
        #expect(LaunchOptions(arguments: ["-UITesting"], environment: [:]).stubScenario == .sample)
    }

    @Test(arguments: [("1", StubScenario.sample), ("empty", .empty), ("failing", .failing)])
    func mockEnvironmentSelectsScenario(raw: String, scenario: StubScenario) {
        #expect(LaunchOptions(arguments: [], environment: ["MOCK_DB": raw]).stubScenario == scenario)
    }

    @Test func testHostsAndStubsAreIsolated() {
        #expect(!LaunchOptions(arguments: [], environment: [:]).isIsolated)
        let host = LaunchOptions(arguments: [], environment: ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"])
        #expect(host.isHostingTests)
        #expect(host.isIsolated)
        #expect(host.stubScenario == nil)
        #expect(LaunchOptions(arguments: ["-UITesting"], environment: [:]).isIsolated)
    }

    @Test func splashMinimumDefaultsAndOverrides() {
        #expect(LaunchOptions(arguments: [], environment: [:]).splashMinimum == .milliseconds(AppConfig.splashMinimumMilliseconds))
        #expect(LaunchOptions(arguments: ["-UITesting"], environment: [:]).splashMinimum == .zero)
        #expect(LaunchOptions(arguments: ["-UITesting"], environment: ["SPLASH_MIN_MS": "2500"]).splashMinimum == .milliseconds(2_500))
    }

    @Test func delayIsParsedAndClamped() {
        #expect(LaunchOptions(arguments: [], environment: ["MOCK_DB_DELAY_MS": "250"]).stubDelay == .milliseconds(250))
        #expect(LaunchOptions(arguments: [], environment: ["MOCK_DB_DELAY_MS": "-3"]).stubDelay == .zero)
        #expect(LaunchOptions(arguments: [], environment: ["MOCK_DB_DELAY_MS": "x"]).stubDelay == .zero)
    }
}
