import Foundation
import Observation
import os

/// The connection sheet: per-engine fields, connection-string import (typed, pasted or picked up
/// from the clipboard), Test and Connect.
@MainActor
@Observable
final class ConnectionFormViewModel: Identifiable {
    enum ImportResult: Equatable {
        case none
        case imported
        /// Filled from a connection string found on the clipboard when the sheet opened.
        case pasted
        case invalid
    }

    let id = UUID()
    let descriptor: EngineDescriptor
    var draft: ConnectionDraft
    var name: String
    var connectionString = ""
    var rememberSecrets = true
    private(set) var importResult: ImportResult = .none
    /// Number of objects found by the last test.
    private(set) var testState: LoadState<Int> = .idle
    private(set) var isConnecting = false
    private(set) var didSave = false

    private var savedID: UUID?
    private let initialDraft: ConnectionDraft
    /// The connection string last applied to the fields, so it isn't re-applied over manual edits.
    private var appliedConnectionString: String?
    /// Fields the last applied connection string set.
    private var importedFields: Set<ConnectionField> = []
    private let factory: any DatabaseClientFactory
    private let store: any ConnectionStore
    private let clipboard: any ClipboardReading

    convenience init(
        engine: DatabaseEngine, factory: any DatabaseClientFactory, store: any ConnectionStore,
        clipboard: any ClipboardReading = EmptyClipboard()
    ) {
        let descriptor = EngineCatalog.descriptor(for: engine)
        var values = descriptor.defaultValues
        if let port = descriptor.defaultPort, descriptor.fields.contains(.port) { values[.port] = String(port) }
        self.init(
            draft: ConnectionDraft(engine: engine, values: values), name: "", savedID: nil, factory: factory, store: store,
            clipboard: clipboard
        )
    }

    init(
        draft: ConnectionDraft, name: String, savedID: UUID?, factory: any DatabaseClientFactory, store: any ConnectionStore,
        clipboard: any ClipboardReading = EmptyClipboard()
    ) {
        descriptor = EngineCatalog.descriptor(for: draft.engine)
        self.draft = draft
        initialDraft = draft
        self.name = name
        self.savedID = savedID
        self.factory = factory
        self.store = store
        self.clipboard = clipboard
    }

    /// The connection-string field's text; for URL-first engines that is the URL field itself.
    /// Typing applies it straight away, so Import is optional.
    var connectionStringInput: String {
        get { descriptor.isURLFirst ? draft[.url] : connectionString }
        set {
            if descriptor.isURLFirst {
                // Importing rewrites the URL (credentials move to their own fields), so URL-first
                // engines import on submit or before Test / Save / Connect, not mid-typing.
                draft[.url] = newValue
            } else {
                connectionString = newValue
                applyConnectionString(reportingInvalid: false)
            }
        }
    }

    var visibleFields: [ConnectionField] {
        descriptor.fields.filter { !(descriptor.isURLFirst && $0 == .url) }
    }

    /// Required values present, so Test / Connect can be enabled.
    var canConnect: Bool {
        descriptor.requiredFields.allSatisfy { draft.value($0) != nil }
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return draft.value(.host) ?? draft.value(.filePath).map { URL(filePath: $0).lastPathComponent }
            ?? draft.value(.url) ?? draft.value(.projectID) ?? draft.value(.account) ?? descriptor.displayName
    }

    func importConnectionString() {
        applyConnectionString(reportingInvalid: true, force: true)
    }

    /// Fills the connection string from the clipboard when a new, untouched form opens and the
    /// clipboard holds a connection string for this engine.
    func pickUpClipboard() {
        guard savedID == nil, descriptor.acceptsConnectionString, draft == initialDraft, connectionString.isEmpty,
              let text = clipboard.unseenString(),
              let detected = ConnectionStringDetector.detect(text, for: descriptor.engine)
        else { return }
        if descriptor.isURLFirst { draft[.url] = detected } else { connectionString = detected }
        if applyConnectionString(reportingInvalid: false) { importResult = .pasted }
    }

    /// Parses the connection string into the fields. Fields set by a previous import that the new
    /// string no longer mentions go back to their defaults. Returns whether the string was recognized.
    /// - Parameter announcing: show the "fields filled" note on success (off for the silent apply
    ///   before Test / Save / Connect).
    @discardableResult
    private func applyConnectionString(reportingInvalid: Bool, force: Bool = false, announcing: Bool = true) -> Bool {
        let input = connectionStringInput
        guard force || input != appliedConnectionString else { return true }
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if announcing { importResult = .none }
            return false
        }
        do {
            let parsed = try ConnectionStringParser.parse(input, for: descriptor.engine)
            for field in importedFields.subtracting(parsed.keys) where !(descriptor.isURLFirst && field == .url) {
                draft[field] = defaultValue(for: field)
            }
            for (field, value) in parsed { draft[field] = value }
            importedFields = Set(parsed.keys)
            appliedConnectionString = connectionStringInput
            if announcing { importResult = .imported }
            testState = .idle
            return true
        } catch {
            if reportingInvalid {
                AppLog.database.info("Connection string not recognized: \(String(describing: error), privacy: .public)")
                importResult = .invalid
            } else if announcing {
                importResult = .none
            }
            return false
        }
    }

    private func defaultValue(for field: ConnectionField) -> String {
        if let value = descriptor.defaultValues[field] { return value }
        if field == .port, let port = descriptor.defaultPort { return String(port) }
        return ""
    }

    func setFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        draft[.filePath] = url.path
        draft[.fileBookmark] = (try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil))?
            .base64EncodedString() ?? ""
    }

    func test() async {
        applyConnectionString(reportingInvalid: true, announcing: false)
        testState = .loading
        do {
            let client = try factory.makeClient(for: draft)
            let objects = try await client.listObjects()
            await client.close()
            testState = .loaded(objects.count)
        } catch {
            AppLog.database.error("Connection test failed: \(String(describing: error), privacy: .private)")
            testState = .failed(error)
        }
    }

    /// Saves the configuration without connecting (secrets go to the Keychain if remembered).
    func save() {
        applyConnectionString(reportingInvalid: true, announcing: false)
        do {
            savedID = try store.save(draft, name: displayName, id: savedID, rememberSecrets: rememberSecrets)
            didSave = true
        } catch {
            AppLog.database.error("Saving connection failed: \(String(describing: error), privacy: .private)")
            didSave = false
        }
    }

    /// Verifies the connection, saves it, and returns a session, or `nil` on failure.
    func connect() async -> ConnectionSession? {
        applyConnectionString(reportingInvalid: true, announcing: false)
        isConnecting = true
        defer { isConnecting = false }
        do {
            let client = try factory.makeClient(for: draft)
            _ = try await client.listObjects()
            let id = (try? store.save(draft, name: displayName, id: savedID, rememberSecrets: rememberSecrets)) ?? UUID()
            savedID = id
            return ConnectionSession(id: id, name: displayName, engine: descriptor.engine, client: client)
        } catch {
            AppLog.database.error("Connect failed: \(String(describing: error), privacy: .private)")
            testState = .failed(error)
            return nil
        }
    }
}
