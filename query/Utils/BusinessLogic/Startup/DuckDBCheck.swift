import DuckDB
import Foundation

/// The bundled DuckDB engine opens an in-memory database and reports its version.
nonisolated struct DuckDBCheck: StartupCheck {
    var id: StartupCheckID { .duckDB }

    func run() async -> StartupCheckOutcome {
        do {
            let connection = try Database(store: .inMemory).connect()
            let result = try connection.query("SELECT version()")
            return .passed(detail: result[0].cast(to: String.self)[0])
        } catch {
            return .degraded(reason: String(describing: error))
        }
    }
}
