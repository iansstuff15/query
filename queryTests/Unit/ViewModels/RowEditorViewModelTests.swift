import Testing
@testable import query

@MainActor
@Suite("RowEditorViewModel")
struct RowEditorViewModelTests {
    private let object = DatabaseObject(schema: "public", name: "customers", kind: .table)
    private let columns = [ColumnInfo(name: "id", dataType: "integer"), ColumnInfo(name: "country", dataType: "text")]
    private let row = ResultRow(id: 3, values: ["7", nil])

    @Test func fieldsStartWithTheRowsValues() {
        let model = RowEditorViewModel(object: object, columns: columns, row: row, client: MockRowUpdater())
        #expect(model.fields.map(\.text) == ["7", ""])
        #expect(model.fields.map(\.isNull) == [false, true])
        #expect(!model.hasChanges)
        #expect(!model.canSave)
        #expect(model.canEdit)
    }

    @Test func savesTheChangedValuesByPrimaryKey() async {
        let updater = MockRowUpdater()
        var savedCount = 0
        let model = RowEditorViewModel(object: object, columns: columns, row: row, client: updater) { savedCount += 1 }
        model.setNull(false, for: 1)
        model.fields[1].text = "GB"
        #expect(model.hasChanges)
        await model.save()
        #expect(model.saveState == .saved)
        #expect(savedCount == 1)
        let change = await updater.changes.first
        #expect(change?.values == ["7", "GB"])
        #expect(change?.original == ["7", nil])
        #expect(change?.keyColumns == ["id"])
        #expect(model.keyColumns == ["id"])
    }

    @Test func aRejectedSaveShowsTheServersMessage() async {
        let model = RowEditorViewModel(
            object: object, columns: columns, row: row, client: MockRowUpdater(failure: "permission denied for table customers")
        )
        model.fields[0].text = "8"
        await model.save()
        #expect(model.saveState == .failed("permission denied for table customers"))
        #expect(model.canSave)
    }

    @Test func revertAndNull() {
        let model = RowEditorViewModel(object: object, columns: columns, row: row, client: MockRowUpdater())
        model.fields[0].text = "8"
        model.setNull(true, for: 0)
        #expect(model.fields[0].value == nil)
        model.revert()
        #expect(model.fields[0].value == "7")
        #expect(!model.hasChanges)
    }

    @Test func readOnlyConnectionsCantSave() async {
        let updater = MockRowUpdater(canUpdateRows: false)
        let model = RowEditorViewModel(object: object, columns: columns, row: row, client: updater)
        #expect(!model.canEdit)
        model.fields[0].text = "8"
        await model.save()
        #expect(model.saveState == .idle)
        #expect(await updater.changes.isEmpty)
        #expect(!RowEditorViewModel(object: object, columns: columns, row: row, client: MockDatabaseClient()).canEdit)
    }

    @Test func refreshingKeepsTheSavedStatus() async {
        let model = RowEditorViewModel(object: object, columns: columns, row: row, client: MockRowUpdater())
        model.fields[1].isNull = false
        model.fields[1].text = "GB"
        await model.save()
        model.refresh(with: ResultRow(id: 3, values: ["7", "GB"]))
        #expect(model.saveState == .saved)
        #expect(model.fields[1].original == "GB")
        #expect(!model.hasChanges)
    }

    // MARK: - Read-only fields

    @Test func fieldsTheUserCantChangeAreReadOnlyAndKeepTheirValue() async {
        let updater = MockRowUpdater(editable: ["country"])
        let model = RowEditorViewModel(object: object, columns: columns, row: row, client: updater)
        await model.loadKey()
        #expect(!model.isEditable(model.fields[0]))
        #expect(model.isEditable(model.fields[1]))
        #expect(model.canEditAnything)
        model.setNull(true, for: 0) // ignored: read-only
        #expect(model.fields[0].value == "7")
        model.fields[0].text = "8" // a read-only field's text never counts as a change
        #expect(!model.hasChanges)
        model.setNull(false, for: 1)
        model.fields[1].text = "GB"
        await model.save()
        #expect(await updater.changes.first?.values == ["7", "GB"])
    }

    @Test func nothingEditableMeansViewOnly() async {
        let model = RowEditorViewModel(object: object, columns: columns, row: row, client: MockRowUpdater(editable: []))
        await model.loadKey()
        #expect(model.canEdit)
        #expect(!model.canEditAnything)
    }

    @Test func unknownEditabilityKeepsEveryFieldEditable() async {
        let model = RowEditorViewModel(object: object, columns: columns, row: row, client: MockRowUpdater(editable: nil))
        await model.loadKey()
        #expect(model.fields.allSatisfy(model.isEditable))
    }
}
