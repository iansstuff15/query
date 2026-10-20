import Foundation

nonisolated enum DatabaseError: Error, Equatable, Sendable {
    /// Host or user not configured in Settings.
    case missingConfiguration
    case connectionFailed
    case queryFailed
    /// The engine has no driver in this build.
    case unsupported
    /// The server answered with an unexpected payload.
    case protocolViolation
    /// The server didn't answer within the allowed time.
    case timedOut
    /// The server rejected a SQL console statement; the message is the server's own, shown in
    /// the console because the user wrote the SQL and needs it to fix the statement.
    case statementFailed(String)
}
