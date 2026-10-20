//
//  queryApp.swift
//  query
//
//  Created by Diriangen Lempira Powell on 10/17/26.
//

import SwiftData
import SwiftUI

@main
struct queryApp: App {
    private let container = AppEnvironment.makeModelContainer()
    private let factory = AppEnvironment.makeClientFactory()
    private let credentials = AppEnvironment.makeCredentialStore()
    private let clipboard = AppEnvironment.makeClipboard()
    private let cipher: any ConnectionCipher
    private let options = LaunchOptions.current
    private let flags = FeatureFlags.current

    init() {
        cipher = AppEnvironment.makeCipher(credentials: credentials)
    }

    var body: some Scene {
        Window(Text(L10n.appName), id: SceneID.splash) {
            SplashView(
                checks: AppEnvironment.startupChecks(container: container, credentials: credentials, cipher: cipher, factory: factory),
                minimumDuration: options.splashMinimum,
                nextScene: { AppEnvironment.needsSetup(options: options, flags: flags) ? SceneID.setup : SceneID.main }
            )
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .defaultWindowPlacement { _, _ in
            WindowPlacement(.center)
        }
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
        .commandsRemoved()

        Window(Text(L10n.setupTitle), id: SceneID.setup) {
            StartupConfigurationView(switcher: credentials, flags: flags)
                .themed()
                .localized()
        }
        .windowResizability(.contentSize)
        .defaultWindowPlacement { _, _ in
            WindowPlacement(.center)
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        WindowGroup(id: SceneID.main) {
            if let container {
                RootView(
                    factory: factory, credentials: credentials, cipher: cipher, clipboard: clipboard,
                    opensWhatsNewAutomatically: !options.isIsolated, alwaysOpensWhatsNew: flags.alwaysShowChangelog
                )
                    .modelContainer(container)
                    .themed()
                    .localized()
            }
        }
        .defaultSize(width: Theme.Layout.windowDefaultWidth, height: Theme.Layout.windowDefaultHeight)
        .defaultLaunchBehavior(.suppressed)
        .commands {
            WorkspaceCommands()
            ConnectionTransferCommands()
            HelpCommands()
        }

        Settings {
            SettingsView(switcher: credentials, flags: flags)
                .themed()
                .localized()
        }
    }
}
