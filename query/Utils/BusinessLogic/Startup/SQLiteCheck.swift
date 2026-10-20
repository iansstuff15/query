import Foundation
import SQLite3

/// The system SQLite library loads and runs a query.
nonisolated struct SQLiteCheck: StartupCheck {
    var id: StartupCheckID { .sqlite }

    func run() async -> StartupCheckOutcome {
        var database: OpaquePointer?
        guard sqlite3_open_v2(":memory:", &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let database else {
            return .degraded(reason: "sqlite3_open_v2 failed")
        }
        defer { sqlite3_close_v2(database) }
        guard sqlite3_exec(database, "SELECT 1", nil, nil, nil) == SQLITE_OK else {
            return .degraded(reason: String(cString: sqlite3_errmsg(database)))
        }
        return .passed(detail: String(cString: sqlite3_libversion()))
    }
}
