# Agent Handoff

This file is for LLMs and coding agents working on DevDeck.

## Project Intent

DevDeck is a lightweight native macOS developer utility. It should help developers see which local development servers are running, what ports they occupy, and which project/runtime each process belongs to.

Keep the app native, fast, and privacy-preserving.

## Hard Constraints

- Use Swift and SwiftUI.
- Support macOS 14+.
- Keep one app bundle with the main window as the primary surface.
- Keep `MenuBarExtra` as an optional status bar surface controlled from Settings.
- Do not add Electron or webviews.
- Do not add telemetry, analytics, or network reporting.
- Do not require sudo.
- Keep shell commands isolated behind services.
- Do not run package managers or build tools during polling.
- Do not commit generated `.build` output.
- Do not commit screenshots, local paths, project names, branch names, API keys, tokens, or private repo URLs.

## Architecture Rules

- `PortScanner` is the light scan layer.
- `MetricsCollector` gathers process metrics in batch.
- `ProcessInspector` orchestrates enrichment and caching.
- `DevProjectDetector` classifies runtime/framework/toolchain using commands and manifest reads.
- `GitInspector` is the only Git metadata layer.
- `ProcessKiller` owns SIGTERM/SIGKILL behavior.
- Ignored process/path filters live in `AppSettings`; support paths must be passed into detection instead of hardcoded in detectors.
- Views should stay thin and delegate work to services or `DevDeckStore`.

## Polling Rules

Polling must stay conservative:

- base scan: `lsof -nP -iTCP -sTCP:LISTEN`
- metrics: one batched `ps` call for all PIDs
- cwd lookup: batched and only for candidates
- Git/runtime/project metadata: cached
- auto-refresh: default 5 seconds
- pause refresh when window/popover is not visible
- do not add a live status bar count badge unless the polling cost and lifecycle behavior are explicitly revisited

Before adding any new detection feature, ask whether it can be implemented by reading existing process data or manifests. Avoid invoking heavy commands inside the refresh loop.

## Future Backlog

- Port conflict detection is not active. Do not reintroduce it without clarifying the UX and performance cost.
- Port suggestion/restart command generation is not active. Do not add it back unless DevDeck's project-mutation/restart behavior is defined.

## Public Repository Hygiene

Use generic examples only:

- OK: `/path/to/project`
- OK: `example-app`
- Not OK: real usernames, home directories, customer/project names, private branch names, or private remote URLs

Before finishing a change, run a quick sensitive-string audit:

```sh
rg -n "TOK[E]N|SEC[R]ET|PASS[W]ORD|PRI[V]ATE|BEGIN .*K[E]Y|github.com[:/][^ ]+" . --glob '!/.build/**'
```

False positives are possible, but real local paths or credentials must be removed before publishing.
