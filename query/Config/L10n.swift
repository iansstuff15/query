import SwiftUI

/// User-facing strings. Keys live in `Localizable.xcstrings`.
enum L10n {
    // Splash
    static let appName: LocalizedStringKey = "query"
    static let splashTagline: LocalizedStringKey = "Every database, one search."
    static let splashStarting: LocalizedStringKey = "Starting…"
    static let checkUnavailable: LocalizedStringKey = "unavailable"
    static func version(_ version: String, _ build: String) -> LocalizedStringKey { "Version \(version) (\(build))" }

    static func title(for check: StartupCheckID) -> LocalizedStringKey {
        switch check {
        case .connectionStore: "Connection store"
        case .keychain: "Secret Store"
        case .encryption: "Encryption"
        case .sqlite: "SQLite"
        case .duckDB: "DuckDB"
        case .tls: "TLS"
        case .cassandraDriver: "Cassandra driver"
        case .drivers: "Database drivers"
        case .network: "Network"
        }
    }

    static func running(for check: StartupCheckID) -> LocalizedStringKey {
        switch check {
        case .connectionStore: "Opening saved connections…"
        case .keychain: "Verifying the secret store…"
        case .encryption: "Unlocking the connection vault…"
        case .sqlite: "Loading SQLite…"
        case .duckDB: "Loading DuckDB…"
        case .tls: "Initializing TLS…"
        case .cassandraDriver: "Loading the Cassandra driver…"
        case .drivers: "Registering database drivers…"
        case .network: "Checking the network…"
        }
    }

    // Commands & toolbar
    static let databaseMenu: LocalizedStringKey = "Database"
    static let openAnything: LocalizedStringKey = "Open Anything"
    static let openAnythingHelp: LocalizedStringKey = "Jump to any table or view (⌘P)"
    static let refresh: LocalizedStringKey = "Refresh"
    static let refreshHelp: LocalizedStringKey = "Reload objects and rows (⌘R)"
    static let filters: LocalizedStringKey = "Filters"
    static let filtersHelp: LocalizedStringKey = "Show or hide the row filter (⇧⌘F)"
    static let searchSidebar: LocalizedStringKey = "Search Sidebar"

    // Sidebar
    static let sidebarSearchPrompt: LocalizedStringKey = "Search tables and views"
    static let sidebarSearchHint: LocalizedStringKey = "Filters the list of tables and views"
    static let objectRowHint: LocalizedStringKey = "Shows this object's rows"
    static let open: LocalizedStringKey = "Open"
    static let openWithFilters: LocalizedStringKey = "Open with Filters"
    static let noObjects: LocalizedStringKey = "No Database Objects"
    static let noObjectsDetail: LocalizedStringKey = "No tables or views are visible to this user, or the database is unreachable. Refresh with ⌘R."
    static let noMatches: LocalizedStringKey = "No Matches"
    static let noMatchesDetail: LocalizedStringKey = "Try a shorter or different search."
    static let loading: LocalizedStringKey = "Loading"

    // Open Anything
    static let openAnythingPrompt: LocalizedStringKey = "Search tables, views… (try schema.name)"
    static let openAnythingHint: LocalizedStringKey = "Type to search; use arrow keys and Return to open"
    static let openAnythingResultHint: LocalizedStringKey = "Opens this object"

    // Detail
    static let selectObject: LocalizedStringKey = "Select a Table"
    static let selectObjectDetail: LocalizedStringKey = "Choose a table or view in the sidebar, or press ⌘P."
    static let noRows: LocalizedStringKey = "No Rows"
    static let noRowsDetail: LocalizedStringKey = "Nothing matches the current filters."
    static func rowCount(_ count: Int) -> LocalizedStringKey { "\(count) rows" }

