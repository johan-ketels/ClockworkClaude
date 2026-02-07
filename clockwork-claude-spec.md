# Clockwork Claude — Spec & Prompt

## What is it?

A native macOS desktop app built in **Swift/SwiftUI** that provides a GUI for creating, managing, and monitoring launchd jobs that run Claude Code (`claude -p`). Inspired by [runclauderun.com](https://runclauderun.com/) but with more control and deeper integration with Claude Code's configuration.

All jobs are prefixed with `com.clockworkclaude.*` — the app only manages its own jobs and never touches system or third-party launchd configurations.

---

## Tech stack

- **Swift / SwiftUI** — native macOS app
- **Dark theme** — terminal aesthetic, monospace typography (SF Mono), minimal and polished

---

## Core features

### 1. Job management (CRUD)

Create, list, edit, and delete scheduled Claude Code jobs.

Each job has:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Unique job name, becomes part of launchd label (`com.clockworkclaude.<name>`) |
| `prompt` | string | The prompt sent to `claude -p` |
| `model` | enum | `claude-opus-4-6`, `claude-sonnet-4-5-20250929`, `claude-haiku-4-5-20251001` |
| `directory` | string | Working directory (`WorkingDirectory` in plist) |
| `scheduleType` | enum | `interval`, `calendar`, `once` |
| `permissionPreset` | enum | `readonly`, `standard`, `full`, `yolo`, `custom` |
| `customTools` | string | Comma-separated tools when using `custom` preset |
| `maxTurns` | number | `--max-turns`, default 10 |
| `outputFormat` | enum | `text` or `json` (`--output-format`) |
| `appendSystemPrompt` | string | Optional, `--append-system-prompt` |
| `enabled` | boolean | Active/inactive job |

### 2. Scheduling

Three types:

**Interval:**
- Value + unit (minutes or hours)
- Alignment: "From load" (`StartInterval`) or "On the hour" (`StartCalendarInterval` with an array of clock times, e.g. every 2h → 00:00, 02:00, 04:00...)
- "On the hour" is only shown when unit is hours

**Calendar:**
- Weekday (optional, -1 = every day)
- Hour + minute
- Generates `StartCalendarInterval`

**Once:**
- Runs immediately on `launchctl load`
- No schedule key in the plist

### 3. Permission presets

| Preset | `--allowedTools` |
|--------|-----------------|
| Read-only | `Read,Grep,Glob,LS` |
| Standard | `Read,Write,Edit,Bash(git *)` |
| Full access | `Read,Write,Edit,MultiEdit,Bash,WebFetch,WebSearch` |
| YOLO | `--dangerously-skip-permissions` (no `--allowedTools`) |
| Custom | Free-text comma-separated tools |

YOLO mode must display a prominent warning.

### 4. Slash command integration

When the user sets a working directory:

1. Scan `<directory>/.claude/commands/` for `.md` files
2. Scan `~/.claude/commands/` for global commands
3. Display discovered commands in a panel below the directory field
4. **Autocomplete in the prompt field**: when the user types `/`, a popup menu appears with matching commands
   - Keyboard navigation: ↑↓ to browse, Enter/Tab to select, Esc to close
   - Real-time filtering based on typed input
   - Mouse click also works
5. **On selection**: Insert the **contents** of the command's `.md` file as the prompt, not the slash command itself (since `-p` doesn't support slash commands). Show a small label indicating the source file.

Button to manually rescan commands (↻ Scan).

### 5. Advanced section

Collapsible section in the job form containing:
- System prompt (`--append-system-prompt`)
- Max turns (with explanatory text)
- Output format (text/JSON)

Shows a "modified" badge if any value differs from default.

### 6. Plist generation & installation

The app must **actually create files and run commands** — not just generate text:

**Create job:**
1. Generate valid launchd plist XML
2. Write to `~/Library/LaunchAgents/com.clockworkclaude.<name>.plist`
3. Run `launchctl load <path>`

**Delete job:**
1. Run `launchctl unload <path>`
2. Delete the plist file

**Toggle (enable/disable):**
- Enable: `launchctl load`
- Disable: `launchctl unload`

**Run now:** `launchctl start <label>`

Plist files must include:
- `WorkingDirectory`
- `ProgramArguments` with the complete `claude` command
- `StandardOutPath` → `/tmp/com.clockworkclaude.<name>.out.log`
- `StandardErrorPath` → `/tmp/com.clockworkclaude.<name>.err.log`
- `EnvironmentVariables.PATH` including `/usr/local/bin`, `/opt/homebrew/bin`

### 7. Terminal / output view

Each job should have a built-in terminal view showing output in real time:
- Read `StandardOutPath` using tail/watch
- Scrollable, monospace, dark background
- Auto-scroll to bottom with ability to scroll up
- Show output from the most recent run
- Clear indication of whether the job is currently running or not

