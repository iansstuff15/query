import Foundation
import Observation
import os

/// The Row tab: the selected row's fields, editable where the database allows it (generated
/// columns, always-generated identities and columns the user can't update are read-only), and
/// Save, which updates that row (matched by primary key, or by every column's original value
/// when there is none).
@MainActor
@Observable
final class RowEditorViewModel {
    let object: DatabaseObject
    /// The row's position in the grid, so a reload can refresh the same row.
    let rowID: ResultRow.ID
    var fields: [RowField]
    private(set) var saveState: SaveState = .idle
    /// `nil` until loaded.
    private(set) var keyColumns: [String]?
    /// Columns the user can change; `nil` when unknown (everything is treated as editable).
    private(set) var editableColumns: Set<String>?
    private var hasLoadedDetails = false

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

    /// Whether a field can be changed here (shown as an input) or only read.
    func isEditable(_ field: RowField) -> Bool {
        canEdit && (editableColumns?.contains(field.column.name) ?? true)
    }

    /// False when every field is read-only, so there's nothing to save.
    var canEditAnything: Bool { canEdit && fields.contains(where: isEditable) }

    var hasChanges: Bool { fields.contains { isEditable($0) && $0.isChanged } }

    var canSave: Bool { canEdit && hasChanges && saveState != .saving }

    /// Loads the primary key and which columns can be edited.
    func loadKey() async {
        guard !hasLoadedDetails, let updater else { return }
        hasLoadedDetails = true
        do {
            keyColumns = try await updater.primaryKey(of: object)
        } catch {
            AppLog.database.error("Reading the primary key failed: \(String(describing: error), privacy: .private)")
            keyColumns = []
        }
        do {
            editableColumns = try await updater.editableColumns(of: object)
        } catch {
            AppLog.database.error("Reading editable columns failed: \(String(describing: error), privacy: .private)")
            editableColumns = nil
        }
    }

    func setNull(_ isNull: Bool, for fieldID: RowField.ID) {
        guard let index = fields.firstIndex(where: { $0.id == fieldID }), isEditable(fields[index]) else { return }
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
            object: object, columns: columns, original: fields.map(\.original),
            // Read-only fields always keep their original value.
            values: fields.map { isEditable($0) ? $0.value : $0.original }, keyColumns: keyColumns ?? []
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
