# Contributing

Thanks for considering a contribution.

DevDeck is early-stage. Small, focused changes are preferred.

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

## Sensitive Data Check

Before publishing:

```sh
rg -n "TOK[E]N|SEC[R]ET|PASS[W]ORD|PRI[V]ATE|BEGIN .*K[E]Y|github.com[:/][^ ]+" . --glob '!/.build/**'
```
