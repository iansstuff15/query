import Foundation

/// The connection vault key exists and AES-GCM round-trips.
nonisolated struct EncryptionCheck: StartupCheck {
    let cipher: any ConnectionCipher
    var id: StartupCheckID { .encryption }

    func run() async -> StartupCheckOutcome {
        let sample = Data("query".utf8)
        do {
            guard try cipher.open(try cipher.seal(sample)) == sample else {
                return .degraded(reason: "round trip mismatch")
            }
            return .passed(detail: "AES-256-GCM")
        } catch {
            return .degraded(reason: String(describing: error))
        }
    }
}
