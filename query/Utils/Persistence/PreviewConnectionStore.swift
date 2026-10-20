import Foundation

/// No-op store for previews.
@MainActor
final class PreviewConnectionStore: ConnectionStore {
    func save(_ draft: ConnectionDraft, name: String, id: UUID?, rememberSecrets: Bool) throws -> UUID { id ?? UUID() }
    func draft(for connection: SavedConnection) -> ConnectionDraft { ConnectionDraft(engine: connection.engine ?? .postgreSQL) }
    func delete(_ connection: SavedConnection) throws {}
    func exportEntries() throws -> [ConnectionExportEntry] { [] }
    func importEntries(_ entries: [ConnectionExportEntry]) throws -> Int { entries.count }
}
