import Foundation
import Observation

struct JobStatus {
    var isLoaded: Bool = false
    var lastExitCode: Int? = nil
    var pid: Int? = nil
}

@Observable
final class LaunchdService {
    private(set) var statusCache: [String: JobStatus] = [:]

    // MARK: - Install / Uninstall

    func install(_ job: Job) {
        let plist = PlistGenerator.generate(for: job)
        let path = job.plistPath

        do {
            try plist.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write plist: \(error)")
            return
        }

        runLaunchctl(["load", path])
    }

    func uninstall(_ job: Job) {
        let path = job.plistPath
        runLaunchctl(["unload", path])

        try? FileManager.default.removeItem(atPath: path)
    }

    func load(_ job: Job) {
        runLaunchctl(["load", job.plistPath])
    }

    func unload(_ job: Job) {
        runLaunchctl(["unload", job.plistPath])
    }

    func toggle(_ job: Job) {
        if job.enabled {
            install(job)
        } else {
            unload(job)
        }
    }

    func runNow(_ job: Job) {
        // Clear log before running
        try? "".write(toFile: job.stdoutLogPath, atomically: true, encoding: .utf8)
        try? "".write(toFile: job.stderrLogPath, atomically: true, encoding: .utf8)

        runLaunchctl(["start", job.launchdLabel])
    }

    // MARK: - Status

    func status(label: String) -> JobStatus {
        let output = runLaunchctlCapture(["list", label])

        guard let output = output, !output.contains("Could not find service") else {
            return JobStatus(isLoaded: false)
        }

        // Parse launchctl list output
        // Format: PID\tStatus\tLabel or tabular key-value
        var status = JobStatus(isLoaded: true)

        // Try parsing single-service output
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\"PID\"") || trimmed.contains("PID") {
                if let pid = extractIntValue(from: trimmed) {
                    status.pid = pid
                }
            }
            if trimmed.hasPrefix("\"LastExitStatus\"") || trimmed.contains("LastExitStatus") {
                if let code = extractIntValue(from: trimmed) {
                    status.lastExitCode = code
                }
            }
        }

        // Also try tab-separated format (launchctl list with label)
        if lines.count >= 1 {
            let parts = lines[0].components(separatedBy: "\t")
            if parts.count >= 3 {
                if let pid = Int(parts[0]), pid > 0 {
                    status.pid = pid
                }
                if let exitCode = Int(parts[1]) {
                    status.lastExitCode = exitCode
                }
            }
        }

        return status
    }

    func refreshStatus(for jobs: [Job]) {
        for job in jobs {
            statusCache[job.launchdLabel] = status(label: job.launchdLabel)
        }
    }

    func cachedStatus(for job: Job) -> JobStatus {
        statusCache[job.launchdLabel] ?? JobStatus()
    }

    // MARK: - Helpers

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            print("Failed to run launchctl: \(error)")
            return -1
        }
    }

    private func runLaunchctlCapture(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func extractIntValue(from line: String) -> Int? {
        let components = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for component in components {
            if let value = Int(component) {
                return value
            }
        }
        return nil
    }
}
