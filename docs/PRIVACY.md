# Privacy

DevDeck is designed as a local-only developer utility.

## Data Collection

DevDeck does not include telemetry, analytics, tracking, or network reporting.

## Local Data Read

To classify local development apps, DevDeck may read:

- listening TCP ports
- process names and command lines
- PID/user/protocol/address metadata
- cwd for candidate processes
- project manifests in detected project folders
- Git branch/status/remote URL for detected project folders
- process CPU/RAM/uptime

## Shell Commands

Current shell usage is local and read-only except process termination:

- `lsof` for ports and cwd
- `ps` for metrics
- `git` for metadata
- runtime `--version` commands for detected runtimes

Process termination is user-confirmed and uses SIGTERM first, then optional SIGKILL.

## Data Storage

DevDeck stores preferences in `UserDefaults`, including:

- display filters
- refresh interval
- per-runtime port settings
- ignored process names
- ignored support paths
- start-at-login preference

Window size and position are stored by macOS frame autosave.

## No Project Mutation

DevDeck does not edit project files. It does not change `.env`, manifests, launch configs, or source code.
