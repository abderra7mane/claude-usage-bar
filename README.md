# Claude Usage Bar

A macOS menu bar app that shows your Claude plan usage for the 5-hour session and the weekly window.

- Blue: below 75%
- Orange: 75–99%
- Red: limit reached

The top bar in the icon is the session, the bottom bar is the week. Click it for details and reset times.

## Notifications

The app notifies you when the session or weekly usage passes 75%, 80%, 85%, 90%, 95% and 100%. If usage jumps past several of them between two checks, you get one notification for the highest. Turn them off in Settings.

## Sessions

Claude Code's prompt cache expires 1 hour after a session's last request; the next message then re-writes the whole context at a higher price. The panel's **Sessions** tab shows one bar per running session with a live cache, full with an hour left and empty when it expires, next to the session's cost. The app notifies you 5 minutes before a session's cache expires, once per expiry, so you can send it a message to keep it. Turn the alerts off in Settings.

The cost is estimated at API prices from the token usage in the session's transcripts, subagents included. It can read lower than Claude Code's own total: subagent transcripts often keep only the usage reported when a response started, and a few requests (title generation, away summaries) aren't recorded in transcripts.

## Multiple subscriptions

Each account is a Claude Code config folder (`CLAUDE_CONFIG_DIR`), e.g. `~/.claude` and `~/.claude-work`. Manage them in **Settings…**: add folders, pick from detected `~/.claude*` folders, rename them, and choose which ones get a menu bar item. Accounts that are logged out or have an expired token are dimmed and offer a "Copy login command" button.

## Install

Download the DMG for your Mac from the [latest release](https://github.com/abderra7mane/claude-usage-bar/releases/latest): `ClaudeUsageBar-arm64.dmg` for Apple Silicon, `ClaudeUsageBar-x86_64.dmg` for Intel or `ClaudeUsageBar-universal.dmg` for both. Open it and drag the app to Applications. The app isn't notarized, so clear the quarantine flag before the first launch:

```sh
xattr -dr com.apple.quarantine /Applications/ClaudeUsageBar.app
```

The app checks for updates daily and installs them from the panel's **Check for Updates…**. Automatic checks can be turned off in Settings.

## Requirements

- macOS 14+, Xcode 16+
- Claude Code logged in with a Pro/Max subscription (`/login`)

## Usage

```sh
make test      # run unit tests
make run       # build build/ClaudeUsageBar.app and open it
make install   # copy to /Applications and open it
make uninstall
make dist      # build build/ClaudeUsageBar.dmg for this Mac; ARCH=arm64, x86_64 or universal builds build/ClaudeUsageBar-<arch>.dmg
make icon      # regenerate Resources/AppIcon.icns from Scripts/generate-icon.swift and Scripts/claude-symbol.svg
```

Open `Package.swift` in Xcode to edit and debug.

## How it works

- Reads each folder's OAuth token from the keychain via `/usr/bin/security`: `Claude Code-credentials` for `~/.claude`, `Claude Code-credentials-<first 8 hex chars of sha256(folder path)>` for other folders. Falls back to `<folder>/.credentials.json`.
- Polls `GET https://api.anthropic.com/api/oauth/usage` every 3 minutes by default (configurable in Settings), the same undocumented endpoint Claude Code's `/usage` uses. It may change without notice.
- Finds sessions from the transcripts in each folder's `projects/`: the timestamp of the last assistant message is the last request, read from the end of transcripts changed in the past hour, every 30 seconds. Sessions in paid usage overage use a 5-minute cache, which the timers don't account for.
- The token is never refreshed by this app, because refreshing rotates it and would log Claude Code out. When it expires, the app shows the last values and asks you to run `claude`.

## Releasing

Updates are delivered with [Sparkle](https://sparkle-project.org). Releases publish a DMG for Apple Silicon, Intel and universal Macs, plus EdDSA-signed appcasts: `appcast.xml` for Apple Silicon and `appcast-x86_64.xml` for Intel. The app reads the appcast of the latest release for the architecture it runs as, so universal installs update to that architecture's build. The repo must be public.

One-time setup:

1. Run `make updater-key`. It stores a private key in your login keychain and prints the public key. Back up the private key; without it, installed copies can't be updated.
2. Export the private key with `.build/artifacts/sparkle/Sparkle/bin/generate_keys --account claude-usage-bar -x sparkle.key`.
3. In the repo's Settings → Secrets and variables → Actions, add the secret `SPARKLE_PRIVATE_KEY` with the contents of `sparkle.key` and the variable `SPARKLE_PUBLIC_KEY` with the public key. Then delete `sparkle.key`.

To release, push a `v*` tag, e.g. `git tag v1.0.0 && git push origin v1.0.0`. The Release workflow runs the tests, builds the DMGs with the tag's version and publishes them with the appcasts. Local builds have no public key and don't check for updates.

## Website

`website/` is the project site, a [TanStack Start](https://tanstack.com/start) app prerendered for Vercel. It needs Node 24+ and pnpm.

```sh
make website-dev    # run it at http://localhost:3000
make website-build  # build .vercel/output
make website-lint   # eslint, prettier check, tsc
```

Vercel deploys it through its Git integration with `website` as the project's Root Directory; `website/vercel.json` holds the build settings.

## License

[MIT](LICENSE)
