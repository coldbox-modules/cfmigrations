# cfmigrations - AI Coding Instructions

This is a **ColdBox module** providing database migration management for CFML and BoxLang applications. It wraps the `cfmigrations` library with CommandBox CLI commands (`migrate up`, `migrate down`, `migrate create`, etc.) and adds BoxLang-specific features like automatic JDBC driver installation.

## Architecture & Key Components

**Command Structure**: Commands follow CommandBox's hierarchical structure in `/commands/migrate/`:

- **Core commands**: `up.cfc`, `down.cfc`, `create.cfc`, `init.cfc`, `install.cfc`, `uninstall.cfc`, `reset.cfc`, `fresh.cfc`, `refresh.cfc`, `status.cfc`, `help.cfc`
- **Seed subcommands** (`/commands/migrate/seed/`): `run.cfc`, `create.cfc`, `help.cfc`

Each command extends `BaseMigrationCommand.cfc` which provides common functionality: DI properties, `isBoxLangProject()`, config resolution, datasource registration, and BoxLang JDBC driver auto-installation.

**Model Layer** (`/models/`):

- `BaseMigrationCommand.cfc` — Base for all commands: DI properties, `setup()`, `getMigrationsInfo()`, `isBoxLangProject()`, `detectBoxLangDriverSlug()`, `ensureBoxLangDriver()`, `loadBoxLangDrivers()`, `findMigrationsConfigPath()`, print helpers
- `MigrationService.cfc` (vendored from cfmigrations) — Core migration engine: `findAll()`, `findSeeds()`, `hasMigrationsToRun()`, `runMigration()`, `runNextMigration()`, `runAllMigrations()`, `seed()`, `install()`, `uninstall()`, `reset()`

**Template System**: Code generation uses text templates in `/templates/`:

- `Migration.txt` / `MigrationBX.txt` — CFML vs BoxLang migration templates
- `seed.txt` / `seedBX.txt` — CFML vs BoxLang seeder templates
- `config.txt` — `.cbmigrations.json` configuration template

**BoxLang Detection**: The `isBoxLangProject()` method detects BoxLang projects via:

1. Server engine detection (`serverInfo.cfengine` contains "boxlang")
2. `box.json` `language` property set to `"boxlang"`

**Dual-language support**: Auto-detects BoxLang vs CFML. When generating scaffolding, selects the correct template pair (`Migration.txt` vs `MigrationBX.txt`). Both `.cfc` and `.bx` files are discovered by `findAll()` and `findSeeds()` using the `"*.cfc|*.bx"` pattern.

**Config resolution order**: `.cbmigrations.json` → legacy `.cfmigrations.json` → legacy `box.json` `cfmigrations` key (deprecated, auto-converted). Environment variables are expanded via `systemSettings.expandDeepSystemSettings()`.

**BoxLang Driver Auto-Install**: When running inside a BoxLang server engine, cbmigrations automatically detects the JDBC driver from `.cbmigrations.json` `connectionInfo` (via `driver`, `type`, or `connectionString` key) and installs the matching `bx-*` module from ForgeBox into `boxlang_modules/` if not already present. Supported drivers: mysql→bx-mysql, mariadb→bx-mariadb, postgresql→bx-postgresql, mssql→bx-mssql, oracle→bx-oracle, sqlite→bx-sqlite, derby→bx-derby, h2/hsql→bx-hypersql. Pass `--installDrivers=false` to opt out.

## Code Style Conventions

- **Semicolons are optional** in CFML/BoxLang — match the surrounding file's convention (most files omit them)
- **Arrow functions** use fat-arrow syntax: `( migration ) => { ... }`
- **K&R brace style** — opening brace on the same line as the statement
- **Always use braces** — even for single-statement bodies
- **Spaces inside parentheses** — `function process( name, count )`
- **No space between function name and `(`** — `doThing( name )`
- **One space around operators** — `var total = price * quantity`
- **Align related assignments** in column groups
- **Copyright header** on every `.cfc` and `.bx` file:

  ```
  /**
   * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
   * www.ortussolutions.com
   * ---
   */
  ```

CFML code is formatted via **CFFormat** (`.cfformat.json`). After editing `.cfc` files, run:

```bash
box run-script format
```

## Build and Test

```bash
# Format CFML files
box run-script format

# Run tests
box task run tests/Runner.cfc
```

The test suite validates command structure, template selection, config generation, and BoxLang support across both `.cfc` and `.bx` files. Tests live in `/tests/specs/`.

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Command CFCs | Lowercase verb | `up.cfc`, `down.cfc`, `fresh.cfc` |
| Models | PascalCase | `BaseMigrationCommand.cfc` |
| Templates | PascalCase, `BX` suffix | `Migration.txt` / `MigrationBX.txt` |
| Config files | Dot-prefixed JSON | `.cbmigrations.json`, legacy `.cfmigrations.json` |

## Skills

Project-specific agent skills are located in `.agents/skills/`. Each skill has a `SKILL.md` file with detailed instructions. When working on a task that matches a skill's domain, read the skill file first.

