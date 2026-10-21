# Project Overview
`query` is a native **macOS** application built with SwiftUI and Xcode. It targets macOS only (`SDKROOT = macosx`, deployment target macOS 26.5). Do not add iOS, iPadOS, or visionOS code, targets, or APIs.
The Xcode project lives at `../query.xcodeproj`, and app sources live in this `query/` directory, which is a file-system-synchronized group: files added here are picked up by the target automatically.

# Minimum Technical Requirements (Mandatory)
- Swift (Swift 6 language mode and strict concurrency once the toolchain allows; currently `SWIFT_VERSION = 5.0`)
- SwiftUI for all UI; AppKit only through `NSViewRepresentable`/`NSViewControllerRepresentable` when SwiftUI has no equivalent. Never import UIKit.
- Swift Concurrency (`async`/`await`, `actor`, `@MainActor`) instead of completion handlers or GCD
- Observation (`@Observable`) for view models and state
- SwiftData for local persistence (the ORM for this project)
- Swift Package Manager for dependencies (no CocoaPods/Carthage)
- Swift Testing (`import Testing`) for unit and integration tests, and XCTest/XCUITest for end-to-end UI tests
- Xcode Cloud or `xcodebuild` for CI builds and test runs

# Architectural Requirements (Mandatory)
- `.gitignore` should be based on this project (Xcode, SwiftPM, macOS, secrets).
- Follow MVVM: `Views` render state, `ViewModels` (`@Observable`, `@MainActor`) hold presentation logic, and `Services` handle side effects.
- Functions and services go inside the `Utils` directory, separated by concern (e.g. `Utils/Networking`, `Utils/Persistence`, `Utils/Auth`, `Utils/BusinessLogic`).
- Put custom types (`struct`, `enum`, `typealias`) in `Types`, and protocols in `Protocols`. Prefer protocol extensions and `extension` on existing types over subclassing. Put extensions on Apple types in `Extensions` (e.g. `Extensions/Color+Theme.swift`).
- Every service sits behind a protocol so tests can inject a mock or fake through the initializer.
- Put reusable view styling in custom `ViewModifier`s, `ButtonStyle`s and `LabelStyle`s inside `Styles`, exposed through `View` extensions (e.g. `.cardStyle()`). Do not repeat modifier chains.
- Put animations and transitions as reusable functions, `Animation` constants, `Transition`s or `ViewModifier`s in the `Animations` directory. Honor `@Environment(\.accessibilityReduceMotion)`.
- Colors, fonts, font weights and sizes, spacing, and feature toggles go in the `Config` directory (e.g. `Config/Theme.swift`, `Config/FeatureFlags.swift`). Colors should be defined in `Assets.xcassets` with light, dark and high-contrast variants, and referenced only through `Config`. Use Dynamic Type text styles. Do not hardcode point sizes.
- Network calls use `URLSession` with `async`/`await` through an `APIClient` protocol in `Utils/Networking`. Base URLs come from `Config`, and App Transport Security stays on (HTTPS only).
- Persistence uses SwiftData `@Model` types in `Models`. Put fetch descriptors, predicates and query logic in the `Queries` directory, not inline in views.
- Secrets and API keys come from an untracked `Secrets.xcconfig` (with a committed `Secrets.example.xcconfig`) that is surfaced through `Info.plist` and read via `Config`. Store tokens obtained at runtime in the Keychain, never in `UserDefaults`. Never commit secrets.
- Whenever a block of views is repeated, make it a component under `Components`.
- A set of components composed by a parent is a valid component (e.g. `Header`, `Footer`, `Sections`, `Cards`).
- Each Swift file should declare one primary type. If several types are logically related, group them in a subdirectory inside `Components`.
- Whenever data is being fetched for a view, show a skeleton/placeholder state (e.g. `.redacted(reason: .placeholder)` with a shimmer modifier from `Animations`), and model loading as an enum such as `LoadState<T> { idle, loading, loaded(T), failed(Error) }`.
- Buttons and navigation items should use `Label` with an SF Symbol by default unless told to omit it.
- Navigation shows an SF Symbol with its text too: Settings tabs, the right panel's tabs and the center panel's tabs. Only links in footers and about lists are text alone. Confirmation-dialog buttons are text, as macOS shows them.
- Do not show alerts, toasts, or user-facing logs when errors come from API calls, missing required config values, or missing secrets. Degrade gracefully (empty or fallback state) and log internally through `os.Logger` with privacy annotations (`\(value, privacy: .private)`). Never use `print`.
- All interactive and meaningful views need accessibility support: `accessibilityLabel`, `accessibilityHint`, `accessibilityIdentifier` (also used by UI tests), and correct traits. Images that are only decorative use `accessibilityHidden(true)`.
- Strings shown to users go in a String Catalog (`Localizable.xcstrings`). Do not hardcode user-facing text.
- The app ships in English, Spanish, French, German and Japanese (`es`, `fr`, `de`, `ja`). Every new or changed string gets all four translations in the same change, with the same format specifiers (`%lld`, `%@`) and plural forms where the English has them. Product and protocol names (query, SQL, SQLite, URL…) stay as they are.
- Features that can be switched off read their `ENABLE_…` toggle and tunable limits from `query-Info.plist` through `Config/FeatureFlags.swift` and `Config/AppConfig.swift`; add new ones there rather than reading the plist directly.
- Build for the Mac, not for a phone:
  - Use `WindowGroup`, `Window`, `Settings` (for the Preferences window), `MenuBarExtra` where it fits, and `DocumentGroup` for document-based features.
  - Navigate with `NavigationSplitView` (sidebar + content + detail). Do not use iOS-style tab bars or full-screen push stacks.
  - Expose actions through the menu bar using `.commands { CommandMenu / CommandGroup }`, with keyboard shortcuts (`.keyboardShortcut`) for common actions.
  - Add `.toolbar` items with SF Symbol `Label`s, plus `.help(...)` tooltips.
  - Support resizable windows, with `.frame(minWidth:minHeight:)` and `.defaultSize`. Support multiple windows and state restoration (`@SceneStorage`).
  - Support pointer hover (`.onHover`), context menus (`.contextMenu`), drag and drop, and full keyboard navigation (`.focusable`, `@FocusState`).
  - Put user preferences in a `Settings` scene backed by `@AppStorage`, with keys defined in `Config`.
