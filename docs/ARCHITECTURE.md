# Architecture

DevDeck is structured as a small native macOS app with service boundaries around shell access and process enrichment.

## Principles

- Keep the main window as the primary surface.
- Keep the status bar icon optional and controlled by settings.
- Keep shell execution isolated behind services.
- Keep refresh work bounded, batched, and cache-aware.
- Prefer reading existing process data and local manifests over invoking toolchains.
- Keep views thin; put process discovery, enrichment, and filtering in services or `DevDeckStore`.
- Do not add telemetry, analytics, or network reporting.
- Do not require sudo.

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

```text
Visible surface
  -> DevDeckStore.refresh()
  -> PortScanner
  -> MetricsCollector
  -> ProcessInspector
  -> DevProjectDetector
  -> GitInspector
  -> [DevProcess]
  -> SwiftUI views
```

## Services

- `Shell`: safe command runner with timeout.
- `PortScanner`: parses `lsof -nP -iTCP -sTCP:LISTEN`.
- `MetricsCollector`: parses batched `ps`.
- `ProcessInspector`: orchestration, caching, cwd lookup, runtime version lookup.
- `DevProjectDetector`: runtime/framework/toolchain classification.
- `GitInspector`: Git metadata.
- `ProcessKiller`: SIGTERM then optional SIGKILL.

## Service Responsibilities

### `PortScanner`

`PortScanner` is the light scan layer. It should only discover listening TCP sockets and parse the process/port fields available from `lsof`.

It should not:

- classify frameworks
- read project manifests
- call Git
- collect CPU or memory
- apply user-facing product decisions beyond basic parsing errors

### `MetricsCollector`

`MetricsCollector` gathers process metrics in batch. The expected MVP implementation is one `ps` call for all relevant PIDs.

It owns:

- CPU percent
- resident memory
- elapsed time
- command text from `ps`

It should avoid one `ps` invocation per process.

### `ProcessInspector`

`ProcessInspector` orchestrates enrichment and caching. It decides which listening processes are likely development candidates, asks for cwd/runtime metadata, applies ignored filters, and merges scanner/metrics/project/Git data into `DevProcess`.

It owns:

- enrichment flow
- metadata cache lifetime
- cwd lookup batching
- runtime version lookup policy
- ignored process/path filtering inputs from settings

### `DevProjectDetector`

`DevProjectDetector` classifies runtime, framework, toolchain, project name, manifest path, and likely start script from command lines and local manifest files.

Detection must stay low-cost:

- read known manifests
- inspect command text
- inspect dependency names
- inspect lockfiles for package manager/toolchain hints

Do not run package managers, framework CLIs, build commands, or application code during polling.

### `GitInspector`

`GitInspector` is the only Git metadata layer. It reads branch, dirty status, and remote origin for detected project folders.

Git calls should be cached because repository status can become expensive in large worktrees.

### `ProcessKiller`

`ProcessKiller` owns process termination:

- request confirmation in the UI before killing
- try graceful termination first
- only use force kill when explicitly requested
- refresh process state after termination

## Models

- `ListeningPort`: raw listening socket/process record from the scan layer.
- `ProcessMetrics`: CPU, memory, uptime, and command metrics.
- `ProjectMetadata`: detected runtime/framework/toolchain/project information.
- `GitMetadata`: branch, dirty status, and remote origin.
- `DevProcess`: enriched UI-facing process model.
- `AppSettings`: user preferences, runtime ports, ignored process names, ignored support paths, refresh behavior, and status bar visibility.

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

## Runtime Ports

Runtime ports are configured per runtime. They are used as detection hints, not as a hard requirement for inclusion.

For example, Node.js, Python, Go, Ruby, Java, and PHP can each have separate default/favorite ports. Avoid adding a single global "extra ports" list as the primary model because it makes runtime-specific behavior harder to reason about.

## Performance Model

Polling is designed to stay cheap:

- `lsof` once per refresh
- `ps` once per refresh for all PIDs
- cwd lookup in batch only for candidates
- metadata cached for 30-60 seconds
- auto-refresh pauses when no app surface is visible
- the status bar icon does not show a live count badge, so it does not need background refresh just to update the menu bar label

Avoid changes that turn refresh into one command per process unless the command is cheap and clearly bounded.

## Refresh Lifecycle

Refresh should run only when useful:

- main window visible
- status bar popover visible
- explicit manual refresh

The default interval is 5 seconds. Lower intervals should be treated as a product/performance decision, not a cosmetic setting.

Long-running refresh work should not block the UI. If a refresh is already in progress, a new automatic refresh should avoid piling up duplicate work.

## Settings and Persistence

`AppSettings` is the source of user-configurable behavior:

- show only detected development apps
- show all listening ports
- status bar icon visibility
- auto-refresh behavior and interval
- per-runtime favorite ports
- ignored process names
- ignored support paths

Ignored filters must be passed into detection/enrichment from settings. Do not hardcode support paths directly in detectors unless they are defaults used to initialize settings.

## Future Detection Ideas

Port conflict detection and port-change command suggestions are intentionally out of the active architecture for now. Reintroduce them only after the product behavior is decided.

## Window Persistence

The main window uses AppKit frame autosave with the name `DevDeckMainWindowV3`. This persists size and position. macOS Spaces are not directly controllable through stable public APIs.

## Current Non-Goals

- Editing project files.
- Restarting development servers.
- Running package manager scripts.
- Live telemetry or analytics.
- Network reporting.
- Docker/container inspection in the polling loop.
- A live status bar process count badge.
- Port conflict detection without a clarified UX.
- Port suggestion/restart command generation without a clarified restart model.
