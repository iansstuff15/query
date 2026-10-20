import Foundation
import UniformTypeIdentifiers

/// Reads a `.sql` (or plain-text) file chosen in the open panel or dropped on the SQL editor.
nonisolated enum SQLFileReader {
    enum ReadError: Error, Equatable {
        case tooLarge
        case unreadable
    }

    /// Types the open panel offers: `.sql` files and plain text.
    static let contentTypes: [UTType] = [UTType(filenameExtension: "sql") ?? .plainText, .plainText]

    /// Whether a dropped file looks like SQL.
    static func accepts(_ url: URL) -> Bool {
        ["sql", "txt", "ddl", "psql"].contains(url.pathExtension.lowercased())
    }

    /// The file's text (UTF-8, or Latin-1 when it isn't valid UTF-8), using its security scope
    /// when it has one.
    static func read(_ url: URL, maxBytes: Int = AppConfig.sqlFileMaxBytes) throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maxBytes else { throw ReadError.tooLarge }
        guard let data = try? Data(contentsOf: url) else { throw ReadError.unreadable }
        guard data.count <= maxBytes else { throw ReadError.tooLarge }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        throw ReadError.unreadable
    }
}
