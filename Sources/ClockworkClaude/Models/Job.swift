import Foundation

enum ClaudeModel: String, Codable, CaseIterable, Identifiable {
    case opus = "claude-opus-4-6"
    case sonnet = "claude-sonnet-4-5-20250929"
    case haiku = "claude-haiku-4-5-20251001"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus: "Opus 4.6"
        case .sonnet: "Sonnet 4.5"
        case .haiku: "Haiku 4.5"
        }
    }

    var shortName: String {
        switch self {
        case .opus: "Opus"
        case .sonnet: "Sonnet"
        case .haiku: "Haiku"
        }
    }
}

enum ScheduleType: String, Codable, CaseIterable {
    case interval
    case calendar
    case once

    var displayName: String {
        switch self {
        case .interval: "Interval"
        case .calendar: "Calendar"
        case .once: "Once"
        }
    }
}

enum IntervalUnit: String, Codable, CaseIterable {
    case minutes
    case hours

    var displayName: String {
        switch self {
        case .minutes: "minutes"
        case .hours: "hours"
        }
    }
}

enum IntervalAlignment: String, Codable, CaseIterable {
    case fromLoad
    case onTheHour

    var displayName: String {
        switch self {
        case .fromLoad: "From load"
        case .onTheHour: "On the hour"
        }
    }
}

enum PermissionPreset: String, Codable, CaseIterable {
    case readonly
    case standard
    case full
    case yolo
    case custom

    var displayName: String {
        switch self {
        case .readonly: "Read-only"
        case .standard: "Standard"
        case .full: "Full access"
        case .yolo: "YOLO"
        case .custom: "Custom"
        }
    }

    var tools: String? {
        switch self {
        case .readonly: "Read,Grep,Glob,LS"
        case .standard: "Read,Write,Edit,Bash(git *)"
        case .full: "Read,Write,Edit,MultiEdit,Bash,WebFetch,WebSearch"
        case .yolo: nil
        case .custom: nil
        }
    }
}

enum OutputFormat: String, Codable, CaseIterable {
    case text
    case json

    var displayName: String {
        switch self {
        case .text: "Text"
        case .json: "JSON"
        }
    }
}

struct Job: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var prompt: String
    var model: ClaudeModel
    var directory: String
    var scheduleType: ScheduleType
    var intervalValue: Int
    var intervalUnit: IntervalUnit
    var intervalAlignment: IntervalAlignment
    var calendarWeekday: Int
    var calendarHour: Int
    var calendarMinute: Int
    var permissionPreset: PermissionPreset
    var customTools: String
    var maxTurns: Int
    var outputFormat: OutputFormat
    var appendSystemPrompt: String
    var enabled: Bool

    var launchdLabel: String {
        "com.clockworkclaude.\(name)"
    }

    var plistFilename: String {
        "\(launchdLabel).plist"
    }

    var plistPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/LaunchAgents/\(plistFilename)"
    }

    var stdoutLogPath: String {
        "/tmp/\(launchdLabel).out.log"
    }

    var stderrLogPath: String {
        "/tmp/\(launchdLabel).err.log"
    }

    var scheduleSummary: String {
        switch scheduleType {
        case .interval:
            let unit = intervalValue == 1 ? String(intervalUnit.displayName.dropLast()) : intervalUnit.displayName
            let alignment = intervalAlignment == .onTheHour && intervalUnit == .hours ? " (on the hour)" : ""
            return "Every \(intervalValue) \(unit)\(alignment)"
        case .calendar:
            let day = calendarWeekday == -1 ? "Daily" : dayName(calendarWeekday)
            return "\(day) \(String(format: "%02d:%02d", calendarHour, calendarMinute))"
        case .once:
            return "Run once"
        }
    }

    var cliCommand: String {
        var parts = ["claude", "-p"]
        parts.append(contentsOf: ["--model", model.rawValue])
        parts.append(contentsOf: ["--max-turns", "\(maxTurns)"])

        if permissionPreset == .yolo {
            parts.append("--dangerously-skip-permissions")
        } else {
            let tools: String
            if permissionPreset == .custom {
                tools = customTools
            } else {
                tools = permissionPreset.tools ?? ""
            }
            if !tools.isEmpty {
                parts.append(contentsOf: ["--allowedTools", "\"\(tools)\""])
            }
        }

        if outputFormat == .json {
            parts.append(contentsOf: ["--output-format", "json"])
        }

        if !appendSystemPrompt.isEmpty {
            let escaped = appendSystemPrompt.replacingOccurrences(of: "\"", with: "\\\"")
            parts.append(contentsOf: ["--append-system-prompt", "\"\(escaped)\""])
        }

        let escapedPrompt = prompt.replacingOccurrences(of: "\"", with: "\\\"")
        parts.append("\"\(escapedPrompt)\"")

        return parts.joined(separator: " \\\n  ")
    }

    private func dayName(_ weekday: Int) -> String {
        switch weekday {
        case 0: "Sun"
        case 1: "Mon"
        case 2: "Tue"
        case 3: "Wed"
        case 4: "Thu"
        case 5: "Fri"
        case 6: "Sat"
        default: "Daily"
        }
    }

    static func makeDefault() -> Job {
        Job(
            id: UUID(),
            name: "",
            prompt: "",
            model: .sonnet,
            directory: "",
            scheduleType: .interval,
            intervalValue: 1,
            intervalUnit: .hours,
            intervalAlignment: .fromLoad,
            calendarWeekday: -1,
            calendarHour: 9,
            calendarMinute: 0,
            permissionPreset: .standard,
            customTools: "",
            maxTurns: 10,
            outputFormat: .text,
            appendSystemPrompt: "",
            enabled: true
        )
    }
}
