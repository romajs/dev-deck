# Project Plan

This document captures the working plan for DevDeck as an open source project. It is meant to guide maintainers, contributors, and coding agents without implying a fixed release commitment.

## Product Direction

DevDeck should stay a lightweight native macOS utility for local development visibility.

The core promise is:

> See local dev servers, ports, runtime, project metadata, Git state, and process usage from one native macOS app.

The app should remain:

- native Swift/SwiftUI
- fast enough to leave open during development
- privacy-preserving by default
- useful without elevated permissions
- installable from GitHub Releases
- understandable enough for contributors to extend runtime detection safely

## Phase 1: Public Foundation

Goal: make the repository clear, safe, and presentable.

Completed or mostly complete:

- Public repository under `romajs/dev-deck`.
- MIT license.
- README with status, features, build instructions, and limitations.
- Privacy and security docs.
- Agent handoff instructions.
- Universal GitHub Release artifact for Apple Silicon and Intel.
- Sensitive-string audit process documented.

Remaining:

- Add screenshots or a short GIF to the README.
- Decide whether to delete old broken releases or keep only the latest visible in messaging.
- Add GitHub issue templates and pull request template.
- Add a public contribution guide section for runtime detector changes.
- Keep examples generic and free of private paths, private repositories, customer names, branch names, and tokens.

## Phase 2: Distribution Baseline

Goal: make releases predictable and understandable without requiring commercial distribution infrastructure.

Current state:

- Release artifacts are universal (`arm64` and `x86_64`).
- Release artifacts are ad-hoc signed.
- Release artifacts include a SHA-256 checksum.
- Releases are not notarized.

Near-term direction:

- Switch release publishing from every `main` merge to explicit version tags.
- Use clean semantic tags such as `v0.1.1`, `v0.2.0`, and `v1.0.0`.
- Keep CI running on pull requests and `main` pushes.
- Publish release artifacts only from tags.
- Add release notes per version.

Not planned for now:

- Buying an Apple Developer Program membership only for this open source project.
- Requiring Developer ID signing or notarization before the project is useful.

Optional future distribution:

- Developer ID signing and notarization if a maintainer later chooses to pay for an Apple Developer account or a sponsor covers it.
- Homebrew Cask once release tags are stable.
- Sparkle auto-update only after the release process is stable.
- A small project website or GitHub Pages download page.

## Phase 3: Stronger MVP Product

Goal: make DevDeck dependable in daily local development.

Priority areas:

- Keep scanning fast under realistic process counts.
- Improve false-positive filtering for background apps.
- Improve default ignored process/path lists while keeping them user-editable.
- Improve runtime detection for Node.js, Python, Go, Ruby, Java/JVM, PHP, Rust, .NET, Elixir, Deno, and Bun.
- Improve project naming for non-Node manifests.
- Make unknown projects easier to understand and debug.
- Add focused parser and detector tests with synthetic fixtures only.
- Improve empty states and error states.
- Add optional actions such as reveal in Finder and open in editor.
- Keep kill-process behavior explicit and confirmed.

Performance guardrails:

- Do not add package manager or framework CLI calls inside polling.
- Prefer manifest reads and existing process data.
- Keep metrics batched.
- Keep expensive metadata cached.
- Keep refresh paused when no surface is visible.

## Phase 4: Open Source Quality

Goal: make contribution safe and practical.

Recommended GitHub structure:

- Milestones:
  - `v0.2`: tag-based releases, screenshots, detector tests
  - `v0.3`: stronger settings, ignored filters, runtime polish
  - `v0.4`: open editor/Finder, debug affordances, UX polish
  - `v1.0`: stable detection, stable settings, stable release process
- Labels:
  - `bug`
  - `good first issue`
  - `help wanted`
  - `runtime-detection`
  - `ui`
  - `performance`
  - `distribution`
  - `privacy`

Contribution standards:

- Keep pull requests small and focused.
- Prefer synthetic fixtures over real local output.
- Do not commit private paths, private repo URLs, branch names, customer names, screenshots with personal data, tokens, or secrets.
- Add tests when changing parsing, detection, filtering, or settings persistence.
- Document new runtime support in the architecture and development guide.

## Phase 5: Outreach

Goal: share the project after installation and messaging are clear.

Before broader outreach:

- Latest release should be downloadable and validated.
- README should include screenshots or a GIF.
- Known limitations should be clear.
- Installation instructions should mention the non-notarized status if still applicable.
- Issues should be ready for bug reports and feature requests.

Possible channels:

- GitHub README and release notes.
- X/Twitter and LinkedIn with a short screen recording.
- Reddit communities such as macOS apps, web development, Node.js, and Swift.
- A technical post about building a native macOS dev-server inspector.
- Hacker News "Show HN" only after the install path is less confusing.
- Product Hunt later, after more polish.

Suggested positioning:

> DevDeck is a native macOS app that shows your local dev servers, ports, runtime, Git branch, CPU/RAM, and quick actions in one place.

## Phase 6: Release Cycle

Preferred future cycle:

1. Open or select issues for the next version.
2. Work in branches.
3. Open pull requests.
4. Run CI on the pull request.
5. Squash merge to `main`.
6. When ready to publish, create a version tag such as `v0.2.0`.
7. Let GitHub Actions build the universal app zip and checksum.
8. Download and validate the release artifact.
9. Publish release notes.
10. Update roadmap and docs if product behavior changed.

This is preferred over publishing a release for every merge to `main`.

## Practical Priority Order

Recommended next work:

1. Switch release publishing to explicit version tags.
2. Add screenshots or a GIF to the README.
3. Add issue and PR templates.
4. Add parser/detector tests with synthetic fixtures.
5. Improve settings and ignored filter UX for larger runtime lists.
6. Refine multi-runtime detection with performance checks.
7. Add Homebrew Cask only after tags are stable.
8. Revisit notarization only if the project has a practical reason to pay for Apple Developer Program access.
