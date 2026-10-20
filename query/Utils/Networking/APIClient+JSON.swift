import Foundation
import os

nonisolated extension APIClient {
    /// Sends `request` and decodes a JSON object, mapping non-2xx responses to `queryFailed`.
    func json(_ request: URLRequest, engine: String) async throws -> [String: Any] {
        let data = try await checkedData(request, engine: engine)
        return try JSONText.object(data)
    }

    func checkedData(_ request: URLRequest, engine: String) async throws -> Data {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await send(request)
        } catch {
            AppLog.database.error("\(engine, privacy: .public) request failed: \(String(reflecting: error), privacy: .private)")
            throw DatabaseError.connectionFailed
        }
        guard (200..<300).contains(response.statusCode) else {
            AppLog.database.error(
                "\(engine, privacy: .public) returned \(response.statusCode): \(String(decoding: data.prefix(2_000), as: UTF8.self), privacy: .private)"
            )
            throw response.statusCode == 401 || response.statusCode == 403 ? DatabaseError.connectionFailed : DatabaseError.queryFailed
        }
        return data
    }
}
