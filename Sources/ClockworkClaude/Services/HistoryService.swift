import Foundation
import Observation

@Observable
final class HistoryService {
    var records: [RunRecord] = []

    private let baseDir: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        baseDir = home.appendingPathComponent(".clockworkclaude/history")
    }

    func loadHistory(for jobName: String) {
        records = parseRecords(for: jobName)
    }

    func loadAllHistory(jobNames: [String]) {
        var all: [RunRecord] = []
        for name in jobNames {
            all.append(contentsOf: parseRecords(for: name))
        }
        records = all.sorted { $0.timestamp > $1.timestamp }
    }

    private func parseRecords(for jobName: String) -> [RunRecord] {
        let jobDir = baseDir.appendingPathComponent(jobName)
        let fm = FileManager.default

        guard fm.fileExists(atPath: jobDir.path) else { return [] }

        do {
            let files = try fm.contentsOfDirectory(atPath: jobDir.path)
            let logFiles = files.filter { $0.hasSuffix(".log") && !$0.hasSuffix(".err.log") }.sorted().reversed()

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

            return logFiles.compactMap { filename -> RunRecord? in
                let ts = String(filename.dropLast(4)) // remove .log
                guard let date = formatter.date(from: ts) else { return nil }

                let logPath = jobDir.appendingPathComponent(filename).path
                let errPath = jobDir.appendingPathComponent("\(ts).err.log").path
                let exitCodePath = jobDir.appendingPathComponent("\(ts).exitcode").path

                let output = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""

                var errorOutput: String? = nil
                if fm.fileExists(atPath: errPath) {
                    errorOutput = try? String(contentsOfFile: errPath, encoding: .utf8)
                }

                var exitCode: Int? = nil
                if let exitStr = try? String(contentsOfFile: exitCodePath, encoding: .utf8) {
                    exitCode = Int(exitStr.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                // Calculate duration from exitcode file modification time
                var duration: TimeInterval? = nil
                if let attrs = try? fm.attributesOfItem(atPath: exitCodePath),
                   let modDate = attrs[.modificationDate] as? Date {
                    let d = modDate.timeIntervalSince(date)
                    if d > 0 { duration = d }
                }

                return RunRecord(
                    id: "\(jobName)_\(ts)",
                    jobName: jobName,
                    timestamp: date,
                    output: output,
                    errorOutput: errorOutput,
                    exitCode: exitCode,
                    duration: duration
                )
            }
        } catch {
            return []
        }
    }

    func clearHistory(for jobName: String) {
        let jobDir = baseDir.appendingPathComponent(jobName)
        try? FileManager.default.removeItem(at: jobDir)
        records = []
    }
}
