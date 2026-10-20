import Foundation
import Testing
@testable import query

@MainActor
@Suite("ConnectionTransferViewModel")
struct ConnectionTransferViewModelTests {
    private let archive = ConnectionArchive(iterations: 1_000)

    private func makeModel() -> (ConnectionTransferViewModel, RecordingConnectionStore) {
        let store = RecordingConnectionStore()
        store.entries = [ConnectionExportEntry(name: "Prod", engine: .postgreSQL, values: [.host: "db", .password: "pw"])]
        return (ConnectionTransferViewModel(store: store, archive: archive), store)
    }

    @Test func plainExportNeedsNoPassphrase() throws {
        let (model, _) = makeModel()
        #expect(model.prepareExport())
        #expect(model.status == .exported(1))
        let data = try #require(model.document?.data)
        #expect(!String(decoding: data, as: UTF8.self).contains("\"pw\""))
        model.finishExport()
        #expect(model.document == nil)
    }

    @Test func encryptedExportValidatesPassphrase() {
        let (model, _) = makeModel()
        model.includeSecrets = true
        model.passphrase = "short"
        #expect(!model.prepareExport())
        #expect(model.status == .passphraseTooShort)
        model.passphrase = "long enough"
        model.confirmation = "different!!"
        #expect(!model.prepareExport())
        #expect(model.status == .passphrasesDiffer)
        model.confirmation = "long enough"
        #expect(model.prepareExport())
        #expect(model.status == .exported(1))
    }

    @Test func plainImportCompletesImmediately() throws {
        let (model, store) = makeModel()
        model.beginImport(try archive.export(store.entries, includeSecrets: false, passphrase: nil))
        #expect(model.status == .imported(1))
        #expect(store.imported.first?.values["password"] == nil)
    }

    @Test func encryptedImportAsksForPassphrase() throws {
        let (model, store) = makeModel()
        model.beginImport(try archive.export(store.entries, includeSecrets: true, passphrase: "long enough"))
        #expect(model.status == .needsPassphrase)
        #expect(model.pendingImport != nil)
        model.importPassphrase = "wrong one!"
        model.submitImportPassphrase()
        #expect(model.status == .wrongPassphrase)
        model.importPassphrase = "long enough"
        model.submitImportPassphrase()
        #expect(model.status == .imported(1))
        #expect(model.pendingImport == nil)
        #expect(store.imported.first?.values["password"] == "pw")
    }

    @Test func unreadableFilesAndCancel() throws {
        let (model, store) = makeModel()
        model.beginImport(Data("nope".utf8))
        #expect(model.status == .unreadable)
        model.beginImport(try archive.export(store.entries, includeSecrets: true, passphrase: "long enough"))
        model.cancelImport()
        #expect(model.status == .idle)
        #expect(model.pendingImport == nil)
    }
}
