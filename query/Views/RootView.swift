import SwiftData
import SwiftUI

/// A window: the engine picker until a connection opens, then its workspace. Shows What's New
/// once after an update, and from Help ▸ What's New.
struct RootView: View {
    @State private var model = SessionViewModel()
    @State private var whatsNew: WhatsNewViewModel
    @State private var isWhatsNewShown = false
    @AppStorage(SettingsKey.whatsNewSeenVersion) private var seenVersion = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.featureFlags) private var flags
    let factory: any DatabaseClientFactory
    let credentials: any CredentialStore
    let cipher: any ConnectionCipher
    let clipboard: any ClipboardReading
    /// Off under tests, so runs don't depend on what was seen last.
    let opensWhatsNewAutomatically: Bool
    /// `ALWAYS_SHOW_CHANGELOG`: open it at every launch.
    let alwaysOpensWhatsNew: Bool

    init(
        factory: any DatabaseClientFactory, credentials: any CredentialStore, cipher: any ConnectionCipher, clipboard: any ClipboardReading,
        changelog: any ChangelogProviding = BundleChangelogProvider(), opensWhatsNewAutomatically: Bool = false,
        alwaysOpensWhatsNew: Bool = false
    ) {
        self.factory = factory
        self.credentials = credentials
        self.cipher = cipher
        self.clipboard = clipboard
        self.opensWhatsNewAutomatically = opensWhatsNewAutomatically
        self.alwaysOpensWhatsNew = alwaysOpensWhatsNew
        _whatsNew = State(initialValue: WhatsNewViewModel(provider: changelog))
    }

    var body: some View {
        Group {
            if let session = model.session {
                WorkspaceView(
                    session: session, history: SwiftDataSQLHistoryStore(context: modelContext), flags: flags,
                    onDisconnect: { Task { await model.disconnect() } }
                )
                    .id(session.id)
            } else {
                WelcomeView(
                    factory: factory,
                    store: SwiftDataConnectionStore(context: modelContext, credentials: credentials, cipher: cipher),
                    clipboard: clipboard,
                    flags: flags,
                    onConnected: model.open
                )
            }
        }
        .frame(minWidth: Theme.Layout.windowMinWidth, minHeight: Theme.Layout.windowMinHeight)
        .onDisappear { Task { await model.disconnect() } }
        .sheet(isPresented: $isWhatsNewShown, onDismiss: markWhatsNewSeen) {
            WhatsNewView(model: whatsNew) { isWhatsNewShown = false }
        }
        .focusedSceneValue(\.showWhatsNew, { isWhatsNewShown = true })
        .task {
            await whatsNew.load()
            guard opensWhatsNewAutomatically, !WhatsNewViewModel.hasOpenedThisLaunch else { return }
            if WhatsNewViewModel.shouldOpenAutomatically(latest: whatsNew.latestVersion, lastSeen: seenVersion, always: alwaysOpensWhatsNew) {
                WhatsNewViewModel.hasOpenedThisLaunch = true
                isWhatsNewShown = true
            } else if seenVersion.isEmpty {
                // Fresh install: nothing is new yet.
                markWhatsNewSeen()
            }
        }
    }

    private func markWhatsNewSeen() {
        if let latest = whatsNew.latestVersion { seenVersion = latest }
    }
}

#Preview {
    let credentials = EphemeralCredentialStore()
    RootView(
        factory: StubDatabaseClientFactory(), credentials: credentials, cipher: KeychainConnectionCipher(credentials: credentials),
        clipboard: EmptyClipboard()
    )
        .modelContainer(for: [SavedConnection.self, SQLHistoryEntry.self], inMemory: true)
}
