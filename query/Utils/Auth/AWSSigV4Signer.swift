import CryptoKit
import Foundation

/// AWS Signature Version 4 request signing (used for DynamoDB's JSON API).
nonisolated struct AWSSigV4Signer: Sendable {
    let accessKeyID: String
    let secretAccessKey: String
    let region: String
    let service: String

    func sign(_ request: inout URLRequest, body: Data, date: Date) {
        guard let url = request.url, let host = url.host else { return }
        let hostHeader = url.port.map { "\(host):\($0)" } ?? host
        let amzDate = Self.format(date, "yyyyMMdd'T'HHmmss'Z'")
        let day = Self.format(date, "yyyyMMdd")
        let payloadHash = Self.hex(SHA256.hash(data: body))
        request.setValue(hostHeader, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")

        var headers: [String: String] = ["host": hostHeader, "x-amz-date": amzDate]
        for (name, value) in request.allHTTPHeaderFields ?? [:] where name.lowercased().hasPrefix("x-amz-") || name.lowercased() == "content-type" {
            headers[name.lowercased()] = value.trimmingCharacters(in: .whitespaces)
        }
        let signedHeaders = headers.keys.sorted().joined(separator: ";")
        let canonicalHeaders = headers.keys.sorted().map { "\($0):\(headers[$0] ?? "")\n" }.joined()
        let path = url.path.isEmpty ? "/" : url.path
        let canonicalRequest = [
            request.httpMethod ?? "POST", path, url.query ?? "", canonicalHeaders, signedHeaders, payloadHash,
        ].joined(separator: "\n")
        let scope = "\(day)/\(region)/\(service)/aws4_request"
        let stringToSign = ["AWS4-HMAC-SHA256", amzDate, scope, Self.hex(SHA256.hash(data: Data(canonicalRequest.utf8)))].joined(separator: "\n")

        var key = SymmetricKey(data: Data("AWS4\(secretAccessKey)".utf8))
        for part in [day, region, service, "aws4_request"] {
            key = SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data(part.utf8), using: key)))
        }
        let signature = Self.hex(HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key))
        request.setValue(
            "AWS4-HMAC-SHA256 Credential=\(accessKeyID)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)",
            forHTTPHeaderField: "Authorization"
        )
    }

    private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
