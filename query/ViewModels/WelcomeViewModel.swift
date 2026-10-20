import Foundation
import Observation
import os

/// First screen: the engine grid (filterable), the recent-connections column with each
/// connection's reachability, and which connection sheet is open.
@MainActor
@Observable
final class WelcomeViewModel {
    var query = ""
    var presentedForm: ConnectionFormViewModel?
    private(set) var health: [UUID: ConnectionHealth] = [:]
    /// The recent connection being opened, if any.
    private(set) var connectingID: UUID?

    private let factory: any DatabaseClientFactory
    private let store: any ConnectionStore
    private let clipboard: any ClipboardReading
    private let checkTimeout: Duration
    /// `ENABLE_CONNECTION_HEALTH_CHECKS`; off leaves every recent connection clickable and unmarked.
    private let checksHealth: Bool

    init(
        factory: any DatabaseClientFactory, store: any ConnectionStore, clipboard: any ClipboardReading = EmptyClipboard(),
        checkTimeout: Duration = AppConfig.connectionCheckTimeout, checksHealth: Bool = true
    ) {
        self.factory = factory
        self.store = store
        self.clipboard = clipboard
        self.checkTimeout = checkTimeout
        self.checksHealth = checksHealth
    }

    func health(of connection: SavedConnection) -> ConnectionHealth {
        health[connection.id] ?? .unknown
    }

    var engines: [EngineDescriptor] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return EngineCatalog.all }
        let matcher = TextMatcher(strategy: .fuzzy)
        return EngineCatalog.all
            .compactMap { descriptor in matcher.match(trimmed, in: descriptor.displayName).map { (descriptor, $0.score) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    func choose(_ engine: DatabaseEngine) {
        presentedForm = ConnectionFormViewModel(engine: engine, factory: factory, store: store, clipboard: clipboard)
    }

    /// Tries every connection at once and records which ones answer within the timeout.
    func checkHealth(of connections: [SavedConnection]) async {
        guard checksHealth else { return }
        let targets = connections.filter { $0.engine != nil }.map { ($0.id, store.draft(for: $0)) }
        for (id, _) in targets { health[id] = .checking }
        let factory = factory
        let timeout = checkTimeout
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for (id, draft) in targets {
                group.addTask { (id, await Self.answers(draft, factory: factory, timeout: timeout)) }
            }
            for await (id, reachable) in group {
                health[id] = reachable ? .reachable : .unreachable
            }
        }
    }

    /// Opens a recent connection straight into its workspace, or returns `nil` (marking it
    /// unreachable) when it can't connect.
    func connect(_ connection: SavedConnection) async -> ConnectionSession? {
        guard health(of: connection).canOpen, connectingID == nil, let engine = connection.engine else { return nil }
        connectingID = connection.id
        defer { connectingID = nil }
        let draft = store.draft(for: connection)
        do {
            let client = try factory.makeClient(for: draft)
            let timeout = checkTimeout
            do {
                _ = try await Deadline.run(timeout) { try await client.listObjects() }
            } catch {
                await client.close()
                throw error
            }
            // Re-saving bumps "last used"; secrets stay remembered only if they already were.
            let rememberSecrets = !draft.secretValues.isEmpty
            _ = try? store.save(draft, name: connection.name, id: connection.id, rememberSecrets: rememberSecrets)
            health[connection.id] = .reachable
            return ConnectionSession(id: connection.id, name: connection.name, engine: engine, client: client)
        } catch {
            AppLog.database.error("Opening a recent connection failed: \(String(describing: error), privacy: .private)")
            health[connection.id] = .unreachable
            return nil
        }
    }

    /// Opens the connection sheet to change a saved connection's details.
    func reopen(_ connection: SavedConnection) {
        presentedForm = ConnectionFormViewModel(
            draft: store.draft(for: connection), name: connection.name, savedID: connection.id, factory: factory, store: store
        )
    }

    func delete(_ connection: SavedConnection) {
        health[connection.id] = nil
        try? store.delete(connection)
    }

    private nonisolated static func answers(
        _ draft: ConnectionDraft, factory: any DatabaseClientFactory, timeout: Duration
    ) async -> Bool {
        guard let client = try? factory.makeClient(for: draft) else { return false }
        let reachable = (try? await Deadline.run(timeout) { try await client.listObjects() }) != nil
        await client.close()
        return reachable
    }
}
