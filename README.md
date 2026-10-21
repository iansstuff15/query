# query

A native macOS database client built with SwiftUI: one app for PostgreSQL, MySQL, SQL Server,
Oracle, SQLite, MongoDB, Redis and 15 more engines, with a table browser, a SQL editor, row
editing and user management.

![The workspace: tables in the sidebar, rows in the center, the SQL editor on the right](docs/screenshots/workspace.png)

## Features

**Connecting**
- 21 engines: PostgreSQL, CockroachDB, Greenplum, Amazon Redshift, Vertica, MySQL, MariaDB,
  Microsoft SQL Server, Oracle, SQLite, DuckDB, libSQL / Turso, Cloudflare D1, ClickHouse,
  BigQuery, Snowflake, Cassandra / ScyllaDB, Redis / Valkey, MongoDB, Elasticsearch and DynamoDB.
- Paste or type a connection string and the fields fill in; a connection string on the clipboard
  is picked up when the sheet opens.
- Recent connections are checked in the background: a green check connects in one click, a red
  cross is disabled until you edit it.
- Saved passwords live in a SQLite file in the app's container (no prompts) or, if you choose, in
  the macOS Keychain. Switching moves them; connection details are encrypted with AES-256-GCM.
- Export and import connections, optionally with passwords in a passphrase-encrypted file.

**Browsing**
- Tables and views by schema in the sidebar, with fuzzy search and ⌘P Open Anything.
- An Xcode-style center panel: a tab per open table or query, a jump bar (connection › schema ›
  table) and back / forward.
- Server-side filters (contains, equals, in list, is null…) with the generated SQL shown.
- Click a row to select it; its fields open in the **Row** tab, editable where your user may
  change them, and **Save** updates that row by its primary key.

**SQL**
- Syntax colors and autocomplete for reserved words and table names.
- Each line, and each statement ending in `;`, has its own ▶; ⌘↩ runs the one at the cursor and
  **Run All** (⇧⌘↩) runs them in order, stopping at the first failure.
- Every distinct query gets its own result tab, with duration and row count; errors show the
  server's own message.
- Per-connection history (run again with one click) and **Open SQL File…** (⌘O) or drag-and-drop.

**Administration**
- **Users & Permissions** (⇧⌘U): create, change and delete users, and grant or revoke SELECT,
  INSERT, UPDATE and DELETE per schema and table (PostgreSQL, Greenplum, MySQL, MariaDB).

**Making it yours**
- A step-by-step startup configuration: language, color theme and password store.
- 12 color themes and five languages (English, Spanish, French, German, Japanese).
- A **What's New** window built from [`CHANGELOG.md`](query/Resources/CHANGELOG.md).
- Feature toggles and limits in `query-Info.plist` (`ENABLE_…`, `ROW_LIMIT`, …).

## Screenshots

| Choose a Database | SQL editor |
| --- | --- |
| ![Engine grid with recent connections and their status](docs/screenshots/welcome.png) | ![SQL editor with syntax colors, per-statement run buttons and a run summary](docs/screenshots/sql-editor.png) |
| **Users & Permissions** | **Row editing** |
| ![Users list, user form and the permissions grid](docs/screenshots/users.png) | ![A row's fields; the read-only key shows a lock](docs/screenshots/row-editor.png) |
| **Startup configuration** | **What's New** |
| ![Theme picker in the startup configuration](docs/screenshots/startup-configuration.png) | ![Release notes grouped by category](docs/screenshots/whats-new.png) |

The screenshots use the app's stub data. To retake them, run `scripts/capture-screenshots.sh`
(Terminal needs Screen Recording permission); it opens each screen and saves the PNGs here.

## Test databases

`docker/` holds disposable, seeded databases to test the app against. To start PostgreSQL and
MySQL together, run this from the project root (`compose.yaml` pulls in both engines):

```sh
docker compose up -d --wait         # start and seed both
docker compose down -v              # stop both and delete their data
```

Or work with one engine at a time:

```sh
docker/test-db.sh up postgres       # start and seed (same for mysql)
docker/test-db.sh down postgres     # stop and delete its data
docker/run-live-tests.sh postgres   # start, run the live tests, then stop
```

Each one is seeded with the same data:

- **Databases:** Postgres has an `app` database with `public`, `sales` and `analytics` schemas.
  MySQL has `app`, `sales` and `analytics` databases.
- **Tables:** `customers` (12 rows), `products` (6), `orders` (20) and `order_items`, plus a
  `sales` view and an `analytics` summary table.
- **Users besides the admin:**
  - `query_reader` / `ReaderPass1`: read-only
  - `query_writer` / `WriterPass1`: can also insert, update and delete in `app`

| Engine | Connection string (paste into the app) |
| --- | --- |
| PostgreSQL 17 | `postgresql://query_reader:ReaderPass1@localhost:55432/app?sslmode=disable` |
| MySQL 8.4 | `mysql://query_reader:ReaderPass1@localhost:33306/app` |

Admin logins are `postgres` and `root`, both with the password `AdminPass1`. These are local
test credentials only. Use them to try **Users & Permissions**:

| Engine | Administrator connection string |
| --- | --- |
| PostgreSQL 17 | `postgresql://postgres:AdminPass1@localhost:55432/app?sslmode=disable` |
| MySQL 8.4 | `mysql://root:AdminPass1@localhost:33306/app` |

To check the setup from inside the app, use `docker/postgres/test-queries.sql` and
`docker/mysql/test-queries.sql`. They're numbered queries to run one at a time, each with its
expected result. They cover browsing, joins, views, a 10,000-row result, the reader's write
restrictions, the writer's insert/update/delete (cleaned up afterwards) and error messages.

To change the seed data, edit `docker/generate_seeds.py` and run `python3 docker/generate_seeds.py`.
Don't edit the `seed.sql` files directly, because the script overwrites them.

See [`docker/README.md`](docker/README.md) for the other engines (MariaDB, SQL Server, Oracle,
MongoDB and more).

## Continuous integration

`.github/workflows/tests.yml` runs the Unit and Integration test plans on a macOS 26 runner for
every push to `main` and every pull request, and checks that the SQL test scripts copied into
`queryTests/Fixtures` still match `docker/`. Live database tests are opt-in and don't run in CI.

To run the workflow locally with [act](https://github.com/nektos/act) (macOS jobs run on this
Mac rather than in Docker):

```sh
act -j test -P macos-26=-self-hosted
act -j fixtures
```
