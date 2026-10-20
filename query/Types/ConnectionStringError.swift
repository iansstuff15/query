import Foundation

nonisolated enum ConnectionStringError: Error, Equatable, Sendable {
    case unsupportedEngine
    case malformed
    case schemeMismatch(expected: [String], found: String)
}
