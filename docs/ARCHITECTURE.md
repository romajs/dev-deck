# Architecture

DevDeck is structured as a small native macOS app with service boundaries around shell access and process enrichment.

## App Surfaces

- Main window: split-view layout with process list, details, and settings.
- Optional status bar icon: `MenuBarExtra` with compact process list and actions.

Both surfaces live in the same app bundle and share one `DevDeckStore`.

## Data Flow

1. `DevDeckStore.refresh()` starts a refresh.
2. `PortScanner` runs the lightweight listening-port scan.
3. `MetricsCollector` collects CPU/RAM/uptime/command in one batched `ps` call.
4. `ProcessInspector` chooses which PIDs deserve deeper inspection.
5. `DevProjectDetector` reads local manifests and classifies runtime/framework/toolchain.
6. `GitInspector` reads Git branch/status/remote for detected project folders.
7. SwiftUI views render filtered `DevProcess` values.

## Services

- `Shell`: safe command runner with timeout.
- `PortScanner`: parses `lsof -nP -iTCP -sTCP:LISTEN`.
- `MetricsCollector`: parses batched `ps`.
- `ProcessInspector`: orchestration, caching, cwd lookup, runtime version lookup.
- `DevProjectDetector`: runtime/framework/toolchain classification.
- `GitInspector`: Git metadata.
- `ProcessKiller`: SIGTERM then optional SIGKILL.

## Runtime Detection

Runtime detection is intentionally heuristic and low-cost. It uses:

- process name
- command line
- cwd
- project manifests
- known dependency strings

It should not run build tools, package managers, or framework CLIs during polling.

Supported runtime families:

- Node.js, Deno, Bun
- Python
- Ruby
- Java/JVM
- Go
- Rust
- PHP
- .NET
- Elixir

## Performance Model

Polling is designed to stay cheap:

- `lsof` once per refresh
- `ps` once per refresh for all PIDs
- cwd lookup in batch only for candidates
- metadata cached for 30-60 seconds
- auto-refresh pauses when no app surface is visible
- the status bar icon does not show a live count badge, so it does not need background refresh just to update the menu bar label

Avoid changes that turn refresh into one command per process unless the command is cheap and clearly bounded.

## Future Detection Ideas

Port conflict detection and port-change command suggestions are intentionally out of the active architecture for now. Reintroduce them only after the product behavior is decided.

## Window Persistence

The main window uses AppKit frame autosave with the name `DevDeckMainWindowV3`. This persists size and position. macOS Spaces are not directly controllable through stable public APIs.
