import Foundation
import Observation
import os

/// The Row tab: the selected row's fields as editable values, and Save, which updates that
/// row (matched by primary key, or by every column's original value when there is none).
@MainActor
@Observable
final class RowEditorViewModel {
    let object: DatabaseObject
    /// The row's position in the grid, so a reload can refresh the same row.
    let rowID: ResultRow.ID
    var fields: [RowField]
    private(set) var saveState: RowSaveState = .idle
    /// `nil` until loaded.
    private(set) var keyColumns: [String]?

    private let columns: [ColumnInfo]
    private let updater: (any RowUpdating)?
    private let onSaved: () async -> Void

    init(
        object: DatabaseObject, columns: [ColumnInfo], row: ResultRow, client: any DatabaseClient,
        onSaved: @escaping () async -> Void = {}
    ) {
        self.object = object
        self.columns = columns
        rowID = row.id
        updater = (client as? any RowUpdating).flatMap { $0.canUpdateRows ? $0 : nil }
        self.onSaved = onSaved
        fields = Self.fields(columns: columns, values: row.values)
    }

    /// Read-only connections and engines without `UPDATE` show the values without Save.
    var canEdit: Bool { updater != nil }

    var hasChanges: Bool { fields.contains(where: \.isChanged) }

    var canSave: Bool { canEdit && hasChanges && saveState != .saving }

    func loadKey() async {
        guard keyColumns == nil, let updater else { return }
        do {
            keyColumns = try await updater.primaryKey(of: object)
        } catch {
            AppLog.database.error("Reading the primary key failed: \(String(describing: error), privacy: .private)")
            keyColumns = []
        }
    }

    func setNull(_ isNull: Bool, for fieldID: RowField.ID) {
        guard let index = fields.firstIndex(where: { $0.id == fieldID }) else { return }
        fields[index].isNull = isNull
        if !isNull, fields[index].original == nil { fields[index].text = "" }
    }

    /// Puts every field back to the loaded value.
    func revert() {
        fields = fields.map { RowField(index: $0.id, column: $0.column, original: $0.original) }
        saveState = .idle
    }

    /// Shows the row as reloaded after a save, keeping the "Saved" status.
    func refresh(with row: ResultRow) {
        fields = Self.fields(columns: columns, values: row.values)
    }

    func save() async {
        guard canSave, let updater else { return }
        await loadKey()
        saveState = .saving
        let change = RowChange(
            object: object, columns: columns, original: fields.map(\.original), values: fields.map(\.value), keyColumns: keyColumns ?? []
        )
        do {
            try await updater.update(change)
            saveState = .saved
            await onSaved()
        } catch {
            AppLog.database.error("Saving a row failed: \(String(describing: error), privacy: .private)")
            let message = if case DatabaseError.statementFailed(let message) = error { message } else { String?.none }
            saveState = .failed(message)
        }
    }

    private static func fields(columns: [ColumnInfo], values: [String?]) -> [RowField] {
        columns.enumerated().map { index, column in
            RowField(index: index, column: column, original: values.indices.contains(index) ? values[index] : nil)
        }
    }
}
