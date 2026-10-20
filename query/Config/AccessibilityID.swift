import Foundation

/// Identifiers shared with UI tests (`queryUITests/Screens`).
enum AccessibilityID {
    enum Splash {
        static let window = "splash.window"
        static let version = "splash.version"
        static let progress = "splash.progress"
        static let currentStep = "splash.step"
        static func check(_ raw: String) -> String { "splash.check.\(raw)" }
    }

    enum Welcome {
        static let search = "welcome.search"
        static let grid = "welcome.grid"
        static let empty = "welcome.empty"
        static func engine(_ raw: String) -> String { "welcome.engine.\(raw)" }
        static func recent(_ index: Int) -> String { "welcome.recent.\(index)" }
        static let recentList = "welcome.recentList"
        static let recentEmpty = "welcome.recentEmpty"
        static let recentCheck = "welcome.recentCheck"
        static let recentToggle = "welcome.recentToggle"
    }

    enum Connection {
        static let sheet = "connection.sheet"
        static let connectionString = "connection.url"
        static let importURL = "connection.import"
        static let chooseFile = "connection.chooseFile"
        static let remember = "connection.remember"
        static let status = "connection.status"
        static let cancel = "connection.cancel"
        static let test = "connection.test"
        static let save = "connection.save"
        static let connect = "connection.connect"
        static func field(_ raw: String) -> String { "connection.field.\(raw)" }
    }

    enum Transfer {
        static let importButton = "transfer.import"
        static let exportButton = "transfer.export"
        static let exportSheet = "transfer.exportSheet"
        static let includeSecrets = "transfer.includeSecrets"
        static let passphrase = "transfer.passphrase"
        static let confirmation = "transfer.confirmation"
        static let export = "transfer.exportConfirm"
        static let importPassphrase = "transfer.importPassphrase"
        static let importSubmit = "transfer.importSubmit"
        static let status = "transfer.status"
    }

    enum Sidebar {
        static let searchField = "sidebar.search"
        static let list = "sidebar.list"
        static let skeleton = "sidebar.skeleton"
        static let empty = "sidebar.empty"
        static func row(_ objectID: String) -> String { "sidebar.row.\(objectID)" }
    }

    enum OpenAnything {
        static let panel = "openAnything.panel"
        static let searchField = "openAnything.search"
        static let empty = "openAnything.empty"
        static func result(_ index: Int) -> String { "openAnything.result.\(index)" }
    }

    enum Detail {
        static let placeholder = "detail.placeholder"
        static let results = "detail.results"
        static let skeleton = "detail.skeleton"
        static let empty = "detail.empty"
        static let rowCount = "detail.rowCount"
        static let loadingBar = "detail.loadingBar"
    }

    enum Filter {
        static let bar = "filter.bar"
        static let add = "filter.add"
        static let apply = "filter.apply"
        static let clear = "filter.clear"
        static let sqlPreview = "filter.sqlPreview"
        static func enabled(_ index: Int) -> String { "filter.rule.\(index).enabled" }
        static func column(_ index: Int) -> String { "filter.rule.\(index).column" }
        static func filterOperator(_ index: Int) -> String { "filter.rule.\(index).operator" }
        static func value(_ index: Int) -> String { "filter.rule.\(index).value" }
        static func clone(_ index: Int) -> String { "filter.rule.\(index).clone" }
        static func remove(_ index: Int) -> String { "filter.rule.\(index).remove" }
    }

    enum Toolbar {
        static let openAnything = "toolbar.openAnything"
        static let filters = "toolbar.filters"
        static let refresh = "toolbar.refresh"
        static let disconnect = "toolbar.disconnect"
        static let sqlConsole = "toolbar.sqlConsole"
    }

    enum SQLConsole {
        static let panel = "sql.panel"
        static let editor = "sql.editor"
        static let run = "sql.run"
        static let status = "sql.status"
        static let results = "sql.results"
        static let placeholder = "sql.placeholder"
        static let skeleton = "sql.skeleton"
        static let unsupported = "sql.unsupported"
        static let error = "sql.error"
        static let tabs = "sql.tabs"
        static let resultFooter = "sql.resultFooter"
        static let openFile = "sql.openFile"
        static let importError = "sql.importError"
        static let gutter = "sql.gutter"
        static let runAll = "sql.runAll"
        static let batch = "sql.batch"
        static func batchEntry(_ index: Int) -> String { "sql.batch.\(index)" }
        static let history = "sql.history"
        static let historyEmpty = "sql.historyEmpty"
        static let clearHistory = "sql.clearHistory"
        static func historyItem(_ index: Int) -> String { "sql.history.\(index)" }
    }

    enum Editor {
        static let header = "editor.header"
        static let tabBar = "editor.tabBar"
        static let jumpBar = "editor.jumpBar"
        static let back = "editor.back"
        static let forward = "editor.forward"
        static func tab(_ index: Int) -> String { "editor.tab.\(index)" }
        static func segment(_ index: Int) -> String { "editor.jumpBar.\(index)" }
    }

    enum WhatsNew {
        static let sheet = "whatsNew.sheet"
        static let version = "whatsNew.version"
        static let versionPicker = "whatsNew.versionPicker"
        static let skeleton = "whatsNew.skeleton"
        static let empty = "whatsNew.empty"
        static let done = "whatsNew.done"
        static func section(_ category: ChangelogCategory) -> String {
            switch category {
            case .other(let heading): "whatsNew.section.\(heading)"
            default: "whatsNew.section.\(category)"
            }
        }
    }

    enum RowEditor {
        static let panel = "row.panel"
        static let empty = "row.empty"
        static let save = "row.save"
        static let revert = "row.revert"
        static let status = "row.status"
        static func field(_ column: String) -> String { "row.field.\(column)" }
        static func null(_ column: String) -> String { "row.null.\(column)" }
        static func readOnly(_ column: String) -> String { "row.readOnly.\(column)" }
    }

    enum Setup {
        static let window = "setup.window"
        static let themes = "setup.themes"
        static let storePicker = "setup.storePicker"
        static let storeError = "setup.storeError"
        static let continueButton = "setup.continue"
        static let back = "setup.back"
        static let summary = "setup.summary"
        static let languagePicker = "setup.languagePicker"
        static func language(_ code: String) -> String { "setup.language.\(code)" }
        static func step(_ index: Int) -> String { "setup.step.\(index)" }
        static func theme(_ raw: String) -> String { "setup.theme.\(raw)" }
        static func store(_ raw: String) -> String { "setup.store.\(raw)" }
    }

    enum Settings {
        static let matchingStrategy = "settings.matchingStrategy"
    }
}