    // Filter bar
    static let anyColumn: LocalizedStringKey = "Any column"
    static let column: LocalizedStringKey = "Column"
    static let filterOperator: LocalizedStringKey = "Operator"
    static let value: LocalizedStringKey = "Value"
    static let valueHint: LocalizedStringKey = "Press Return to apply the filter"
    static let enabled: LocalizedStringKey = "Enabled"
    static let addFilter: LocalizedStringKey = "Add Filter"
    static let cloneFilter: LocalizedStringKey = "Clone this filter"
    static let removeFilter: LocalizedStringKey = "Remove this filter"
    static let apply: LocalizedStringKey = "Apply"
    static let applyHint: LocalizedStringKey = "Runs the filter on the server (⌘↩)"
    static let clear: LocalizedStringKey = "Clear"
    static let clearHint: LocalizedStringKey = "Removes all filters and reloads"
    static let generatedSQL: LocalizedStringKey = "Generated SQL"

    // Settings
    static let search: LocalizedStringKey = "Search"
    static let matching: LocalizedStringKey = "Matching"

    // Welcome
    static let welcomeTitle: LocalizedStringKey = "Choose a Database"
    static let welcomeSubtitle: LocalizedStringKey = "Pick an engine to enter its connection details."
    static let engineSearchPrompt: LocalizedStringKey = "Filter engines"
    static let engineSearchHint: LocalizedStringKey = "Filters the list of database engines"
    static let engineHint: LocalizedStringKey = "Opens the connection form for this engine"
    static let recentConnections: LocalizedStringKey = "Recent Connections"
    static let recentHint: LocalizedStringKey = "Connects and opens this database"
    static let noRecentConnections: LocalizedStringKey = "Connections you save appear here."
    static let checkAgain: LocalizedStringKey = "Check Again"
    static let recentToggleHelp: LocalizedStringKey = "Show or hide recent connections"
    static let checkAgainHint: LocalizedStringKey = "Tests whether each saved connection can connect"
    static let editConnection: LocalizedStringKey = "Edit Connection"
    static let editConnectionHint: LocalizedStringKey = "Changes this connection's details"
    static let connectionChecking: LocalizedStringKey = "Checking connection"
    static let connectionConnecting: LocalizedStringKey = "Connecting"
    static let connectionReachable: LocalizedStringKey = "Can connect"
    static let connectionUnreachable: LocalizedStringKey = "Can't connect"
    static let connectionUnreachableHelp: LocalizedStringKey = "Couldn't connect with the saved details. Edit the connection to fix it."

