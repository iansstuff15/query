import Foundation

/// Where the app keeps saved passwords and the key that encrypts saved connections.
nonisolated enum SecretStoreKind: String, CaseIterable, Identifiable, Sendable {
    /// A SQLite file in the app's container. The default: no system prompts.
    case sqlite
    /// The macOS login Keychain. Opt-in: encrypted by the system, but macOS may ask for your
    /// password when a new build of the app reads it.
    case keychain

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .sqlite: "externaldrive"
        case .keychain: "key"
        }
    }
}
