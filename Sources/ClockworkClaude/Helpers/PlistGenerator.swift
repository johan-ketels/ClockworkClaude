import Foundation

enum PlistGenerator {
    static func generate(for job: Job) -> String {
        let programArgs = buildProgramArguments(for: job)
        let label = job.launchdLabel
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        var plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(escapeXML(label))</string>
            <key>ProgramArguments</key>
            <array>
        \(programArgs.map { "        <string>\(escapeXML($0))</string>" }.joined(separator: "\n"))
            </array>
            <key>WorkingDirectory</key>
            <string>\(escapeXML(job.directory))</string>
            <key>StandardOutPath</key>
            <string>/dev/null</string>
            <key>StandardErrorPath</key>
            <string>/dev/null</string>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>\(escapeXML(homeDir))/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
            </dict>
        """

        // Schedule
        switch job.scheduleType {
        case .interval:
            if job.intervalAlignment == .fromLoad {
                let seconds = job.intervalUnit == .hours
                    ? job.intervalValue * 3600
                    : job.intervalValue * 60
                plist += """

                    <key>StartInterval</key>
                    <integer>\(seconds)</integer>
                """
            } else {
                // On the hour alignment — generate calendar intervals
                let times = onTheHourTimes(every: job.intervalValue)
                plist += """

                    <key>StartCalendarInterval</key>
                    <array>
                """
                for hour in times {
                    plist += """

                            <dict>
                                <key>Hour</key>
                                <integer>\(hour)</integer>
                                <key>Minute</key>
                                <integer>0</integer>
                            </dict>
                    """
                }
                plist += """

                    </array>
                """
            }
        case .calendar:
            plist += """

                <key>StartCalendarInterval</key>
                <dict>
            """
            if job.calendarWeekday >= 0 {
                plist += """

                    <key>Weekday</key>
                    <integer>\(job.calendarWeekday)</integer>
                """
            }
            plist += """

                    <key>Hour</key>
                    <integer>\(job.calendarHour)</integer>
                    <key>Minute</key>
                    <integer>\(job.calendarMinute)</integer>
                </dict>
            """
        case .once:
            // No schedule — runs on load
            break
        }

        plist += """

        </dict>
        </plist>
        """

        return plist
    }

    private static func buildProgramArguments(for job: Job) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let claudePath = "\(home)/.local/bin/claude"
        let histDir = "\(home)/.clockworkclaude/history/\(job.name)"

        // Build the claude command with output management:
        // 1. Truncate current output file (so LogView shows fresh output)
        // 2. Run claude, capture output
        // 3. Save a timestamped copy to history directory
        var claudeCmd = "\(shellQuote(claudePath)) -p"
        claudeCmd += " --model \(shellQuote(job.model.rawValue))"
        claudeCmd += " --max-turns \(job.maxTurns)"

        if job.permissionPreset == .yolo {
            claudeCmd += " --dangerously-skip-permissions"
        } else {
            let tools: String
            if job.permissionPreset == .custom {
                tools = job.customTools
            } else {
                tools = job.permissionPreset.tools ?? ""
            }
            if !tools.isEmpty {
                claudeCmd += " --allowedTools \(shellQuote(tools))"
            }
        }

        if job.outputFormat == .json {
            claudeCmd += " --output-format json"
        }

        if !job.appendSystemPrompt.isEmpty {
            claudeCmd += " --append-system-prompt \(shellQuote(job.appendSystemPrompt))"
        }

        let outLog = job.stdoutLogPath
        let errLog = job.stderrLogPath

        let script = """
        mkdir -p \(shellQuote(histDir))
        TS=$(date +%Y-%m-%d_%H-%M-%S)
        echo \(shellQuote(job.prompt)) | \(claudeCmd) > \(shellQuote(outLog)) 2> \(shellQuote(errLog))
        EXIT_CODE=$?
        cp \(shellQuote(outLog)) \(shellQuote(histDir))/"$TS".log
        if [ -s \(shellQuote(errLog)) ]; then cp \(shellQuote(errLog)) \(shellQuote(histDir))/"$TS".err.log; fi
        echo "$EXIT_CODE" > \(shellQuote(histDir))/"$TS".exitcode
        exit $EXIT_CODE
        """

        return ["/bin/sh", "-c", script]
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func onTheHourTimes(every hours: Int) -> [Int] {
        guard hours > 0 && hours <= 24 else { return [0] }
        var times: [Int] = []
        var h = 0
        while h < 24 {
            times.append(h)
            h += hours
        }
        return times
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