    // SQL console
    static let sqlConsole: LocalizedStringKey = "SQL Console"
    static let sqlConsoleHelp: LocalizedStringKey = "Show or hide the SQL console (⌥⌘S)"
    static let sqlEditorLabel: LocalizedStringKey = "SQL"
    /// For the AppKit editor, which takes a plain string.
    static var sqlEditorAccessibilityLabel: String { String(localized: "SQL") }
    static let sqlPlaceholder: LocalizedStringKey = "Type SQL to run against this database"
    static let runSQL: LocalizedStringKey = "Run"
    static let sqlIdleDetail: LocalizedStringKey = "Results appear in the center panel."
    static let sqlRunning: LocalizedStringKey = "Running…"
    static let sqlStatus: LocalizedStringKey = "Status"
    static let sqlSucceeded: LocalizedStringKey = "Succeeded"
    static let sqlFailed: LocalizedStringKey = "Failed"
    static let sqlDuration: LocalizedStringKey = "Duration"
    static let sqlRowsReturned: LocalizedStringKey = "Rows returned"
    static let sqlFailedSeeConsole: LocalizedStringKey = "The error is shown in the SQL console."
    static let queryResults: LocalizedStringKey = "Query Results"
    static let queryResultGoneTitle: LocalizedStringKey = "No Result"
    static let queryResultGoneDetail: LocalizedStringKey = "Run the statement again to see its result."
    static let runAll: LocalizedStringKey = "Run All"
    static let runAllHint: LocalizedStringKey = "Runs every statement in the editor, in order, stopping at the first failure (⇧⌘↩)"
    static let runStatementHint: LocalizedStringKey = "Each line, and each statement ending in ;, runs on its own: click ▶ beside it, or press ⌘↩ to run the one at the cursor"
    static let sqlBatchStopped: LocalizedStringKey = "Stopped at the first failure."
    static func sqlBatchProgress(_ ran: Int, _ total: Int) -> LocalizedStringKey { "Ran \(ran) of \(total) statements" }
    /// For the AppKit gutter, which takes plain strings.
    static func runStatementAccessibilityLabel(_ sql: String) -> String { String(localized: "Run \(sql)") }
    static let closeTab: LocalizedStringKey = "Close Tab"
    static let closeOtherTabs: LocalizedStringKey = "Close Other Tabs"
    static let tabHint: LocalizedStringKey = "Shows this tab"
    static let jumpBarHint: LocalizedStringKey = "Shows the items at this level"
    static let goBack: LocalizedStringKey = "Go Back"
    static let goForward: LocalizedStringKey = "Go Forward"
    static let goBackHelp: LocalizedStringKey = "Go back to the previous tab (⌃⌘←)"
    static let goForwardHelp: LocalizedStringKey = "Go forward (⌃⌘→)"
    static let sqlNoRowsTitle: LocalizedStringKey = "No Rows Returned"
    static let sqlNoRowsDetail: LocalizedStringKey = "The statement ran."
    static let sqlFailedTitle: LocalizedStringKey = "The Statement Didn't Run"
    static let sqlFailedDetail: LocalizedStringKey = "The server didn't say why. Check the SQL and your permissions, then try again."
    static let sqlUnsupportedTitle: LocalizedStringKey = "SQL Isn't Available"
    static let sqlUnsupportedDetail: LocalizedStringKey = "This database doesn't use SQL."
    static let deleteConnection: LocalizedStringKey = "Delete Connection"

    // Export / import
    static let importConnections: LocalizedStringKey = "Import Connections…"
    static let exportConnections: LocalizedStringKey = "Export Connections…"
    static let importHint: LocalizedStringKey = "Adds connections from an export file (⇧⌘I)"
    static let exportHint: LocalizedStringKey = "Saves your connections to a file (⇧⌘E)"
    static let exportTitle: LocalizedStringKey = "Export Connections"
    static let includePasswords: LocalizedStringKey = "Include passwords and tokens"
    static let includePasswordsHint: LocalizedStringKey = "Encrypts the file with a passphrase you choose"
    static let passphrase: LocalizedStringKey = "Passphrase"
    static let confirmPassphrase: LocalizedStringKey = "Confirm Passphrase"
    static let exportPlainFooter: LocalizedStringKey = "Hosts, ports, users and options are saved as JSON. Passwords are left out."
    static let exportEncryptedFooter: LocalizedStringKey = "The file is encrypted with AES-256 using a key derived from your passphrase (8+ characters). It can't be recovered without it."
    static let exportAction: LocalizedStringKey = "Export…"
    static let importAction: LocalizedStringKey = "Import"
    static let exportFilename = "query-connections"
    static let importPassphraseTitle: LocalizedStringKey = "Encrypted Export"
    static let importPassphraseDetail: LocalizedStringKey = "Enter the passphrase used when these connections were exported."
    static let wrongPassphrase: LocalizedStringKey = "That passphrase doesn't open this file."
    static let unreadableExport: LocalizedStringKey = "This file isn't a connection export."
    static let passphraseTooShort: LocalizedStringKey = "Use a passphrase of at least 8 characters."
    static let passphrasesDiffer: LocalizedStringKey = "The passphrases don't match."
    static func exportedCount(_ count: Int) -> LocalizedStringKey { "Exported \(count) connections." }
    static func importedCount(_ count: Int) -> LocalizedStringKey { "Imported \(count) connections." }

