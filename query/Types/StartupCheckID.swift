import Foundation

/// Launch-time verifications shown on the splash screen, in run order.
nonisolated enum StartupCheckID: String, CaseIterable, Identifiable, Hashable, Sendable {
    case connectionStore
    case keychain
    case encryption
    case sqlite
    case duckDB
    case tls
    case cassandraDriver
    case drivers
    case network

    var id: String { rawValue }
}
