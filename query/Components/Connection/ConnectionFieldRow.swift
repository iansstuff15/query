import SwiftUI
import UniformTypeIdentifiers

/// One input on the connection sheet, rendered according to the field kind.
struct ConnectionFieldRow: View {
    let field: ConnectionField
    @Binding var value: String
    let placeholder: String
    let onPickFile: (URL) -> Void

    @State private var isImporting = false

    var body: some View {
        Group {
            switch field {
            case .password, .secretAccessKey, .apiToken:
                SecureField(text: $value, prompt: Text(verbatim: placeholder)) { Text(L10n.title(for: field)) }
            case .tlsMode:
                Picker(selection: tlsBinding) {
                    ForEach(TLSMode.allCases) { mode in Text(L10n.title(for: mode)).tag(mode) }
                } label: {
                    Text(L10n.title(for: field))
                }
            case .filePath:
                LabeledContent {
                    HStack {
                        TextField(text: $value, prompt: Text(verbatim: placeholder)) { Text(L10n.title(for: field)) }
                            .labelsHidden()
                        Button { isImporting = true } label: { Label(L10n.chooseFile, systemImage: "folder") }
                            .help(L10n.chooseFile)
                            .accessibilityIdentifier(AccessibilityID.Connection.chooseFile)
                    }
                } label: {
                    Text(L10n.title(for: field))
                }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data, .database]) { result in
                    if case .success(let url) = result { onPickFile(url) }
                }
            case .serviceAccountJSON:
                LabeledContent {
                    VStack(alignment: .leading) {
                        TextEditor(text: $value)
                            .font(Theme.Typography.sql)
                            .frame(minHeight: Theme.Layout.jsonEditorHeight)
                        Button { isImporting = true } label: { Label(L10n.importKeyFile, systemImage: "doc.badge.plus") }
                            .help(L10n.importKeyFile)
                    }
                } label: {
                    Text(L10n.title(for: field))
                }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                    guard case .success(let url) = result else { return }
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    if let text = try? String(contentsOf: url, encoding: .utf8) { value = text }
                }
            default:
                TextField(text: $value, prompt: Text(verbatim: placeholder)) { Text(L10n.title(for: field)) }
            }
        }
        .accessibilityHint(L10n.fieldHint)
        .accessibilityIdentifier(AccessibilityID.Connection.field(field.rawValue))
    }

    private var tlsBinding: Binding<TLSMode> {
        Binding(get: { TLSMode(rawValue: value) ?? .prefer }, set: { value = $0.rawValue })
    }
}

extension UTType {
    /// SQLite / DuckDB database files.
    static var database: UTType { UTType(filenameExtension: "sqlite") ?? .data }
}

#Preview {
    @Previewable @State var value = "localhost"
    Form {
        ConnectionFieldRow(field: .host, value: $value, placeholder: "localhost", onPickFile: { _ in })
    }
    .formStyle(.grouped)
}
