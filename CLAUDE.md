# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build                              # debug build
.build/debug/ClockworkClaude             # run debug binary
VERSION=1.0.0 bash scripts/build-app.sh  # .app bundle + DMG + zip
make app                                 # shorthand for above
make clean                               # remove build/ and .build/
```

No external dependencies — pure Foundation/AppKit. Swift 5.9, macOS 14+ target.

### Release

Push a `v*` tag to trigger the GitHub Actions workflow that builds and publishes DMG + zip as release assets:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Architecture

ClockworkClaude is a native macOS SwiftUI app that provides a GUI for managing scheduled launchd jobs that run `claude -p`. It handles the full lifecycle: creating jobs, generating launchd plists, monitoring live output, and browsing run history.

### State Management

Uses Swift's `@Observable` macro (not `ObservableObject`). Three core services are `@State`-owned in `ClockworkClaudeApp` and injected via `.environment()`:

- **JobStore** — CRUD + JSON persistence to `~/.clockworkclaude/jobs.json`
- **LaunchdService** — launchctl integration, plist install/unload, status polling with cache. Also defines `JobStatus` struct.
- **CommandScanner** — discovers slash command `.md` files from project, global, and plugin directories

Additional services created locally in views:

- **HistoryService** — parses timestamped run logs from `~/.clockworkclaude/history/<name>/`
- **LogWatcher** — real-time file monitoring via `DispatchSourceFileSystemObject` with polling fallback

`MainView` polls launchd status every 5 seconds via a `Timer` to keep the UI in sync.

### View Structure

`MainView` uses a fixed 3-panel layout: sidebar (job cards) + detail pane (`JobDetailView`) with a unified top bar.

`JobDetailView` has two modes driven by `job: Job?`:
- **Filtered** (`job != nil`): single job header with actions, live output row, next-run countdown, filtered history
- **All-jobs** (`job == nil`): "All Runs" header, upcoming scheduled runs for all jobs, merged history with job-name badges

The detail pane itself is an `HSplitView`: run list (left) + output panel (right).

`JobFormView` is shown as a sheet for create/edit, composed of `ScheduleEditor`, `PermissionEditor`, `PromptEditor`, and `SlashCommandPanel`.

### Key Helpers

- **PlistGenerator** — generates launchd plist XML with a shell wrapper script that archives stdout/stderr/exitcode to timestamped history files
- **Theme** — centralized design tokens (dark warm palette, monospaced typography, spacing constants). All colors use `Color(hex:)` extension.

### Data Paths

| Data | Location |
|------|----------|
| Job config | `~/.clockworkclaude/jobs.json` |
| Plists | `~/Library/LaunchAgents/com.clockworkclaude.<name>.plist` |
| Live logs | `/tmp/com.clockworkclaude.<name>.{out,err}.log` |
| History | `~/.clockworkclaude/history/<name>/<timestamp>.{log,err.log,exitcode}` |
| App bundle output | `build/` (git-ignored) |

### Patterns to Follow

- Services are `@Observable final class`, views access them via `@Environment` or pass as parameters
- `Job` is a value type (`struct`, `Codable`, `Hashable`) — mutations go through `JobStore.update()`
- Views that need a `Job` take it as `Job?` when they support an "all" mode (see `JobDetailView`)
- History record IDs are prefixed with job name (`jobName_timestamp`) for cross-job uniqueness
- Use `Theme.*` constants for all colors, fonts, and spacing — never hardcode values
- The app title uses the custom "Timepiece" font (`Resources/Timepiece.TTF`), registered at runtime via `CTFontManagerRegisterFontsForURL` in `ClockworkClaudeApp.init()`. All other UI text uses SF Mono via Theme.
- `Resources/logo.svg` and `Resources/Timepiece.TTF` are bundled via SPM's `.copy()` resource rules and loaded from `Bundle.module` (debug) or `Bundle.main` (release .app). `Resources/AppIcon.icns` is the Dock/Finder icon, copied into the .app bundle by `scripts/build-app.sh`.