- Keep the App Sandbox enabled (`ENABLE_APP_SANDBOX = YES`) and add only the entitlements you need (e.g. `com.apple.security.network.client` for outgoing network calls, user-selected file access for open/save panels). Turn on the Hardened Runtime (`ENABLE_HARDENED_RUNTIME = YES`, which is not set yet) because notarization requires it.
- Distribution: sign with a Developer ID or Mac App Store certificate and notarize (`xcrun notarytool`) before distributing outside the App Store.
- Do not write files into the app bundle at runtime, because it is read-only and code-signed. Writable data goes in the sandbox container (`URL.applicationSupportDirectory`, `URL.cachesDirectory`, or the SwiftData store), or in locations the user picks through `NSOpenPanel`/`NSSavePanel` or `.fileImporter`/`.fileExporter`.
- Build configurations: keep `Debug` (local) and `Release` (production) separate, with per-configuration `.xcconfig` files for base URLs and flags.

# Directory Layout
```
query/
├── App/            # queryApp.swift, app-level DI/environment setup
├── Scenes/         # WindowGroup / Settings / MenuBarExtra / Commands definitions
├── Views/          # Sidebar, content, and detail views
├── ViewModels/
├── Components/     # Reusable views (subdirectories for related groups)
├── Models/         # SwiftData @Model types
├── Queries/        # FetchDescriptors, predicates, query helpers
├── Types/
├── Protocols/
├── Extensions/
├── Utils/          # Networking/, Persistence/, Auth/, BusinessLogic/
├── Styles/         # ViewModifiers, ButtonStyles
├── Animations/
├── Config/         # Theme, typography, spacing, feature flags, environment
└── Assets.xcassets
queryTests/         # Unit + integration tests (Swift Testing)
queryUITests/       # End-to-end tests (XCUITest)
```

