import XCTest

/// End-to-end flows against stub data (`-UITesting`, `MOCK_DB`): engine picker → connection
/// sheet → workspace search.
final class SearchFlowUITests: XCTestCase {
    private var app: XCUIApplication?

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
        app = nil
    }

    private func launch(scenario: String = "1", delay: Int = 0) -> WelcomeScreen {
        let launched = AppLauncher.launch(scenario: scenario, delayMilliseconds: delay)
        app = launched
        return WelcomeScreen(app: launched).waitUntilShown()
    }

    // MARK: Splash

    func testSplashRunsChecksThenOpensWelcome() {
        let launched = AppLauncher.launch(splashMilliseconds: 4_000)
        app = launched
        let splash = SplashScreen(app: launched)
        XCTAssertTrue(splash.window.waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertTrue(splash.version.exists)
        for check in ["connectionStore", "keychain", "encryption", "sqlite", "duckDB", "tls", "cassandraDriver", "drivers", "network"] {
            XCTAssertTrue(splash.check(check).exists, "missing check \(check)")
        }
        XCTAssertTrue(WelcomeScreen(app: launched).engine("postgreSQL").waitForExistence(timeout: 20))
        XCTAssertFalse(splash.window.exists)
    }

    // MARK: Saving & export

    func testSaveWithoutConnectingAddsRecentConnection() {
        let welcome = launch()
        let sheet = welcome.choose("postgreSQL")
        XCTAssertTrue(sheet.saveButton.waitForExistence(timeout: WorkspaceScreen.timeout))
        sheet.saveButton.click()
        sheet.cancelButton.click()
        XCTAssertTrue(welcome.recent(0).waitForExistence(timeout: WorkspaceScreen.timeout))
    }

    func testExportRequiresMatchingPassphraseForPasswords() {
        let welcome = launch()
        let sheet = welcome.choose("postgreSQL")
        XCTAssertTrue(sheet.saveButton.waitForExistence(timeout: WorkspaceScreen.timeout))
        sheet.saveButton.click()
        sheet.cancelButton.click()
        let transfer = TransferScreen(app: welcome.app)
        XCTAssertTrue(transfer.exportButton.waitForExistence(timeout: WorkspaceScreen.timeout))
        transfer.exportButton.click()
        XCTAssertTrue(transfer.includeSecrets.waitForExistence(timeout: WorkspaceScreen.timeout))
        transfer.includeSecrets.click()
        XCTAssertTrue(transfer.passphrase.waitForExistence(timeout: WorkspaceScreen.timeout))
        transfer.passphrase.click()
        transfer.passphrase.typeText("short")
        transfer.confirmExport.click()
        XCTAssertTrue(transfer.status.waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertEqual(screenAlerts(), 0)
    }

    // MARK: Engine picker & connection sheet

    func testWelcomeListsEveryEngine() {
        let welcome = launch()
        let engines = ["postgreSQL", "cockroachDB", "greenplum", "redshift", "vertica", "mySQL", "mariaDB", "sqlServer", "oracle",
                       "sqlite", "duckDB", "libSQL", "cloudflareD1", "clickHouse", "bigQuery", "snowflake", "cassandra", "redis",
                       "mongoDB", "elasticsearch", "dynamoDB"]
        for engine in engines {
            XCTAssertTrue(welcome.engine(engine).exists, "missing \(engine)")
        }
    }

    func testEngineSearchFilters() {
        let welcome = launch()
        welcome.search.click()
        welcome.search.typeText("mongo")
        XCTAssertTrue(welcome.engine("mongoDB").waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertFalse(welcome.engine("postgreSQL").exists)
        welcome.search.typeText("zzzz")
        XCTAssertTrue(welcome.empty.waitForExistence(timeout: WorkspaceScreen.timeout))
    }

    func testConnectionSheetShowsEngineDefaultsAndCancels() {
        let sheet = launch().choose("oracle")
        XCTAssertTrue(sheet.connectButton.waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertEqual(sheet.value(of: "port"), "1521")
        XCTAssertEqual(sheet.value(of: "serviceName"), "FREEPDB1")
        sheet.cancelButton.click()
        XCTAssertFalse(sheet.sheet.waitForExistence(timeout: 1))
    }

    func testConnectionStringImportFillsFields() {
        let sheet = launch().choose("mySQL")
        XCTAssertTrue(sheet.connectionString.waitForExistence(timeout: WorkspaceScreen.timeout))
        sheet.importURL("mysql://ada:secret@db.internal:3307/app")
        XCTAssertEqual(sheet.value(of: "host"), "db.internal")
        XCTAssertEqual(sheet.value(of: "port"), "3307")
        XCTAssertEqual(sheet.value(of: "database"), "app")
    }

    func testTypedConnectionStringFillsFieldsWithoutImport() {
        let sheet = launch().choose("postgreSQL")
        XCTAssertTrue(sheet.connectionString.waitForExistence(timeout: WorkspaceScreen.timeout))
        sheet.connectionString.click()
        sheet.connectionString.typeText("postgresql://query_reader:ReaderPass1@localhost:55432/app")
        XCTAssertEqual(sheet.value(of: "username"), "query_reader")
        XCTAssertEqual(sheet.value(of: "port"), "55432")
        XCTAssertEqual(sheet.value(of: "database"), "app")
    }

    func testTestButtonReportsInline() {
        let sheet = launch().choose("redis")
        XCTAssertTrue(sheet.testButton.waitForExistence(timeout: WorkspaceScreen.timeout))
        sheet.testButton.click()
        XCTAssertTrue(sheet.status.waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertEqual(screenAlerts(), 0)
    }

    func testConnectOpensWorkspaceAndDisconnectReturns() {
        let workspace = launch().connect()
        workspace.waitForCatalog()
        workspace.disconnectButton.click()
        let welcome = WelcomeScreen(app: workspace.app)
        XCTAssertTrue(welcome.engine("postgreSQL").waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertTrue(welcome.recent(0).waitForExistence(timeout: WorkspaceScreen.timeout), "connection was saved")
    }

    // MARK: Workspace search

    func testSkeletonTransitionsToCatalog() {
        let workspace = launch(delay: 1_500).connect()
        XCTAssertTrue(workspace.sidebarSkeleton.waitForExistence(timeout: WorkspaceScreen.timeout))
        workspace.waitForCatalog()
        XCTAssertFalse(workspace.sidebarSkeleton.exists)
    }

    func testSidebarSearchFiltersLocally() {
        let workspace = launch().connect().waitForCatalog()
        workspace.searchSidebar("oi")
        XCTAssertTrue(workspace.sidebarRow("public.order_items").waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertFalse(workspace.sidebarRow("public.customers").exists)
        workspace.sidebarSearch.typeText("zzz")
        XCTAssertTrue(workspace.sidebarEmpty.waitForExistence(timeout: WorkspaceScreen.timeout))
    }

    func testOpenAnythingWithKeyboard() {
        let workspace = launch().connect().waitForCatalog()
        let palette = workspace.openAnything()
        XCTAssertTrue(palette.searchField.waitForExistence(timeout: WorkspaceScreen.timeout))
        palette.type("oi")
        XCTAssertTrue(palette.result(0).waitForExistence(timeout: WorkspaceScreen.timeout))
        palette.confirm()
        XCTAssertTrue(workspace.results.waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertTrue(workspace.waitForRowCount("5 rows"))
    }

    func testOpenAnythingNoMatchesAndEscape() {
        let workspace = launch().connect().waitForCatalog()
        let palette = workspace.openAnything()
        XCTAssertTrue(palette.searchField.waitForExistence(timeout: WorkspaceScreen.timeout))
        palette.type("qqq")
        XCTAssertTrue(palette.empty.waitForExistence(timeout: WorkspaceScreen.timeout))
        palette.dismiss()
        XCTAssertTrue(workspace.detailPlaceholder.waitForExistence(timeout: WorkspaceScreen.timeout))
    }

    func testRowFilterRunsAndClears() {
        let workspace = launch().connect().waitForCatalog()
        workspace.open("public.customers")
        XCTAssertTrue(workspace.waitForRowCount("12 rows"))
        let filters = workspace.toggleFilters()
        XCTAssertTrue(filters.valueField(0).waitForExistence(timeout: WorkspaceScreen.timeout))
        filters.filter(by: "example.com")
        XCTAssertTrue(workspace.waitForRowCount("4 rows"))
        filters.valueField(0).typeText("zzz")
        filters.applyButton.click()
        XCTAssertTrue(workspace.detailEmpty.waitForExistence(timeout: WorkspaceScreen.timeout))
        filters.clearButton.click()
        XCTAssertTrue(workspace.waitForRowCount("12 rows"))
    }

    func testEmptyCatalogFallback() {
        let workspace = launch(scenario: "empty").connect()
        XCTAssertTrue(workspace.sidebarEmpty.waitForExistence(timeout: WorkspaceScreen.timeout))
    }

    func testBackendFailureStaysOnSheetWithoutAlerts() {
        let sheet = launch(scenario: "failing").choose("postgreSQL")
        XCTAssertTrue(sheet.connectButton.waitForExistence(timeout: WorkspaceScreen.timeout))
        sheet.connectButton.click()
        XCTAssertTrue(sheet.status.waitForExistence(timeout: WorkspaceScreen.timeout))
        XCTAssertTrue(sheet.connectButton.exists)
        XCTAssertEqual(screenAlerts(), 0)
    }

    func testRefreshShortcutKeepsSelection() {
        let workspace = launch().connect().waitForCatalog()
        workspace.open("public.orders")
        XCTAssertTrue(workspace.waitForRowCount("20 rows"))
        workspace.app.typeKey("r", modifierFlags: .command)
        XCTAssertTrue(workspace.waitForRowCount("20 rows"))
    }

    func testSettingsWindowOpens() {
        let welcome = launch()
        let settings = SettingsScreen.open(in: welcome.app)
        XCTAssertTrue(settings.languagePicker.waitForExistence(timeout: WorkspaceScreen.timeout))
    }

    func testMultipleWindows() {
        let welcome = launch()
        let before = welcome.app.windows.count
        welcome.app.typeKey("n", modifierFlags: .command)
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count > %d", before), object: welcome.app.windows)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: WorkspaceScreen.timeout), .completed)
    }

    func testAccessibilityAudit() throws {
        let welcome = launch()
        try welcome.app.performAccessibilityAudit()
        let workspace = welcome.connect().waitForCatalog()
        workspace.open("public.customers")
        XCTAssertTrue(workspace.results.waitForExistence(timeout: WorkspaceScreen.timeout))
        try workspace.app.performAccessibilityAudit()
    }

    private func screenAlerts() -> Int {
        (app?.dialogs.count ?? 0) + (app?.alerts.count ?? 0)
    }
}
