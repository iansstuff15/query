import Foundation
import Network

/// Minimal async byte stream over `NWConnection` (TCP, optional TLS) for protocols without a
/// Swift package: RESP (Redis/Valkey) and TDS (SQL Server).
actor TCPStream {
    private let connection: NWConnection
    private var buffer = Data()
    private var isOpen = false

    init(host: String, port: Int, useTLS: Bool, verifyCertificate: Bool = true, applicationProtocols: [String] = []) {
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 10
        let parameters: NWParameters
        if useTLS {
            let tls = NWProtocolTLS.Options()
            for name in applicationProtocols {
                sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, name)
            }
            if !verifyCertificate {
                sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in complete(true) }, .global())
            }
            parameters = NWParameters(tls: tls, tcp: tcp)
        } else {
            parameters = NWParameters(tls: nil, tcp: tcp)
        }
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(clamping: port)) ?? .any,
            using: parameters
        )
    }

    func open() async throws {
        guard !isOpen else { return }
        let connection = connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let resumed = ResumeOnce(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: resumed.resume(with: .success(()))
                case .failed(let error): resumed.resume(with: .failure(error))
                case .waiting(let error): resumed.resume(with: .failure(error)); connection.cancel()
                case .cancelled: resumed.resume(with: .failure(DatabaseError.connectionFailed))
                default: break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
        isOpen = true
    }

    func write(_ data: Data) async throws {
        let connection = connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }

    /// Reads exactly `count` bytes.
    func read(exactly count: Int) async throws -> Data {
        while buffer.count < count {
            try await fill()
        }
        let chunk = buffer.prefix(count)
        buffer.removeFirst(count)
        return Data(chunk)
    }

    /// Reads up to and including `delimiter`, returning the bytes before it.
    func read(until delimiter: Data) async throws -> Data {
        while true {
            if let range = buffer.range(of: delimiter) {
                let line = buffer[buffer.startIndex..<range.lowerBound]
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                return Data(line)
            }
            try await fill()
        }
    }

    func close() {
        connection.cancel()
        isOpen = false
    }

    private func fill() async throws {
        let connection = connection
        let chunk: Data = try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: DatabaseError.connectionFailed)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
        buffer.append(chunk)
    }
}

/// Guards a continuation that several `NWConnection` state callbacks may try to resume.
private nonisolated final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, any Error>?

    init(_ continuation: CheckedContinuation<Void, any Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Void, any Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
