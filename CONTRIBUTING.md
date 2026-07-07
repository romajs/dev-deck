# Contributing

Thanks for considering a contribution.

DevDeck is early-stage. Small, focused changes are preferred.

## License Note

DevDeck is source-available, not open source under an OSI-approved license. The public repository does not grant permission to use, copy, modify, distribute, commercialize, or create derivative works without written permission. By submitting a contribution, you agree that it may be included in DevDeck under the repository license.

## Before Opening a PR

- Keep the app native Swift/SwiftUI.
- Do not add Electron or webviews.
- Do not add telemetry.
- Avoid new polling commands unless they are cheap and justified.
- Keep generated files out of commits.
- Do not include local paths, private project names, screenshots with private data, or secrets.

## Build

```sh
Scripts/build-app.sh
```

`swift build` may work with a healthy SwiftPM toolchain, but the supported local verification path is the app-bundle script above.

Release packaging can be tested locally:

```sh
Scripts/package-release.sh local
```

## Sensitive Data Check

Before publishing:

```sh
rg -n "TOK[E]N|SEC[R]ET|PASS[W]ORD|PRI[V]ATE|BEGIN .*K[E]Y|github.com[:/][^ ]+" . --glob '!/.build/**'
```
