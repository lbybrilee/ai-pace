# AIPace

**A macOS menu bar app for keeping an eye on your AI usage.**

AIPace is a lightweight menu bar app that shows your current `5h` and `weekly` usage for Claude and Codex — right from your Mac, no extra logins needed.

> This project is unofficial and is not affiliated with, endorsed by, or maintained by Anthropic or OpenAI.

## Features

- 🧪 A flask icon in your menu bar, built with SwiftUI
- 📊 See your Claude and Codex `5h` + `weekly` usage at a glance
- 🔐 No need to paste tokens — it reuses your existing local CLI login
- 🔔 Optional notifications when a usage window refreshes
- ⏱️ Auto-refreshes every 5 minutes by default, configurable
- 🧠 Pacing insights that show where you are in your current usage window

## What You'll Need

- macOS 14 or later
- Xcode with Swift 6.2 support, or a Swift 6.2 toolchain
- `claude` installed and logged in (for Claude usage)
- `codex` installed and logged in (for Codex usage)

## How It Works

### Claude

AIPace finds your Claude credentials by checking these locations in order:

1. `~/.claude/.credentials.json`
2. macOS Keychain service `Claude Code-credentials`
3. `CLAUDE_CODE_OAUTH_TOKEN` environment variable

Then it calls:

- Usage endpoint: `https://api.anthropic.com/api/oauth/usage`
- Refresh endpoint: `https://platform.claude.com/v1/oauth/token`

It also reads `~/.claude.json -> oauthAccount` for display info only.

**Note:** If macOS asks you about Keychain access, that's expected — it's the system prompting when the app reads Claude credentials from Keychain.

### Codex

AIPace uses `codex app-server` JSON-RPC with your existing Codex login. It launches from your home directory to avoid workspace trust prompts.

## Privacy & Security

- **No telemetry** — nothing is tracked
- **No backend** — no proxy or app server involved
- **Local only** — credentials are read from your existing CLI auth state
- **Direct connections** — network requests go straight from your Mac to provider endpoints
- **No syncing** — tokens never leave your machine

This project works with local auth state and depends on provider APIs and CLI contracts that could change. If you're using this in a security-sensitive environment, review the code first.

## Getting Started

### Option 1: Xcode

1. In Xcode, choose `File -> Open...`
2. Select `app/Package.swift` (not the repo root)
3. Run the `AIPace` executable target

This repository is a Swift Package. It does not include an `.xcodeproj` or `.xcworkspace`, so opening the top-level folder will not work the same way as a typical Xcode project.

### Option 2: Terminal

```bash
cd app && swift run
```

After launch, look for the flask icon in your menu bar.

## Run Tests

Run the unit test suite from the repo root:

```bash
./scripts/test.sh
```

The script prefers the full Xcode toolchain when it is installed, which avoids the missing test framework problem some Command Line Tools setups have with plain `swift test`.

## Build a DMG

Build an unsigned DMG locally:

```bash
./scripts/build-dmg.sh --version 0.1.0
```

Artifacts are written to `dist/`.

## Sign and Notarize

For distribution outside the Mac App Store, sign the app with a `Developer ID Application` certificate and notarize the DMG with `notarytool`.

1. List your signing identities:

```bash
security find-identity -v -p codesigning
```

2. Store notarization credentials in Keychain:

```bash
xcrun notarytool store-credentials AC_NOTARY \
  --apple-id "you@example.com" \
  --team-id TEAMID
```

3. Build, sign, notarize, and staple the DMG:

```bash
./scripts/build-dmg.sh \
  --version 0.1.0 \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  --notarize-profile AC_NOTARY
```

The script signs the `.app` with hardened runtime enabled, submits the `.dmg` to Apple, then staples the notarization ticket to the `.dmg`.

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| Claude unavailable | Make sure `claude` is installed and logged in, or set `CLAUDE_CODE_OAUTH_TOKEN` |
| Claude Keychain prompt | Expected if your credentials are stored in Keychain — just approve it |
| Codex unavailable | Check that the `codex` CLI is installed, on your `PATH`, and logged in |
| Codex works in Terminal but not from Xcode | Xcode-launched apps often inherit a different `PATH`; AIPace now augments `PATH` with your login shell and common macOS install directories |
| Usage stuck on loading | Try the refresh button, then relaunch the app so it picks up your current shell environment |
| Xcode will not open the app | Open `app/Package.swift`, not the repo root, and make sure your Xcode version supports `swift-tools-version: 6.2` |

## Good to Know

- The app relies on local CLI install paths and auth state
- `codex app-server` and the Claude OAuth usage flow are external integrations that may change over time
- The GitHub release workflow currently builds an unsigned DMG unless you add signing credentials in CI

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

## Security

See [SECURITY.md](SECURITY.md) for reporting security concerns.

## License

MIT — see [LICENSE](LICENSE) for details.
