# Contributing

## Scope

AIPace is intentionally small. Contributions are most useful when they improve reliability, packaging, documentation, or compatibility without turning the app into a large multi-provider platform.

## Development Setup

Requirements:

- macOS 14 or later
- Xcode with Swift 6.2 support, or a Swift 6.2 toolchain

Build locally:

```bash
swift build
```

Run locally:

```bash
swift run
```

You can also open `Package.swift` in Xcode and run the `AIPace` target.

## Before You Open A PR

- Keep changes focused and scoped.
- Update documentation when behavior changes.
- Prefer concrete bug fixes over speculative abstraction.
- Do not commit secrets, tokens, local auth files, screenshots with private account data, or machine-specific config.

## Pull Requests

- Describe the user-visible behavior change.
- Include reproduction steps for bug fixes.
- Mention any provider contract assumptions you validated.
- If a change affects Claude or Codex auth flows, call that out explicitly.

## Security Issues

Do not file public issues for credential-handling or token-exposure problems. See [SECURITY.md](SECURITY.md).
