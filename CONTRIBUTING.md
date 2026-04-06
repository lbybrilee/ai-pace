# Contributing

Thanks for helping improve AIPace.

## What To Work On

The most useful changes are:

- Reliability fixes
- Documentation improvements
- Compatibility updates
- Packaging improvements

Please keep changes focused. This app is meant to stay small and simple.

## Development Setup

You will need:

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

## Before You Open A Pull Request

- Keep changes focused and scoped.
- Update documentation when behavior changes.
- Prefer clear fixes over extra abstraction.
- Do not commit secrets, tokens, local auth files, screenshots with private account data, or machine-specific config.

## Pull Requests

- Describe the user-visible behavior change.
- Include reproduction steps for bug fixes.
- If your change affects Claude or Codex login behavior, call that out clearly.

## Security Issues

Do not file public issues for credential-handling or token-exposure problems. See [SECURITY.md](SECURITY.md).
