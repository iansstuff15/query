import Foundation

/// The selected secret store (SQLite file or Keychain) can write, read back and remove a secret.
nonisolated struct KeychainCheck: StartupCheck {
    static let probeAccount = "startup-probe"
    let credentials: any CredentialStore
    var id: StartupCheckID { .keychain }

    func run() async -> StartupCheckOutcome {
        let token = UUID().uuidString
        do {
            try credentials.setPassword(token, for: Self.probeAccount)
            defer { try? credentials.setPassword("", for: Self.probeAccount) }
            guard credentials.password(for: Self.probeAccount) == token else {
                return .degraded(reason: "probe read back a different value")
            }
            return .passed(detail: nil)
        } catch {
            return .degraded(reason: String(describing: error))
        }
    }
}
