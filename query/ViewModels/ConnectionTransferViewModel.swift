import Foundation
import Observation
import os

/// Export / import of saved connections, with optional passphrase-encrypted passwords.
@MainActor
@Observable
final class ConnectionTransferViewModel {
    enum Status: Equatable {
        case idle
        case exported(Int)
        case imported(Int)
        case needsPassphrase
        case wrongPassphrase
        case unreadable
        case passphraseTooShort
        case passphrasesDiffer
    }

    var includeSecrets = false
    var passphrase = ""
    var confirmation = ""
    var importPassphrase = ""
    private(set) var status: Status = .idle
    private(set) var document: ConnectionArchiveDocument?
    /// Encrypted import awaiting a passphrase.
    private(set) var pendingImport: Data?

    private let store: any ConnectionStore
    private let archive: ConnectionArchive

    init(store: any ConnectionStore, archive: ConnectionArchive = ConnectionArchive()) {
        self.store = store
        self.archive = archive
    }

    var needsPassphrase: Bool { includeSecrets }

    /// Builds the export file; returns false when validation fails.
    func prepareExport() -> Bool {
        if includeSecrets {
            guard passphrase.count >= ConnectionArchive.minimumPassphraseLength else {
                status = .passphraseTooShort
                return false
            }
            guard passphrase == confirmation else {
                status = .passphrasesDiffer
                return false
            }
        }
        do {
            let entries = try store.exportEntries()
            document = ConnectionArchiveDocument(data: try archive.export(
                entries, includeSecrets: includeSecrets, passphrase: includeSecrets ? passphrase : nil
            ))
            status = .exported(entries.count)
            return true
        } catch {
            AppLog.keychain.error("Export failed: \(String(describing: error), privacy: .private)")
            status = .unreadable
            return false
        }
    }

    func finishExport() {
        passphrase = ""
        confirmation = ""
        document = nil
    }

    func beginImport(_ data: Data) {
        do {
            if try archive.isEncrypted(data) {
                pendingImport = data
                status = .needsPassphrase
            } else {
                try complete(data, passphrase: nil)
            }
        } catch {
            status = .unreadable
        }
    }

    func submitImportPassphrase() {
        guard let pendingImport else { return }
        do {
            try complete(pendingImport, passphrase: importPassphrase)
        } catch ConnectionArchiveError.wrongPassphrase {
            status = .wrongPassphrase
        } catch {
            status = .unreadable
        }
    }

    func cancelImport() {
        pendingImport = nil
        importPassphrase = ""
        status = .idle
    }

    private func complete(_ data: Data, passphrase: String?) throws {
        let entries = try archive.entries(from: data, passphrase: passphrase)
        let count = try store.importEntries(entries)
        pendingImport = nil
        importPassphrase = ""
        status = .imported(count)
    }
}
