import Foundation

/// Host/port/credentials shared by every TCP-based engine.
nonisolated struct ServerEndpoint: Hashable, Sendable {
    var host: String
    var port: Int
    var username: String?
    var password: String?
    var database: String?
    var tlsMode: TLSMode

    init(host: String, port: Int, username: String? = nil, password: String? = nil, database: String? = nil, tlsMode: TLSMode = .prefer) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.tlsMode = tlsMode
    }

    /// Reads host/port/user/password/database/TLS from a draft, applying the engine's defaults.
    init(draft: ConnectionDraft) throws {
        let descriptor = EngineCatalog.descriptor(for: draft.engine)
        guard let host = draft.value(.host), let port = draft.port(default: descriptor.defaultPort), (1...65_535).contains(port) else {
            throw DatabaseError.missingConfiguration
        }
        self.init(
            host: host,
            port: port,
            username: draft.value(.username),
            password: draft.value(.password),
            database: draft.value(.database) ?? draft.value(.serviceName) ?? draft.value(.keyspace),
            tlsMode: draft.tlsMode
        )
    }
}
