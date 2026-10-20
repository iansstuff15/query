import Foundation
import SwiftData
import os

/// Saved connections: name and engine in clear, every other non-secret value sealed with
/// `ConnectionCipher`, secrets in the Keychain keyed by connection id.
@MainActor
final class SwiftDataConnectionStore: ConnectionStore {
    private let context: ModelContext
    private let credentials: any CredentialStore
    private let codec: ConnectionValuesCodec
    private let now: () -> Date

    init(context: ModelContext, credentials: any CredentialStore, cipher: any ConnectionCipher, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.credentials = credentials
        codec = ConnectionValuesCodec(cipher: cipher)
        self.now = now
    }

    @discardableResult
    func save(_ draft: ConnectionDraft, name: String, id: UUID?, rememberSecrets: Bool) throws -> UUID {
        let sealed = try codec.encode(draft.nonSecretValues)
        let connection: SavedConnection
        if let id, let existing = try context.fetch(SavedConnectionQueries.byID(id)).first {
            connection = existing
            connection.name = name
            connection.engineRawValue = draft.engine.rawValue
            connection.valuesJSON = sealed
            connection.lastUsedAt = now()
        } else {
            connection = SavedConnection(name: name, engine: draft.engine, sealedValues: sealed, date: now())
            context.insert(connection)
        }
        try context.save()
        storeSecrets(draft, for: connection.id, remember: rememberSecrets)
        return connection.id
    }

    func draft(for connection: SavedConnection) -> ConnectionDraft {
        var values: [ConnectionField: String] = [:]
        do {
            let decoded = try codec.decode(connection.valuesJSON)
            values = decoded.values
            if decoded.wasPlaintext { migrate(connection, values: values) }
        } catch {
            AppLog.keychain.error("Opening saved connection failed: \(String(describing: error), privacy: .private)")
        }
        for field in ConnectionField.allCases where field.isSecret {
            values[field] = credentials.password(for: Self.account(connection.id, field))
        }
        return ConnectionDraft(engine: connection.engine ?? .postgreSQL, values: values)
    }

    func delete(_ connection: SavedConnection) throws {
        for field in ConnectionField.allCases where field.isSecret {
            try? credentials.setPassword("", for: Self.account(connection.id, field))
        }
        context.delete(connection)
        try context.save()
    }

    func exportEntries() throws -> [ConnectionExportEntry] {
        try context.fetch(FetchDescriptor<SavedConnection>(sortBy: [SortDescriptor(\.name)])).compactMap { connection in
            guard let engine = connection.engine else { return nil }
            return ConnectionExportEntry(name: connection.name, engine: engine, values: draft(for: connection).values)
        }
    }

    @discardableResult
    func importEntries(_ entries: [ConnectionExportEntry]) throws -> Int {
        for entry in entries {
            let draft = entry.draft
            try save(draft, name: entry.name, id: nil, rememberSecrets: !draft.secretValues.isEmpty)
        }
        return entries.count
    }

    static func account(_ id: UUID, _ field: ConnectionField) -> String {
        "\(id.uuidString).\(field.rawValue)"
    }

    private func storeSecrets(_ draft: ConnectionDraft, for id: UUID, remember: Bool) {
        for field in ConnectionField.allCases where field.isSecret {
            let value = remember ? (draft.values[field] ?? "") : ""
            do {
                try credentials.setPassword(value, for: Self.account(id, field))
            } catch {
                AppLog.keychain.error("Storing \(field.rawValue, privacy: .public) failed: \(String(describing: error), privacy: .private)")
            }
        }
    }

    /// Re-seals a row written in plaintext by a build before encryption at rest.
    private func migrate(_ connection: SavedConnection, values: [ConnectionField: String]) {
        do {
            connection.valuesJSON = try codec.encode(values)
            try context.save()
        } catch {
            AppLog.keychain.error("Encrypting legacy connection failed: \(String(describing: error), privacy: .private)")
        }
    }
}