### 8. Job status

Show real-time status per job:
- **Active** (loaded in launchd) / **Inactive**
- Last run (timestamp)
- Exit code from last run
- Fetched via `launchctl list <label>` and parsing the output

### 9. Job list

- Card layout with: name, model badge (color-coded), status badge, schedule summary, directory name, prompt preview (truncated)
- Toggle and delete buttons directly on the card
- Click opens detail view

### 10. Detail view

Shows:
- Full job configuration
- Generated CLI command (copyable)
- Installation commands (copyable)
- Logs / terminal view
- Edit button

---

## CLI command generation

Generate the correct `claude` command based on job configuration:

```bash
claude -p \
  --model <model> \
  --max-turns <n> \
  --allowedTools "<tools>" \
  --output-format <format> \
  --append-system-prompt "<prompt>" \
  "<user prompt>"
```

Special cases:
- YOLO: replace `--allowedTools` with `--dangerously-skip-permissions`
- No system prompt: omit `--append-system-prompt`
- Text output (default): omit `--output-format`

---

## Data storage

- Job metadata stored in a local JSON file (e.g. `~/.clockworkclaude/jobs.json`)
- Plist files in `~/Library/LaunchAgents/`
- Sync state on startup — verify that plist files and launchctl state match stored metadata

---

## UI structure

```
┌─────────────────────────────────────────────────────┐
│ ⌘ Clockwork Claude         3 jobs · 2 active    [+] │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────────┐  ┌─────────────────────┐   │
│  │ daily-review        │  │ weekly-security     │   │
│  │ Sonnet 4.5  ● Active│  │ Opus 4.6   ● Active│   │
│  │ "Review commits..." │  │ "Security audit..." │   │
│  │ ⏰ Daily 09:00      │  │ ⏰ Mon 10:00       │   │
│  │ 📁 my-project       │  │ 📁 my-project      │   │
│  │            [⏸] [✕]  │  │            [⏸] [✕] │   │
│  └─────────────────────┘  └─────────────────────┘   │
│                                                     │
│  ┌─────────────────────┐                            │
│  │ nightly-cleanup     │                            │
│  │ Haiku 4.5 ○ Inactive│                            │
│  │ "Remove temp..."    │                            │
│  │ ⏰ Every 6h ⏰      │                            │
│  │ 📁 scripts          │                            │
│  │            [▶] [✕]  │                            │
│  └─────────────────────┘                            │
│                                                     │
│  ── com.clockworkclaude.* · ~/Library/LaunchAgents  │
└─────────────────────────────────────────────────────┘
```

**Job form:**
```
┌─────────────────────────────────────────────────────┐
│ New Job                                         [×] │
├─────────────────────────────────────────────────────┤
│ Job name: [daily-review    ]  Model: [Sonnet 4.5 ▾]│
│                                                     │
│ Working directory: [/Users/johan/projects/my-proj ] │
│ ┌ ⚡ Available commands ─────────── [↻ Scan] ─────┐ │
│ │ /review  /test  /docs  /security                │ │
│ └─────────────────────────────────────────────────┘ │
│                                                     │
│ Prompt: [Review all commits from the last 24h     ] │
│         [                                         ] │
│         [  ┌──────────────────────────┐           ] │
│         [  │ /review  Run code review │           ] │  ← autocomplete
│         [  │ /refactor Refactor code  │           ] │
│         [  └──────────────────────────┘           ] │
│                                                     │
│ ─── Schedule ────────────────────────────────────── │
│ [Interval] [Calendar] [Once]                        │
│ Every [1] [minutes|hours]                           │
│ [● From load] [○ On the hour]                       │
│                                                     │
│ ─── Permissions ─────────────────────────────────── │
│ [Read-only] [Standard] [Full] [⚠YOLO] [Custom]     │
│ Read  Write  Edit  Bash(git *)                      │
│                                                     │
│ ▶ Advanced                              [modified]  │
│ │ System prompt: [You are a code reviewer...]       │
│ │ Max turns: [10]  Output: [Text▾]                  │
│                                                     │
│                          [Cancel] [Create Job]      │
└─────────────────────────────────────────────────────┘
```

---

## Design

- Dark theme, warm tones (#2B2926 background, Claude-inspired palette)
- Monospace typography: SF Mono for code/values, SF Pro for headings (system-native)
- Model badges color-coded: Opus = purple, Sonnet = blue, Haiku = teal
- Status badges: Active = green with glow, Inactive = gray
- Subtle borders (rgba), no hard lines
- Animations: fade-in on elements, glow on icons
- Copyable code blocks with "Copy" button

---

## Reference: Prototype

There is a working React prototype (JSX artifact) that demonstrates the UI flow, component structure, and plist generation. It can be used as a design and data model reference but needs to be rebuilt in Swift/SwiftUI as a native macOS app.
