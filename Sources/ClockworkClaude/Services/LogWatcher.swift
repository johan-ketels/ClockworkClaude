import Foundation
import Observation

@Observable
final class LogWatcher {
    var logContent: String = ""
    var isRunning: Bool = false

    private var source: DispatchSourceFileSystemObject?
    private var fileHandle: FileHandle?
    private var currentPath: String?
    private var timer: Timer?

    func watch(path: String) {
        stop()
        currentPath = path

        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            fm.createFile(atPath: path, contents: nil)
        }

        // Read existing content
        if let data = fm.contents(atPath: path),
           let text = String(data: data, encoding: .utf8) {
            logContent = text
        }

        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        fileHandle = handle
        handle.seekToEndOfFile()

        let fd = handle.fileDescriptor
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename],
            queue: .main
        )

        src.setEventHandler { [weak self] in
            self?.readNewContent()
        }

        src.setCancelHandler { [weak self] in
            self?.fileHandle?.closeFile()
            self?.fileHandle = nil
        }

        source = src
        src.resume()

        // Also poll periodically as a fallback
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.readNewContent()
        }
    }

    func stop() {
        source?.cancel()
        source = nil
        timer?.invalidate()
        timer = nil
        fileHandle?.closeFile()
        fileHandle = nil
        currentPath = nil
    }

    func clear() {
        logContent = ""
        if let path = currentPath {
            try? "".write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    private func readNewContent() {
        guard let path = currentPath else { return }

        // Re-read entire file to handle truncation/rotation
        if let data = FileManager.default.contents(atPath: path),
           let text = String(data: data, encoding: .utf8) {
            if text != logContent {
                logContent = text
            }
        }
    }

    deinit {
        stop()
    }
}
