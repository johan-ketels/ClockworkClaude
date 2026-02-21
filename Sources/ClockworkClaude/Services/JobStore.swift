import Foundation
import Observation

@Observable
final class JobStore {
    var jobs: [Job] = []

    private let storageDir: URL
    private let storageFile: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        storageDir = home.appendingPathComponent(".clockworkclaude")
        storageFile = storageDir.appendingPathComponent("jobs.json")
        load()
    }

    // MARK: - CRUD

    func add(_ job: Job) {
        jobs.append(job)
        save()
    }

    func update(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
            save()
        }
    }

    func delete(_ job: Job) {
        jobs.removeAll { $0.id == job.id }
        save()
    }

    func job(byName name: String) -> Job? {
        jobs.first { $0.name == name }
    }

    // MARK: - Persistence

    func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storageFile.path) else { return }

        do {
            let data = try Data(contentsOf: storageFile)
            jobs = try JSONDecoder().decode([Job].self, from: data)
        } catch {
            print("Failed to load jobs: \(error)")
        }
    }

    func save() {
        let fm = FileManager.default

        if !fm.fileExists(atPath: storageDir.path) {
            try? fm.createDirectory(at: storageDir, withIntermediateDirectories: true)
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(jobs)
            try data.write(to: storageFile, options: .atomic)
        } catch {
            print("Failed to save jobs: \(error)")
        }
    }

    // MARK: - Sync

    func syncWithSystem(launchdService: LaunchdService) {
        for i in jobs.indices {
            let status = launchdService.status(label: jobs[i].launchdLabel)
            let plistExists = FileManager.default.fileExists(atPath: jobs[i].plistPath)

            if jobs[i].enabled && !plistExists {
                // Plist was deleted externally — reinstall
                launchdService.install(jobs[i])
            } else if !jobs[i].enabled && status.isLoaded {
                // Job was loaded externally — uninstall it
                launchdService.uninstall(jobs[i])
            }
        }

        // Clean up orphaned plist files that don't match any known job
        cleanOrphanedPlists(launchdService: launchdService)
    }

    private func cleanOrphanedPlists(launchdService: LaunchdService) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let launchAgentsDir = home.appendingPathComponent("Library/LaunchAgents")
        let prefix = "com.clockworkclaude."

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: launchAgentsDir.path) else {
            return
        }

        let knownFilenames = Set(jobs.map(\.plistFilename))

        for file in files where file.hasPrefix(prefix) && file.hasSuffix(".plist") {
            if !knownFilenames.contains(file) {
                let fullPath = launchAgentsDir.appendingPathComponent(file).path
                print("Removing orphaned plist: \(file)")
                launchdService.uninstallPlist(atPath: fullPath)
            }
        }
    }

    var activeCount: Int {
        jobs.filter(\.enabled).count
    }
}
