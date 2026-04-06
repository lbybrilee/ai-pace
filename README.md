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

1. Open `app/Package.swift` in Xcode
2. Run the `AIPace` executable target

### Option 2: Terminal

```bash
cd app && swift run
```

After launch, look for the flask icon in your menu bar.

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| Claude unavailable | Make sure `claude` is installed and logged in, or set `CLAUDE_CODE_OAUTH_TOKEN` |
| Claude Keychain prompt | Expected if your credentials are stored in Keychain — just approve it |
| Codex unavailable | Check that the `codex` CLI is installed, on your `PATH`, and logged in |
| Usage stuck on loading | Try the refresh button, then relaunch the app so it picks up your current shell environment |

## Good to Know

- The app relies on local CLI install paths and auth state
- `codex app-server` and the Claude OAuth usage flow are external integrations that may change over time
- Currently ships as source code only — no signed/notarized app releases yet

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

## Security

See [SECURITY.md](SECURITY.md) for reporting security concerns.

## License

MIT — see [LICENSE](LICENSE) for details.