    // Connection sheet
    static let connectionString: LocalizedStringKey = "Connection String"
    static let connectionStringHint: LocalizedStringKey = "Paste a connection URL to fill in the fields"
    static let importURL: LocalizedStringKey = "Import"
    static let importSucceeded: LocalizedStringKey = "Fields filled from the connection string."
    static let importFromClipboard: LocalizedStringKey = "Fields filled from the connection string on your clipboard."
    static let importUnrecognized: LocalizedStringKey = "That connection string format isn't recognized for this engine."
    static let rememberSecrets: LocalizedStringKey = "Remember secrets on this Mac"
    static let chooseFile: LocalizedStringKey = "Choose…"
    static let importKeyFile: LocalizedStringKey = "Import Key File…"
    static let fieldHint: LocalizedStringKey = "Connection setting"
    static let cancel: LocalizedStringKey = "Cancel"
    static let test: LocalizedStringKey = "Test"
    static let save: LocalizedStringKey = "Save"
    static let saveHint: LocalizedStringKey = "Saves this connection on this Mac without connecting"
    static let testHint: LocalizedStringKey = "Checks the connection without opening it"
    static let connect: LocalizedStringKey = "Connect"
    static let connectHint: LocalizedStringKey = "Opens this connection in the window"
    static let connectionUnavailable: LocalizedStringKey = "Couldn't reach the database with these details."
    static func connectionSucceeded(_ count: Int) -> LocalizedStringKey { "Connected — \(count) objects found." }
    static let disconnect: LocalizedStringKey = "Disconnect"
    static let disconnectHelp: LocalizedStringKey = "Close this connection and return to the engine list (⇧⌘W)"

    static func title(for filterOperator: FilterOperator) -> LocalizedStringKey {
        switch filterOperator {
        case .equals: "equals"
        case .notEquals: "not equals"
        case .lessThan: "less than"
        case .greaterThan: "greater than"
        case .lessThanOrEqual: "less than or equal"
        case .greaterThanOrEqual: "greater than or equal"
        case .contains: "contains"
        case .notContains: "does not contain"
        case .beginsWith: "begins with"
        case .endsWith: "ends with"
        case .inList: "in list"
        case .notInList: "not in list"
        case .isNull: "is null"
        case .isNotNull: "is not null"
        }
    }

    static func title(for kind: DatabaseObjectKind) -> LocalizedStringKey {
        switch kind {
        case .table: "Table"
        case .partitionedTable: "Partitioned Table"
        case .view: "View"
        case .materializedView: "Materialized View"
        case .foreignTable: "Foreign Table"
        case .collection: "Collection"
        case .index: "Index"
        case .keyspace: "Keyspace"
        }
    }

    static func title(for field: ConnectionField) -> LocalizedStringKey {
        switch field {
        case .name: "Name"
        case .url: "URL"
        case .host: "Host"
        case .port: "Port"
        case .username: "User"
        case .password: "Password"
        case .database: "Database"
        case .schema: "Schema"
        case .filePath: "File"
        case .tlsMode: "TLS"
        case .serviceName: "Service Name"
        case .role: "Role"
        case .account: "Account"
        case .warehouse: "Warehouse"
        case .projectID: "Project ID"
        case .dataset: "Dataset"
        case .serviceAccountJSON: "Service Account Key"
        case .endpoint: "Endpoint"
        case .region: "Region"
        case .accessKeyID: "Access Key ID"
        case .secretAccessKey: "Secret Access Key"
        case .accountID: "Account ID"
        case .databaseID: "Database ID"
        case .apiToken: "Token"
        case .keyspace: "Keyspace"
        case .fileBookmark: "File"
        }
    }

    static func title(for mode: TLSMode) -> LocalizedStringKey {
        switch mode {
        case .disable: "Disable"
        case .prefer: "Prefer"
        case .require: "Require (verify certificate)"
        }
    }

    static func title(for strategy: MatchingStrategy) -> LocalizedStringKey {
        switch strategy {
        case .fuzzy: "Fuzzy"
        case .contains: "Contains"
        case .prefix: "Prefix"
        }
    }

