# Clockwork Claude

A native macOS app for scheduling and managing [Claude Code](https://docs.anthropic.com/en/docs/claude-code) jobs via launchd.

Create recurring prompts, monitor their output, and manage everything from a single GUI — no crontabs, no terminal juggling.

## What it does

- **Create scheduled Claude Code jobs** with a visual editor — pick a model, set a prompt, choose a schedule
- **Three schedule types**: interval (every N minutes/hours), calendar (specific day and time), or run once
- **Permission presets**: read-only, standard, full access, YOLO, or define custom tool access
- **Slash command & skill discovery**: scans your project and global `.claude/commands/` and `.claude/skills/` directories, plus installed plugins — click to insert into the prompt
- **Live output**: tail stdout/stderr in real time with auto-scroll
- **Run history**: browse past runs with output, duration, and exit status across all jobs
- **Upcoming runs**: see what's scheduled next at a glance, with live countdown timers

## How it works

Each job becomes a launchd plist at `~/Library/LaunchAgents/com.clockworkclaude.<name>.plist`. The app generates the plist, writes it, and manages it with `launchctl load/unload/start`. Job metadata is stored in `~/.clockworkclaude/jobs.json`.

The app only manages its own `com.clockworkclaude.*` jobs — it never touches system or third-party launchd configurations.

## Requirements

- macOS 14+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and on your PATH

## Build & run

```bash
swift build
.build/debug/ClockworkClaude
```

### App bundle (DMG)

```bash
VERSION=0.1.0 bash scripts/build-app.sh
open "build/Clockwork Claude.app"
```

This creates a signed `.app` bundle, a `.dmg` with Applications symlink, and a `.zip` in `build/`. You can also run `make app`.

### Releases

Push a version tag to trigger a GitHub Actions build that publishes the DMG and zip as release assets:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Tech

- Swift / SwiftUI
- Warm dark theme inspired by Claude's UI
- SF Mono typography
- No dependencies — just Apple frameworks
