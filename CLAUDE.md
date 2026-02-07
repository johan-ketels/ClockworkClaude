# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
swift build
```

No external dependencies — pure Foundation/AppKit. Swift 5.9, macOS 14+ target.

## Architecture

ClockworkClaude is a native macOS SwiftUI app that provides a GUI for managing scheduled launchd jobs that run `claude -p`. It handles the full lifecycle: creating jobs, generating launchd plists, monitoring live output, and browsing run history.

### State Management

Uses Swift's `@Observable` macro (not `ObservableObject`). Services are injected via SwiftUI `@Environment`:

- **JobStore** — CRUD + JSON persistence to `~/.clockworkclaude/jobs.json`
- **LaunchdService** — launchctl integration, plist install/unload, status polling with cache
- **HistoryService** — parses timestamped run logs from `~/.clockworkclaude/history/<name>/`
- **LogWatcher** — real-time file monitoring via `DispatchSourceFileSystemObject` with polling fallback
- **CommandScanner** — discovers slash command `.md` files from project, global, and plugin directories

### View Structure

`MainView` uses `NavigationSplitView`: sidebar (job cards) + detail pane (`JobDetailView`).

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

### Patterns to Follow

- Services are `@Observable final class`, views access them via `@Environment` or pass as parameters
- `Job` is a value type (`struct`, `Codable`, `Hashable`) — mutations go through `JobStore.update()`
- Views that need a `Job` take it as `Job?` when they support an "all" mode (see `JobDetailView`)
- History record IDs are prefixed with job name (`jobName_timestamp`) for cross-job uniqueness
- Use `Theme.*` constants for all colors, fonts, and spacing — never hardcode values
