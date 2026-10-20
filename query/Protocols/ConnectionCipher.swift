import Foundation

/// Authenticated encryption for connection details stored on disk.
nonisolated protocol ConnectionCipher: Sendable {
    func seal(_ plaintext: Data) throws -> Data
    func open(_ sealed: Data) throws -> Data
}
