import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import query

/// Renders the app's main screens with stub data into PNGs for the README (docs/screenshots).
/// Opt-in, so normal runs skip it:
///
///     TEST_RUNNER_QUERY_SCREENSHOTS=1 xcodebuild test -project query.xcodeproj -scheme query \
///       -testPlan Unit -only-testing:queryTests/ReadmeScreenshotTests
///
/// Each screen opens in a real window; meanwhile run `scripts/capture-screenshots.sh`, which
/// photographs each window with `screencapture` and writes the PNGs to docs/screenshots.
@MainActor
@Suite("README screenshots", .enabled(if: ProcessInfo.processInfo.environment["QUERY_SCREENSHOTS"] != nil), .serialized)
struct ReadmeScreenshotTests {
    private static let folder = URL(filePath: NSTemporaryDirectory()).appending(path: "readme-screenshots")
    private let session = ConnectionSession(id: UUID(), name: "Local Postgres", engine: .postgreSQL, client: StubDatabaseClient())

    /// Shows `view` in a real window (light appearance) and waits for it to be photographed:
    /// writes `<name>.window` with the window number, then waits for `<name>.done`, which
    /// `scripts/capture-screenshots.sh` writes after
    /// running `screencapture -l <number>`. Real windows render glass, sidebars and inspectors,
    /// which offscreen rendering can't.
    private func capture(_ view: some View, _ name: String, width: CGFloat, height: CGFloat, wait: Duration = .milliseconds(1_500)) async throws {
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let size = NSSize(width: width, height: height)
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: 80, y: 120), size: size), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: view.frame(width: width, height: height))
        // Active, so controls draw as they do in use rather than dimmed.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        try await Task.sleep(for: wait)
        let done = Self.folder.appending(path: "\(name).done")
        try? FileManager.default.removeItem(at: done)
        try String(window.windowNumber).write(to: Self.folder.appending(path: "\(name).window"), atomically: true, encoding: .utf8)
        for _ in 0..<200 where !FileManager.default.fileExists(atPath: done.path) {
            try await Task.sleep(for: .milliseconds(100))
        }
        window.close()
    }

    @Test func welcome() async throws {
        let container = try ModelContainer(for: SavedConnection.self, SQLHistoryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        for (name, engine) in [("Local Postgres", DatabaseEngine.postgreSQL), ("Analytics MySQL", .mySQL), ("Orders on SQL Server", .sqlServer)] {
            container.mainContext.insert(SavedConnection(name: name, engine: engine, sealedValues: Data(), date: .now))
        }
        let view = WelcomeView(factory: StubDatabaseClientFactory(), store: PreviewConnectionStore(), clipboard: EmptyClipboard(), onConnected: { _ in })
            .modelContainer(container)
        try await capture(view, "welcome", width: 1_180, height: 720, wait: .seconds(2))
    }

    @Test func workspace() async throws {
        let sql = """
            SELECT c.full_name, count(o.id) AS orders, sum(o.total) AS spent
            FROM customers c LEFT JOIN orders o ON o.customer_id = c.id
            GROUP BY c.full_name
            ORDER BY spent DESC;
            SELECT * FROM products WHERE in_stock;
            """
        let view = WorkspaceView(
            session: session, history: InMemorySQLHistoryStore(), initialObjectID: "public.customers", initialSQL: sql, onDisconnect: {}
        )
        try await capture(view, "workspace", width: 1_400, height: 780, wait: .seconds(2))
    }

    @Test func sqlEditor() async throws {
        let console = SQLConsoleViewModel(client: StubDatabaseClient(), text: """
            -- Each line, or statement ending in ;, has its own ▶
            SELECT id, full_name, country FROM customers WHERE country = 'US';
            SELECT p.name, sum(oi.quantity) AS units
            FROM order_items oi JOIN products p ON p.id = oi.product_id
            GROUP BY p.name ORDER BY units DESC;
            UPDATE customers SET country = 'GB' WHERE id = 7;
            """)
        await console.run(["SELECT id, full_name, country FROM customers WHERE country = 'US'", "UPDATE customers SET country = 'GB' WHERE id = 7"])
        struct Panel: View {
            @State var tab = SQLConsoleTab.editor
            let model: SQLConsoleViewModel
            var body: some View { SQLConsoleView(model: model, objects: SampleCatalog.objects, tab: $tab, rowEditor: nil, onOpenFile: {}) }
        }
        try await capture(Panel(model: console), "sql-editor", width: 520, height: 640)
    }

    @Test func rowEditor() async throws {
        let model = RowEditorViewModel(
            object: SampleCatalog.objects[2], columns: SampleCatalog.customerColumns,
            row: ResultRow(id: 6, values: SampleCatalog.customerRows[6]), client: StubDatabaseClient()
        )
        await model.loadKey()
        model.setNull(false, for: 3)
        model.fields[3].text = "US"
        try await capture(RowEditorView(model: model), "row-editor", width: 420, height: 520)
    }

    @Test func users() async throws {
        try await capture(UserManagementView(session: session, selecting: "query_reader"), "users", width: 1_180, height: 640, wait: .seconds(2))
    }

    @Test func startupConfiguration() async throws {
        try await capture(StartupConfigurationView(switcher: SwitchableCredentialStore(
            stores: [.sqlite: EphemeralCredentialStore(), .keychain: EphemeralCredentialStore()], active: .sqlite
        ), flags: FeatureFlags(infoDictionary: ["ENABLE_LANGUAGE_SETTING": false])), "startup-configuration", width: 660, height: 600)
    }

    @Test func whatsNew() async throws {
        let model = WhatsNewViewModel(provider: BundleChangelogProvider())
        await model.load()
        try await capture(WhatsNewView(model: model, onDone: {}), "whats-new", width: 620, height: 580)
    }
}
