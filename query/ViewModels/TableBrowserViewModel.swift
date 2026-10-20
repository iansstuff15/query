import Foundation
import Observation
import os

/// Rows of one table plus its filter bar (filters are sent to the server as SQL), and the
/// selected row, whose fields the Row tab edits.
@MainActor
@Observable
final class TableBrowserViewModel {
    let object: DatabaseObject
    private(set) var columns: [ColumnInfo] = []
    private(set) var resultState: LoadState<QueryResult> = .idle
    var rules: [FilterRule] = []
    private(set) var isFilterBarShown = false
    /// Rules used for the rows on screen; edits only take effect on `applyFilters()`.
    private(set) var appliedRules: [FilterRule] = []
    /// The selected row in the grid; its fields open in the Row tab.
    var selectedRowID: ResultRow.ID? {
        didSet {
            guard oldValue != selectedRowID else { return }
            updateEditor()
        }
    }
    private(set) var editor: RowEditorViewModel?

    private let client: any DatabaseClient
    private let rowLimit: Int
    private var loadGeneration = 0

    init(object: DatabaseObject, client: any DatabaseClient, rowLimit: Int = AppConfig.rowLimit) {
        self.object = object
        self.client = client
        self.rowLimit = rowLimit
    }

    /// The native query `applyFilters()` would run, shown under the filter bar.
    var previewText: String? {
        client.queryPreview(of: object, columns: columns, rules: rules, limit: rowLimit)
    }

    var rowCount: Int { resultState.value?.rows.count ?? 0 }

    func loadIfNeeded() async {
        guard case .idle = resultState else { return }
        await reload()
    }

    func reload() async {
        loadGeneration += 1
        let generation = loadGeneration
        resultState = .loading
        do {
            if columns.isEmpty {
                let fetched = try await client.columns(of: object)
                guard generation == loadGeneration else { return }
                columns = fetched
            }
            let result = try await client.rows(of: object, columns: columns, rules: appliedRules, limit: rowLimit)
            guard generation == loadGeneration else { return }
            resultState = .loaded(result)
            if let selectedRowID, !result.rows.contains(where: { $0.id == selectedRowID }) {
                self.selectedRowID = nil
            } else if let editor, let row = result.rows.first(where: { $0.id == editor.rowID }) {
                editor.refresh(with: row)
            }
        } catch {
            guard generation == loadGeneration else { return }
            AppLog.database.error("Loading rows of \(self.object.id, privacy: .private) failed: \(String(describing: error), privacy: .private)")
            resultState = .failed(error)
        }
    }

    func applyFilters() async {
        appliedRules = rules.filter(\.isActive)
        await reload()
    }

    func clearFilters() async {
        rules = []
        let hadFilters = !appliedRules.isEmpty
        appliedRules = []
        if hadFilters { await reload() }
    }

    var selectedRow: ResultRow? {
        guard let selectedRowID else { return nil }
        return resultState.value?.rows.first { $0.id == selectedRowID }
    }

    private func updateEditor() {
        guard let row = selectedRow else {
            editor = nil
            return
        }
        editor = RowEditorViewModel(object: object, columns: columns, row: row, client: client) { [weak self] in
            await self?.reload()
        }
    }

    func toggleFilterBar() {
        isFilterBarShown.toggle()
        if isFilterBarShown, rules.isEmpty { addRule() }
    }

    func addRule() {
        rules.append(FilterRule())
        isFilterBarShown = true
    }

    func duplicateRule(_ id: FilterRule.ID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        let source = rules[index]
        let copy = FilterRule(column: source.column, filterOperator: source.filterOperator, value: source.value, isEnabled: source.isEnabled)
        rules.insert(copy, at: index + 1)
    }

    func removeRule(_ id: FilterRule.ID) {
        rules.removeAll { $0.id == id }
    }
}
