# Development Guide

## Requirements

- macOS 14+
- Swift toolchain with SwiftUI/AppKit support

## Build Commands

Build the app bundle:

```sh
Scripts/build-app.sh
open .build/DevDeck.app
```

`Package.swift` is kept for source indexing and SwiftPM-compatible toolchains. Use `Scripts/build-app.sh` as the canonical local build because it creates the macOS `.app` bundle and avoids SwiftPM manifest issues seen in some Command Line Tools installs.

## Source Layout

```text
DevDeck/
  App/
  Models/
  Services/
  Utils/
  Views/
Scripts/
docs/
```

## Verification

Use direct compilation for a fast build check:

```sh
swiftc -target arm64-apple-macosx14.0 -parse-as-library $(find DevDeck -name '*.swift' | sort) -o /tmp/DevDeckBuildCheck
```

Then build the app bundle:

```sh
Scripts/build-app.sh
```

Package the app for local release testing:

```sh
Scripts/package-release.sh local
```

## Release Automation

- Pull requests run the `CI` workflow.
- Pushes to `main` run `CI`.
- When `CI` succeeds on `main`, the `Release` workflow creates a tag automatically and publishes a GitHub Release.
- Release assets include `DevDeck-<tag>.zip` and `DevDeck-<tag>.zip.sha256`.
- Releases are currently unsigned and not notarized. Users may see standard macOS Gatekeeper warnings until signing/notarization is added.
- The `Release` workflow can also be run manually from GitHub Actions.

## UX Notes

- The window layout is the primary development surface.
- The status bar icon is optional and controlled from Settings.
- The status bar popover should stay compact and should not require background polling just to update a badge.
- Process details should align to the top of the right pane.
- Settings are shown in the right pane of the main window.
- Ignored process/path filters are edited as drafts. Reset returns the drafts to defaults, and Save applies them.
- Conflict detection and port-change suggestions are not active features. Keep them as future backlog unless the product behavior is revisited.

## Adding Runtime Support

When adding a new runtime:

1. Add it to `RuntimeKind`.
2. Define common ports per runtime.
3. Add a runtime badge in `RuntimeBadgeView`.
4. Extend `DevProjectDetector` with cheap manifest/command heuristics.
5. Add framework cases only when they improve classification.
6. Avoid new shell commands in the polling loop.

## Privacy Rules

Do not add docs or fixtures with real:

- home directory paths
- private project names
- private branch names
- customer names
- private Git remotes
- tokens or secrets

Use placeholders.