### BoxLang Language

| Skill | Description |
|-------|-------------|
| `boxlang-application-descriptor` | Application.bx behavior: app discovery, lifecycle events, sessions, mappings, schedulers/watchers |
| `boxlang-async-programming` | BoxFuture, asyncRun, asyncAll, executors, schedulers, thread components, parallel pipelines |
| `boxlang-best-practices` | Community best practices for naming, structure, scoping, error handling, performance |
| `boxlang-cfml-migration` | Migrating from CFML (Adobe/Lucee) to BoxLang: syntax differences, bx-compat-cfml, common issues |
| `boxlang-classes-and-oop` | Classes, components, interfaces, inheritance, annotations, properties, constructors, OOP patterns |
| `boxlang-code-documenter` | Javadoc-style comments, argument/return documentation, DocBox-compatible API reference generation |
| `boxlang-code-reviewer` | Code review for quality, correctness, security, performance, and style |
| `boxlang-configuration` | boxlang.json settings, env var overrides, datasources, caches, executors, modules, logging |
| `boxlang-database-access` | queryExecute, bx:query, datasource config, parameterized queries, transactions, SQL injection prevention |
| `boxlang-docbox` | DocBox API documentation generation: install, CLI, config, output strategies, themes |
| `boxlang-file-handling` | fileRead, fileWrite, fileCopy, fileMove, directoryList, fileUpload, streaming, CSV/JSON processing |
| `boxlang-file-watchers` | Filesystem watchers: watcherNew/Start/Stop, event payloads, debounce/throttle, error thresholds |
| `boxlang-functional-programming` | Lambdas, closures, arrow functions, array/struct pipelines (map, filter, reduce), destructuring, spread |
| `boxlang-interceptors` | Interceptor/event system: registration, announcement points, pre/post hooks, BoxRegisterInterceptor |
| `boxlang-java-integration` | createObject, static methods, type conversion, importing classes, closures as functional interfaces, JARs |
| `boxlang-language-fundamentals` | Syntax, file types, variables, scopes, operators, control flow, exception handling, type system |
| `boxlang-modules-and-packages` | box install, module settings, BoxLang+ premium modules (bx-pdf, bx-redis, bx-csv), ORM, mail |
| `boxlang-runtime-cli-scripting` | CLI scripts, command-line arguments, REPL, action commands (compile, cftranspile), CLI-specific BIFs |
| `boxlang-runtime-commandbox` | Deploying via CommandBox: server.json, modules, SSL, rewrites, BoxLang+/++ subscriptions |
| `boxlang-scheduled-tasks` | Scheduler DSL, BaseScheduler/ScheduledTask APIs, cron expressions, lifecycle callbacks, bx:schedule |
| `boxlang-security` | Security review, OWASP Top 10, injection prevention, file upload safety, secrets management |
| `boxlang-templating` | .bxm templates, bx:output, bx:loop, bx:if, bx:include, bx:script, building views |
| `boxlang-testing` | TestBox: BDD specs, xUnit classes, expectations, MockBox, mockData, async testing, CLI runner |
| `boxlang-web-development` | Web apps: request/response, sessions, forms, REST APIs, HTTP clients, routing, CSRF, SSE |
| `boxlang-zip` | bx:zip component: compress, extract, filter entries, read archives, download as ZIP |

### CommandBox CLI

| Skill | Description |
|-------|-------------|
| `commandbox-config-settings` | Global config: set/show/clear, server defaults, ForgeBox tokens, endpoints, proxy, env overrides |
| `commandbox-deploying` | Production deployment: Docker, GitHub Actions, Heroku, Lightsail, OS service, server.json, CFConfig |
| `commandbox-developing` | Custom commands, modules, namespaces, tab completion, WireBox DI, interceptors, lifecycle events |
| `commandbox-embedded-server` | Server management: start/stop, server.json, JVM args, SSL/TLS, rewrites, rules, profiles, auth, gzip |
| `commandbox-package-management` | box.json, installing from ForgeBox/Git/HTTP, semver, dependencies, lock files, publishing |
| `commandbox-setup` | Installing/upgrading CommandBox: Homebrew, apt-get, Windows, Java requirements, first-run config |
| `commandbox-task-runners` | Task CFCs, targets, lifecycle events, interactive jobs, progress bars, async, file watching |
| `commandbox-testing` | testbox run command, runner URL, output formats, test watcher, CI integration, code coverage |
| `commandbox-usage` | CLI usage: commands, namespaces, tab completion, system settings, env vars, piping, recipes, REPL |

### Other

| Skill | Description |
|-------|-------------|
| `ortus-coding-standards` | Official Ortus coding standards: indentation, spacing, braces, naming, alignment, comments |
| `github-action-authoring` | Composite GitHub Actions: multi-platform, PATH issues, inputs/outputs, PowerShell, CI testing |
| `java-expert` | Java services/libraries: API design, concurrency, performance, dependency management, production |
| `junit-expert` | JUnit 5 tests: lifecycle, parameterized tests, extensions, assertions, parallel execution, suites |