    // Startup configuration, display and store
    static let displaySection: LocalizedStringKey = "Display"
    static let displaySectionDetail: LocalizedStringKey = "Pick a color theme. It applies right away and can be changed in Settings."
    static let storeSection: LocalizedStringKey = "Store"
    static let storeSectionDetail: LocalizedStringKey = "Where saved passwords and the key for saved connections are kept. Switching moves them; nothing is lost."
    static let storeMoving: LocalizedStringKey = "Moving saved passwords…"
    static let storeSwitchFailed: LocalizedStringKey = "Couldn't move saved passwords, so the store wasn't changed."
    static let setupTitle: LocalizedStringKey = "Startup Configuration"
    static let setupSubtitle: LocalizedStringKey = "Choose how query looks and where it keeps your passwords."
    static let setupContinue: LocalizedStringKey = "Get Started"
    static let setupBack: LocalizedStringKey = "Back"
    static let setupNext: LocalizedStringKey = "Next"
    static let setupNextHint: LocalizedStringKey = "Goes to the next step"
    static let setupReadyTitle: LocalizedStringKey = "You're All Set"
    static let setupReadyDetail: LocalizedStringKey = "Here's how query is set up. You can change both in Settings at any time."
    static let themePreviewTitle: LocalizedStringKey = "Customers"
    static let themePreviewDetail: LocalizedStringKey = "12 rows · 4 ms"
    static let themePreviewButton: LocalizedStringKey = "Run"
    static func setupStepTitle(_ step: SetupStep) -> LocalizedStringKey {
        switch step {
        case .language: "Language"
        case .display: "Display"
        case .store: "Store"
        case .ready: "Ready"
        }
    }
    static let setupContinueHint: LocalizedStringKey = "Saves these choices and opens query"
    static let sqlEditorTab: LocalizedStringKey = "Editor"
    static let sqlHistoryTab: LocalizedStringKey = "History"
    static let sqlHistoryEmptyTitle: LocalizedStringKey = "No History Yet"
    static let sqlHistoryEmptyDetail: LocalizedStringKey = "Statements you run on this connection appear here."
    static let runHistoryHint: LocalizedStringKey = "Runs this statement again"
    static let openInEditor: LocalizedStringKey = "Open in Editor"
    static let deleteHistoryItem: LocalizedStringKey = "Remove from History"
    static let clearHistory: LocalizedStringKey = "Clear History"
    static let clearHistoryHint: LocalizedStringKey = "Removes every statement from this connection's history"

    static func themeName(_ theme: AppTheme) -> LocalizedStringKey {
        switch theme {
        case .classic: "Classic"
        case .midnightHarbor: "Midnight Harbor"
        case .sunlitTerracotta: "Sunlit Terracotta"
        case .mintJulep: "Mint Julep"
        case .auroraBorealis: "Aurora Borealis"
        case .desertDusk: "Desert Dusk"
        case .lavenderFields: "Lavender Fields"
        case .emberGlow: "Ember Glow"
        case .glacier: "Glacier"
        case .matchaLatte: "Matcha Latte"
        case .neonArcade: "Neon Arcade"
        case .cherryBlossom: "Cherry Blossom"
        }
    }

    static func themeDescription(_ theme: AppTheme) -> LocalizedStringKey {
        switch theme {
        case .classic: "The system's own colors."
        case .midnightHarbor: "Deep navy with harbor-light blue. Always dark."
        case .sunlitTerracotta: "Warm clay on cream. Always light."
        case .mintJulep: "Cool mint on a fresh green wash."
        case .auroraBorealis: "Northern-lights green over a polar night. Always dark."
        case .desertDusk: "Sunset amber on sandstone."
        case .lavenderFields: "Soft violet on a lilac haze. Always light."
        case .emberGlow: "Glowing orange on charcoal. Always dark."
        case .glacier: "Icy blue on frost white. Always light."
        case .matchaLatte: "Earthy green on oat milk."
        case .neonArcade: "Hot pink on a midnight arcade cabinet. Always dark."
        case .cherryBlossom: "Sakura pink on petal white. Always light."
        }
    }

