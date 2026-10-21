# Changelog

All notable changes to query. The app's What's New window reads this file: each `## [version] - date`
is a release, each `### emoji Heading` a category, and each `- item` a change. Inline Markdown such as
**bold** and `code` is supported.

| Emoji | Category |
| --- | --- |
| ✨ | New Features |
| 🎨 | UI Changes |
| ⚡️ | Improvements |
| 🐛 | Bug Fixes |
| 🔒 | Security |
| 🗑️ | Removed |
| 🛠️ | Developer Tools |

## [0.14.0] - 2026-10-21

### 🎨 UI Changes
- Settings tabs (Language, Display, Store, Search) and the right panel's Editor / History / Row tabs show icons.
- Cancel, Revert and Clear History buttons have icons like the rest.
- The **Choose a Database** header has a solid background, so the engine grid never shows through it.

## [0.13.0] - 2026-10-21

### ✨ New Features
- **Users & Permissions** window (`⇧⌘U`, or the toolbar's people button) for the open connection: create, change and delete database users, and grant or revoke `SELECT`, `INSERT`, `UPDATE` and `DELETE` per schema and table. Saving permissions only grants and revokes what you changed.
- On PostgreSQL, users have sign-in, superuser, create-database and manage-users options; deleting a user hands anything it owns to you first, so nothing is lost. On MySQL and MariaDB, accounts are `user@host` and sign-in locks or unlocks the account.
- Managing users needs an administrator's login; if the server refuses, its message is shown.

### 🛠️ Developer Tools
- `ENABLE_USER_MANAGEMENT` in `query-Info.plist` turns the window on or off.

## [0.12.0] - 2026-10-21

### ✨ New Features
- The **Row** tab only offers input fields for values you can change. Generated columns, always-generated identities and columns your user has no UPDATE permission on are shown as plain read-only text with a lock (PostgreSQL, MySQL and MariaDB). When nothing in a row can be changed, Save and Revert are hidden.

### 🐛 Bug Fixes
- Table and query results fill the center panel again, starting at the top left, instead of sitting compressed in the middle. Spare width is shared among the columns.

## [0.11.2] - 2026-10-21

### 🐛 Bug Fixes
- Rows in a table can be clicked to select them again. A system effect drawn over the grid hid rows from clicks; the grid's header and footer are now ordinary solid bars.
- Query results can be selected too, with the same highlight.
- The SQL editor stays inside its own section instead of running under the tabs and the Run All bar.

### 🎨 UI Changes
- The right panel's Editor / History / Row tabs always stay on top.
- The center panel's tab bar, filter bar, column headers and row count have solid backgrounds in the theme's window color, so text behind them never shows through.

## [0.11.1] - 2026-10-21

### 🐛 Bug Fixes
- SQL formatted across several lines runs as one statement again, so opening `docker/postgres/test-queries.sql` (or any formatted `.sql` file) no longer breaks queries apart at `FROM`, `WHERE` or `VALUES`. A line continues the statement above it when it's indented, starts with a clause such as `FROM` or `WHERE`, or follows a line ending in `,`, `(` or an operator; separate one-line statements still run on their own.
- Clicking a row in a table now selects it reliably, and the selected row stays highlighted with an accent border even while you edit it in the Row tab. Arrow keys move the selection and `Esc` clears it.

## [0.11.0] - 2026-10-21

### ✨ New Features
- **Languages**: query is now available in Spanish, French, German and Japanese. Pick one in the new **Language** step of the startup configuration or in **Settings ▸ Language**; it applies right away, and menus follow after a restart.

### 🎨 UI Changes
- The startup configuration starts with **Language**, before Display and Store.

### 🛠️ Developer Tools
- `query-Info.plist` has a toggle for each feature (`ENABLE_SQL_CONSOLE`, `ENABLE_SQL_HISTORY`, `ENABLE_SQL_AUTOCOMPLETE`, `ENABLE_SQL_SYNTAX_HIGHLIGHTING`, `ENABLE_ROW_EDITING`, `ENABLE_CLIPBOARD_CONNECTION_STRINGS`, `ENABLE_CONNECTION_HEALTH_CHECKS`, `ENABLE_KEYCHAIN_STORE`, `ENABLE_THEMES`, `ENABLE_LANGUAGE_SETTING`), all on.
- Limits are set there too: `ROW_LIMIT`, `OPEN_ANYTHING_RESULT_LIMIT`, `SPLASH_MINIMUM_MILLISECONDS`, `CONNECTION_CHECK_TIMEOUT_SECONDS`, `SQL_HISTORY_LIMIT`, `SQL_COMPLETION_LIMIT` and `SQL_FILE_MAX_MEGABYTES`. Out-of-range values are clamped to safe limits.

## [0.10.0] - 2026-10-21

### ✨ New Features
- **Edit rows**: select a row in a table and its fields open in the right panel's new **Row** tab, each in a text field holding its value. Change values (or set them to `NULL`) and **Save** (`⌘S`) updates that row, matched by its primary key. If the server refuses, its message is shown.
- **Open SQL File…** (`⌘O`) adds a `.sql` file's statements to the editor; you can also drop a `.sql` file on the editor.

### 🎨 UI Changes
- The startup configuration is now three steps (Display, Store, Ready) in a fixed-size window, with Back and Next.
- Each theme in the picker previews how text, secondary text and buttons look in it.
- What's New opens at startup.

### 🛠️ Developer Tools
- `ALWAYS_SHOW_STARTUP_CONFIG` and `ALWAYS_SHOW_CHANGELOG` in `query-Info.plist` (both on) open the startup configuration and What's New on every launch.

## [0.9.0] - 2026-10-21

### ✨ New Features
- Each line of the SQL editor, and each statement ending in `;`, is its own query. Run one with the **▶** beside it, or press `⌘↩` to run the one at the cursor (or the ones you've selected).
- **Run All** (`⇧⌘↩`) runs every statement in order and stops at the first failure. The console lists each statement with its status, duration, rows and error; click one to see its results.
- Every distinct query gets its own **result tab** in the center panel. Running the same query again reuses its tab, and each tab shows how long the query took and how many rows came back.

### 🎨 UI Changes
- The **Run** button is now **Run All**.

## [0.8.0] - 2026-10-21

### ✨ New Features
- **Autocomplete** in the SQL editor: reserved words and the connection's table names are suggested as you type. Tables come first after `FROM`, `JOIN`, `INTO` and `UPDATE`, and `schema.` lists only that schema's tables. Accept with Return or Tab; Esc dismisses.

### 🎨 UI Changes
- **Syntax colors** in the SQL editor: reserved words, table names, strings, numbers and comments each have their own color, in light, dark and high-contrast versions.

## [0.7.0] - 2026-10-21

### ✨ New Features
- **What's New** window listing each release's changes by category. It opens once after an update, and any time from **Help ▸ What's New**.

### 🎨 UI Changes
- The center panel's header is organized like Xcode's editor: **tabs** for open tables and the SQL results, then a **jump bar** with back / forward and a *connection › schema › table* path. Each part of the path is a menu of its neighbors.
- Switching tabs keeps each table's rows and filters.
- **Go Back** (⌃⌘←), **Go Forward** (⌃⌘→) and **Close Tab** (⌃⌘W) in the Database menu.

## [0.6.0] - 2026-10-21

### ✨ New Features
- **Startup configuration** on first launch, with **Display** and **Store** sections.
- 12 color themes: Classic, Midnight Harbor, Sunlit Terracotta, Mint Julep, Aurora Borealis, Desert Dusk, Lavender Fields, Ember Glow, Glacier, Matcha Latte, Neon Arcade and Cherry Blossom.
- Saved passwords are kept in a **SQLite file** by default; the **macOS Keychain** is opt-in. Switching moves every secret, so nothing is lost.
- **SQL history**: every statement run on a connection, newest first, each with its own Run button.

### 🎨 UI Changes
- The SQL console column has **Editor** and **History** tabs.
- Settings has **Display** and **Store** tabs.

### 🐛 Bug Fixes
- Choosing the secret store that's already active no longer re-saves the setting.
- A test of encrypted connection exports no longer fails at random.

## [0.5.0] - 2026-10-21

### 🎨 UI Changes
- Recent connections moved to a collapsible column on the right of **Choose a Database**.
- SQL results open in the center panel; the SQL column shows the editor and the last run's status, duration and row count.
- A loading bar at the top of the center panel while tables, rows or SQL load.

### ⚡️ Improvements
- The SQL console shows the server's own error message for PostgreSQL and MySQL, such as `permission denied for table customers`.

## [0.4.0] - 2026-10-21

### ⚡️ Improvements
- At most **one** Keychain prompt per launch: every secret is kept in a single Keychain item.
- Running tests no longer touches your Keychain, clipboard or saved connections.

### 🐛 Bug Fixes
- Denying the Keychain prompt no longer replaces the key that decrypts saved connections.

## [0.3.0] - 2026-10-20

### ✨ New Features
- Recent connections are checked in the background: a click connects to reachable ones, and unreachable ones are marked and disabled.
- An **Edit** button at the end of each recent connection.
- A **SQL console** beside the table browser.

### 🐛 Bug Fixes
- MySQL `DATETIME`, `DATE`, `TIME`, `FLOAT` and `DOUBLE` values showed as garbled bytes.

## [0.2.0] - 2026-10-20

### ✨ New Features
- A connection string on the clipboard fills in the connection sheet when it opens.
- Typing or pasting a connection string fills in the fields; **Import** is optional.

### 🎨 UI Changes
- Connection test results are green on success and red on failure.

### 🛠️ Developer Tools
- Seeded PostgreSQL and MySQL Docker databases, plus SQL test scripts to run against them.

## [0.1.0] - 2026-10-17

### ✨ New Features
- First release: connect to PostgreSQL, MySQL, SQL Server, Oracle, SQLite, MongoDB, Redis and many more, browse tables and filter rows.
