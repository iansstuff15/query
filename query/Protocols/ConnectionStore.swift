import Foundation

/// Persists connections (encrypted SwiftData rows) and their secrets (Keychain).
@MainActor
protocol ConnectionStore {
    /// Saves or updates; returns the connection id.
    @discardableResult
    func save(_ draft: ConnectionDraft, name: String, id: UUID?, rememberSecrets: Bool) throws -> UUID
    func draft(for connection: SavedConnection) -> ConnectionDraft
    func delete(_ connection: SavedConnection) throws
    /// Every saved connection with its values (and secrets when stored).
    func exportEntries() throws -> [ConnectionExportEntry]
    /// Adds connections from an import; returns how many were added.
    @discardableResult
    func importEntries(_ entries: [ConnectionExportEntry]) throws -> Int
}