    static func storeName(_ kind: SecretStoreKind) -> LocalizedStringKey {
        switch kind {
        case .sqlite: "SQLite File (Recommended)"
        case .keychain: "macOS Keychain"
        }
    }

    static func storeDescription(_ kind: SecretStoreKind) -> LocalizedStringKey {
        switch kind {
        case .sqlite: "Saved passwords go in a file in the app's container. macOS never asks for your password, but the file isn't encrypted by the system."
        case .keychain: "Saved passwords are encrypted by macOS. While builds are signed to run locally, macOS may ask for your login password after each new build."
        }
    }

    // What's New
    static let whatsNewTitle: LocalizedStringKey = "What's New"
    static let whatsNewMenu: LocalizedStringKey = "What's New…"
    static let whatsNewContinue: LocalizedStringKey = "Continue"
    static let releaseNotesVersion: LocalizedStringKey = "Version"
    static let releaseNotesVersionHint: LocalizedStringKey = "Shows the notes for another release"
    static let noReleaseNotes: LocalizedStringKey = "No Release Notes"
    static let noReleaseNotesDetail: LocalizedStringKey = "This build doesn't include a changelog."
    static func releaseVersion(_ version: String) -> LocalizedStringKey { "Version \(version)" }
    static func releaseVersionDate(_ version: String, _ date: String) -> LocalizedStringKey { "Version \(version) · \(date)" }
    static func changeCount(_ count: Int) -> LocalizedStringKey { "\(count) changes" }

    static func title(for category: ChangelogCategory) -> Text {
        switch category {
        case .newFeatures: Text("New Features")
        case .uiChanges: Text("UI Changes")
        case .improvements: Text("Improvements")
        case .bugFixes: Text("Bug Fixes")
        case .security: Text("Security")
        case .removed: Text("Removed")
        case .other(let heading): Text(verbatim: heading)
        }
    }

    // Row editor and SQL files
    static let rowTab: LocalizedStringKey = "Row"
    static let selectRowTitle: LocalizedStringKey = "No Row Selected"
    static let selectRowDetail: LocalizedStringKey = "Select a row in a table to see and edit its values here."
    static let rowSave: LocalizedStringKey = "Save"
    static let rowSaveHint: LocalizedStringKey = "Updates this row in the database (⌘S)"
    static let rowRevert: LocalizedStringKey = "Revert"
    static let rowRevertHint: LocalizedStringKey = "Puts back the values from the database"
    static let rowSaved: LocalizedStringKey = "Saved"
    static let rowSaving: LocalizedStringKey = "Saving…"
    static let rowSaveFailed: LocalizedStringKey = "Couldn't save the row."
    static let rowNullHint: LocalizedStringKey = "Sets this field to NULL"
    static let rowKeyColumn: LocalizedStringKey = "Primary key"
    static let rowFieldChanged: LocalizedStringKey = "Changed"
    static let rowMatchedByAll: LocalizedStringKey = "No primary key: Save matches the row on every column's original value."
    static let rowReadOnly: LocalizedStringKey = "This connection can't edit rows."
    static let openSQLFile: LocalizedStringKey = "Open SQL File…"
    static let openSQLFileHint: LocalizedStringKey = "Adds a .sql file's statements to the editor (⌘O)"
    static let sqlImportFailed: LocalizedStringKey = "Couldn't open that file. It may be too large or not text."
    static func rowMatchedByKey(_ columns: String) -> LocalizedStringKey { "Save matches the row by its primary key: \(columns)" }

    // Language
    static let languageSection: LocalizedStringKey = "Language"
    static let languageSectionDetail: LocalizedStringKey = "Choose the language query uses. It applies right away and can be changed in Settings."
    static let languageSystem: LocalizedStringKey = "System Default"
    static let languageSystemDetail: LocalizedStringKey = "Uses the language order in System Settings."
    static let languageRelaunchNote: LocalizedStringKey = "Menus and a few labels switch after you restart query."
}
