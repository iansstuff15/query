import Foundation

/// `URLSession`-backed `APIClient`. Tests inject a session configured with a stub `URLProtocol`.
nonisolated struct URLSessionAPIClient: APIClient {
    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DatabaseError.protocolViolation }
        return (data, http)
    }
}
