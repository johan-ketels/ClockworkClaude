import Foundation

struct RunRecord: Identifiable {
    let id: String // timestamp string
    let jobName: String
    let timestamp: Date
    let output: String
    let errorOutput: String?
    let exitCode: Int?
    let duration: TimeInterval?
    var isArchived: Bool = false

    var succeeded: Bool {
        exitCode == 0
    }

    var displayTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var shortTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }

    var displayDuration: String {
        guard let duration else { return "—" }
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        } else {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
    }

    var outputPreview: String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "No output" }
        let firstLine = trimmed.prefix(while: { $0 != "\n" })
        return String(firstLine.prefix(80))
    }
}
