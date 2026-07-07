# Security

## Supported Versions

DevDeck is pre-1.0. Security policy will mature with releases.

## Reporting

For now, report security issues through GitHub issues if the repository is public. If private disclosure is needed later, add a dedicated contact before the first public release.

## Security Principles

- No sudo requirement.
- No telemetry.
- No remote execution.
- Shell commands are isolated behind services.
- Shell calls use argument arrays rather than interpolated shell strings.
- Timeouts are required for shell commands.
- Process killing requires user confirmation.

## Areas To Review Before Public Release

- Shell command parsing and timeout behavior.
- Process kill confirmation flows.
- Git metadata display of private remote URLs.
- Any future restart/edit-project behavior.
- Any future network/update mechanism.