# Testing (Mandatory)
Every feature or bug fix comes with tests at the right levels. A change is not done until all three suites pass.

## Unit Tests (`queryTests/Unit`)
- Use Swift Testing: `@Suite`, `@Test`, `#expect`, `#require`, and parameterized `@Test(arguments:)`.
- Cover ViewModels, business logic in `Utils`, `Queries`, `Types`, formatting, and `Config` parsing.
- Test in isolation. Inject protocol-based mocks or fakes, with no network, disk, or real clock (inject a `Clock` or a date provider).
- Test `async` code with `async` tests and `@MainActor` where needed. Do not sleep.
- Cover every `LoadState` path (loading, success, empty, failure) and confirm that failures are silent to the user.
- Mirror the source layout: `Utils/Networking/APIClient.swift` → `queryTests/Unit/Utils/Networking/APIClientTests.swift`.

## Integration Tests (`queryTests/Integration`)
- Exercise real collaborators working together: ViewModel + Service + SwiftData.
- Run SwiftData against an in-memory store (`ModelConfiguration(isStoredInMemoryOnly: true)`) built fresh for each test.
- Stub networking at the transport layer with a custom `URLProtocol` and JSON fixtures in `queryTests/Fixtures`. Never call real endpoints.
- Verify decoding against real response shapes, persistence round-trips, and error mapping (including missing config or secrets).
- Tag them with `@Test(.tags(.integration))` so they can be run on their own.

## End-to-End Tests (`queryUITests`)
- Use XCUITest (macOS) to drive the app as a user would, covering critical flows such as launch, sidebar navigation, menu bar commands and keyboard shortcuts (`typeKey(_:modifierFlags:)`), toolbar actions, the Settings window, opening multiple windows, data loading, the skeleton-to-content transition, and the empty or error fallback.
- Find elements only by `accessibilityIdentifier`. Do not match on localized text.
- Launch with `launchArguments`/`launchEnvironment` (e.g. `-UITesting`, `MOCK_API=1`) so the app uses deterministic stub data and an in-memory store.
- Use Page Object helpers in `queryUITests/Screens` for reusable screen interactions.
- Wait with `waitForExistence(timeout:)`, never fixed sleeps.
- Clean up between tests: terminate the app and avoid relying on restored windows. `-UITesting` turns window restoration off. Don't pass `-ApplePersistenceIgnoreState`: it stops SwiftUI from opening any window at launch.
- Include at least one accessibility audit (`try app.performAccessibilityAudit()`).

## Running Tests
```sh
# All tests
xcodebuild test -project query.xcodeproj -scheme query -destination 'platform=macOS,arch=arm64'

# Unit/integration only (skip UI tests)
xcodebuild test -project query.xcodeproj -scheme query -destination 'platform=macOS,arch=arm64' \
  -skip-testing:queryUITests

# Integration tests only (via the Integration test plan, which includes the `.integration` tag)
xcodebuild test -project query.xcodeproj -scheme query -destination 'platform=macOS,arch=arm64' \
  -testPlan Integration
```
- Keep test plans (`.xctestplan`) for `Unit`, `Integration` and `EndToEnd`, with each one filtering by tag or target.
- UI tests on macOS need the test runner to have Accessibility permission (System Settings → Privacy & Security → Accessibility) the first time they run.
- Enable code coverage in the scheme. Target at least 80% coverage on `Utils`, `ViewModels` and `Queries`.
- Tests must be deterministic and independent, with no ordering assumptions and no shared mutable state.

