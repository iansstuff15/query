import Foundation
@testable import query

/// Transport-level HTTP stub. Each test registers a handler for its own host, so tests can
/// run in parallel without sharing state.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest, Data) -> (Int, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]
    nonisolated(unsafe) private static var recorded: [String: [(URLRequest, Data)]] = [:]

    static func register(host: String, handler: @escaping Handler) {
        lock.withLock {
            handlers[host] = handler
            recorded[host] = []
        }
    }

    static func requests(for host: String) -> [(URLRequest, Data)] {
        lock.withLock { recorded[host] ?? [] }
    }

    static func client() -> URLSessionAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSessionAPIClient(session: URLSession(configuration: configuration))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.read) ?? Data()
        let host = request.url?.host ?? ""
        let handler = Self.lock.withLock { () -> Handler? in
            Self.recorded[host, default: []].append((request, body))
            return Self.handlers[host]
        }
        let (status, data) = handler?(request, body) ?? (404, Data())
        if let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// Loads JSON fixtures from `queryTests/Fixtures`.
enum FixtureFile {
    private final class Marker {}

    static func data(_ name: String) -> Data {
        guard let url = Bundle(for: Marker.self).url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return Data() }
        return data
    }
}
