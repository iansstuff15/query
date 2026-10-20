import Foundation

/// Mirrors libpq `sslmode`: `prefer` encrypts without verifying, `require` verifies the certificate and host.
nonisolated enum TLSMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case disable
    case prefer
    case require

    var id: String { rawValue }
}
