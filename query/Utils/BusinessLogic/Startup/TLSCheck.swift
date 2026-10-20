import Foundation
import NIOSSL

/// BoringSSL (used by the PostgreSQL, MySQL and Oracle drivers) initializes a client context.
nonisolated struct TLSCheck: StartupCheck {
    var id: StartupCheckID { .tls }

    func run() async -> StartupCheckOutcome {
        do {
            _ = try NIOSSLContext(configuration: .makeClientConfiguration())
            return .passed(detail: nil)
        } catch {
            return .degraded(reason: String(describing: error))
        }
    }
}
