# Claude Usage Bar

A macOS menu bar app that shows your Claude plan usage for the 5-hour session and the weekly window.

- Blue: below 75%
- Orange: 75–99%
- Red: limit reached

The top bar in the icon is the session, the bottom bar is the week. Click it for details and reset times.

## Multiple subscriptions

Each account is a Claude Code config folder (`CLAUDE_CONFIG_DIR`), e.g. `~/.claude` and `~/.claude-work`. Manage them in **Settings…**: add folders, pick from detected `~/.claude*` folders, rename them, and choose which ones get a menu bar item. Accounts that are logged out or have an expired token are dimmed and offer a "Copy login command" button.

## Install

Download `ClaudeUsageBar.zip` from the [latest release](https://github.com/abderra7mane/claude-usage-bar/releases/latest), unzip it and move the app to `/Applications`. The app isn't notarized, so clear the quarantine flag before the first launch:

```sh
xattr -dr com.apple.quarantine /Applications/ClaudeUsageBar.app
```

## Requirements

- macOS 14+, Xcode 16+
- Claude Code logged in with a Pro/Max subscription (`/login`)

## Usage

```sh
make test      # run unit tests
make run       # build build/ClaudeUsageBar.app and open it
make install   # copy to /Applications and open it
make uninstall
make dist      # build build/ClaudeUsageBar.zip
make icon      # regenerate Resources/AppIcon.icns from Scripts/generate-icon.swift and Scripts/claude-symbol.svg
```

Open `Package.swift` in Xcode to edit and debug.

## How it works

- Reads each folder's OAuth token from the keychain via `/usr/bin/security`: `Claude Code-credentials` for `~/.claude`, `Claude Code-credentials-<first 8 hex chars of sha256(folder path)>` for other folders. Falls back to `<folder>/.credentials.json`.
- Polls `GET https://api.anthropic.com/api/oauth/usage` every 3 minutes by default (configurable in Settings), the same undocumented endpoint Claude Code's `/usage` uses. It may change without notice.
- The token is never refreshed by this app, because refreshing rotates it and would log Claude Code out. When it expires, the app shows the last values and asks you to run `claude`.

## Releasing

Push a `v*` tag, e.g. `git tag v1.0.0 && git push origin v1.0.0`. The Release workflow runs the tests, builds the app with the tag's version and attaches `ClaudeUsageBar.zip` to a new GitHub release.

## License

[MIT](LICENSE)
