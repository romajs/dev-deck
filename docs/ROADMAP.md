# Roadmap

This roadmap captures current direction. It is not a release commitment.

## Done

- Native SwiftUI macOS app.
- Main window app with optional status bar integration.
- Listening TCP port detection.
- Process metrics.
- Runtime and framework detection across common dev stacks.
- Git metadata.
- Runtime-specific port configuration.
- Per-runtime badges.
- Process details screen.
- Open in browser.
- Kill process with confirmation.
- Auto-refresh with visibility pause.
- Window size/position persistence.
- False-positive reduction for common macOS support folders.
- Configurable ignored process/path filters.
- Release publishing from explicit version tags.

## Near-Term Backlog

- Add screenshots or a short GIF to the README.
- Add GitHub issue and pull request templates.
- Improve settings layout for large runtime lists.
- Add tests for `lsof`, `ps`, manifest parsing, and detector heuristics.
- Add sample parser fixtures with synthetic data only.
- Improve project name detection for non-Node manifests.
- Improve runtime-specific port defaults.
- Design optional port conflict detection.
- Design optional port-change/restart suggestions.

## Product Decisions Pending

- Whether conflict warnings should exist, and if so whether they should be visible, grouped, or opt-in.
- Whether DevDeck should ever edit project files.
- Whether DevDeck should restart processes or only inspect them.
- Whether logs/tailing belongs in scope.
- Whether Docker/container detection belongs in MVP.
- Whether Homebrew cask distribution is worth maintaining.

## Larger Ideas

- Developer ID signing and notarization if a maintainer later chooses to pay for Apple Developer Program access or a sponsor covers it.
- Notifications when a new dev server starts.
- Notifications when a conflict appears.
- Workspace grouping.
- Open in editor.
- Reveal project folder in Finder.
- Docker container detection.
- Historical CPU/RAM chart.
- Global hotkey.
- Sparkle auto-update.
- Homebrew cask.
