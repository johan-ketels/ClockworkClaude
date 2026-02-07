import Foundation
import Observation

@Observable
final class HistoryService {
    var records: [RunRecord] = []

    private let baseDir: URL
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private var reloadWork: DispatchWorkItem?
    private var currentMode: WatchMode = .none

    private enum WatchMode {
        case none
        case single(String)
        case all([String])
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        baseDir = home.appendingPathComponent(".clockworkclaude/history")
    }

    deinit {
        stopWatching()
    }

    // MARK: - Load

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

    // MARK: - Directory Watching

    func watchHistory(for jobName: String) {
        stopWatching()
        currentMode = .single(jobName)
        let dir = baseDir.appendingPathComponent(jobName)
        ensureDirectory(dir)
        watchDirectory(at: dir)
    }

    func watchAllHistory(jobNames: [String]) {
        stopWatching()
        currentMode = .all(jobNames)
        for name in jobNames {
            let dir = baseDir.appendingPathComponent(name)
            ensureDirectory(dir)
            watchDirectory(at: dir)
        }
    }

    func stopWatching() {
        reloadWork?.cancel()
        reloadWork = nil
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        for fd in fileDescriptors {
            close(fd)
        }
        fileDescriptors.removeAll()
        currentMode = .none
    }

    private func watchDirectory(at url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptors.append(fd)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .link],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }

        sources.append(source)
        source.resume()
    }

    private func scheduleReload() {
        reloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reloadCurrent()
        }
        reloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func reloadCurrent() {
        switch currentMode {
        case .none:
            break
        case .single(let name):
            loadHistory(for: name)
        case .all(let names):
            loadAllHistory(jobNames: names)
        }
    }

    private func ensureDirectory(_ url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
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
