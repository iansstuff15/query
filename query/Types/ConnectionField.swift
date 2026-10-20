import Foundation

/// A value on an engine's connection form.
nonisolated enum ConnectionField: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case name
    case url
    case host
    case port
    case username
    case password
    case database
    case schema
    case filePath
    case tlsMode
    case serviceName
    case role
    case account
    case warehouse
    case projectID
    case dataset
    case serviceAccountJSON
    case endpoint
    case region
    case accessKeyID
    case secretAccessKey
    case accountID
    case databaseID
    case apiToken
    case keyspace
    /// Base64 security-scoped bookmark for a file picked in the open panel (not shown on forms).
    case fileBookmark

    var id: String { rawValue }

    /// Secrets are kept out of SwiftData and stored in the Keychain.
    var isSecret: Bool {
        switch self {
        case .password, .serviceAccountJSON, .secretAccessKey, .apiToken: true
        default: false
        }
    }
}
