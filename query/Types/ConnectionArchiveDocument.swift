import SwiftUI
import UniformTypeIdentifiers

/// File wrapper for `.fileExporter` / `.fileImporter`.
struct ConnectionArchiveDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw ConnectionArchiveError.unsupportedFormat }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