# Changelog (Mandatory)
`query/Resources/CHANGELOG.md` is bundled with the app and shown to users in the What's New window (Help ▸ What's New, and once after an update). Keep it current:
- Every user-facing change (feature, UI change, behavior change, bug fix) gets an entry in the same change that makes it. Internal refactors and test-only changes don't.
- Add new entries to the newest release at the top. Start a new release (`## [x.y.z] - YYYY-MM-DD`, newest first) for each new batch of work: bump the minor version for features or UI changes and the patch version for fixes only. Use the date the work lands.
- Group entries under these headings, in this order, each starting with its emoji. Use only the ones a release needs:

  | Heading | Use for |
  | --- | --- |
  | `### ✨ New Features` | New capabilities |
  | `### 🎨 UI Changes` | Layout, styling, navigation, wording users see |
  | `### ⚡️ Improvements` | Existing features working better or faster |
  | `### 🐛 Bug Fixes` | Things that were broken |
  | `### 🔒 Security` | Security and privacy fixes |
  | `### 🗑️ Removed` | Removed or deprecated features |
  | `### 🛠️ Developer Tools` | Docker databases, test scripts and other tooling |

- One `- ` bullet per change, written for users: say what they can now do or what was fixed, not how the code changed. Use **bold** for the feature's name, and `code` for SQL, keyboard shortcuts typed as text, or file names. Keep each bullet to one or two sentences.
- Don't put emojis in bullets or release headings; the heading emoji marks the category. Other headings are allowed, but they show in the app with a generic icon.
- After editing, run the `ChangelogParserTests` suite, which parses the bundled file.

# Commits (Mandatory)
Follow [Conventional Commit Messages](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13):

```
<type>(<optional scope>): <description>

<optional body>

<optional footer>
```

- **Types**
  - `feat`: add, adjust or remove a feature of the UI or API.
  - `fix`: fix a bug in an earlier `feat`.
  - `refactor`: restructure code without changing behavior. `perf` is a refactor that improves performance.
  - `style`: formatting only (white space, line breaks), no behavior change.
  - `test`: add missing tests or correct existing ones.
  - `docs`: documentation only (`README.md`, `Claude.md`, doc comments).
  - `build`: build tools, the Xcode project, dependencies (Swift packages), version.
  - `ops`: CI/CD (GitHub Actions), Docker test databases, scripts.
  - `chore`: everything else, such as `.gitignore`. The first commit is `chore: init`.
- **Scopes** are optional and name the area changed: `app`, `welcome`, `connection`, `workspace`, `results`, `sql-editor`, `row-editor`, `setup`, `settings`, `whats-new`, `users`, `store`, `drivers`, `i18n`, `theme`, `docker`, `ci`. Never use issue numbers as scopes.
- **Description**: required; imperative, present tense ("add", not "added" or "adds"); lowercase first letter; no period at the end. Read it as "This commit will …".
- **Body**: optional; the motivation for the change and how behavior differs from before, also in the imperative.
- **Footer**: optional; issue references (`Closes #123`). Breaking changes add `!` before the `:` (`feat(store)!: …`) and a footer starting with `BREAKING CHANGE:`.
- **Versioning**: a breaking change bumps the major version, any `feat` the minor version, otherwise the patch version. Keep `CHANGELOG.md` releases in step.
- One logical change per commit, and each commit should build. Merge and revert commits keep git's default messages.

Examples:
```
feat(sql-editor): run each line as its own statement
fix(results): keep the selected row highlighted when the grid loses focus
ops(ci): run unit and integration tests on pull requests
```

# Code Quality
- Use SwiftLint and `swift-format`, and fix warnings before committing. Treat warnings as errors in CI.
- Do not force-unwrap (`!`) or use `try!` outside tests.
- Mark types `final` and members `private` by default, and widen access only when needed.
- Every view gets a `#Preview` using mock data from a shared preview fixture.
