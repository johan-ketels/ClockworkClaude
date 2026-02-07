import Foundation
import Observation

@Observable
final class CommandScanner {
    var commands: [SlashCommand] = []
    private(set) var isScanning = false

    func scan(directory: String) {
        guard !directory.isEmpty else {
            commands = []
            return
        }

        isScanning = true
        var found: [SlashCommand] = []

        // Project commands
        let projectDir = (directory as NSString).appendingPathComponent(".claude/commands")
        found.append(contentsOf: scanDirectory(projectDir, source: "project"))

        // Global commands
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let globalDir = (home as NSString).appendingPathComponent(".claude/commands")
        found.append(contentsOf: scanDirectory(globalDir, source: "global"))

        // Plugin commands (~/.claude/plugins/marketplaces/*/plugins/*/commands/)
        found.append(contentsOf: scanPluginCommands(home))

        // Project skills
        let projectSkillsDir = (directory as NSString).appendingPathComponent(".claude/skills")
        found.append(contentsOf: scanSkillsDirectory(projectSkillsDir, source: "project"))

        // Global skills
        let globalSkillsDir = (home as NSString).appendingPathComponent(".claude/skills")
        found.append(contentsOf: scanSkillsDirectory(globalSkillsDir, source: "global"))

        commands = found
        isScanning = false
    }

    private func scanDirectory(_ path: String, source: String) -> [SlashCommand] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return [] }

        do {
            let files = try fm.contentsOfDirectory(atPath: path)
            return files
                .filter { $0.hasSuffix(".md") }
                .sorted()
                .compactMap { filename -> SlashCommand? in
                    let filePath = (path as NSString).appendingPathComponent(filename)
                    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                        return nil
                    }
                    let name = String(filename.dropLast(3)) // remove .md
                    return SlashCommand(name: name, source: source, filePath: filePath, content: content)
                }
        } catch {
            return []
        }
    }

    private func scanPluginCommands(_ home: String) -> [SlashCommand] {
        let fm = FileManager.default
        let pluginsRoot = (home as NSString).appendingPathComponent(".claude/plugins/marketplaces")
        guard fm.fileExists(atPath: pluginsRoot) else { return [] }

        var found: [SlashCommand] = []
        guard let marketplaces = try? fm.contentsOfDirectory(atPath: pluginsRoot) else { return [] }

        for marketplace in marketplaces {
            for subdir in ["plugins", "external_plugins"] {
                let base = (pluginsRoot as NSString)
                    .appendingPathComponent(marketplace)
                    .appending("/\(subdir)")
                guard let plugins = try? fm.contentsOfDirectory(atPath: base) else { continue }
                for plugin in plugins {
                    let commandsDir = (base as NSString)
                        .appendingPathComponent(plugin)
                        .appending("/commands")
                    let cmds = scanDirectory(commandsDir, source: plugin)
                    found.append(contentsOf: cmds)
                }
            }
        }
        return found
    }

    private func scanSkillsDirectory(_ path: String, source: String) -> [SlashCommand] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return [] }

        do {
            let entries = try fm.contentsOfDirectory(atPath: path)
            return entries.sorted().compactMap { entry -> SlashCommand? in
                let skillDir = (path as NSString).appendingPathComponent(entry)
                let skillFile = (skillDir as NSString).appendingPathComponent("SKILL.md")
                guard fm.fileExists(atPath: skillFile) else { return nil }
                guard let content = try? String(contentsOfFile: skillFile, encoding: .utf8) else { return nil }
                return SlashCommand(name: entry, source: "\(source) skill", filePath: skillFile, content: content)
            }
        } catch {
            return []
        }
    }

    func filteredCommands(for query: String) -> [SlashCommand] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty || q == "/" {
            return commands
        }
        let search = q.hasPrefix("/") ? String(q.dropFirst()) : q
        return commands.filter { $0.name.lowercased().contains(search) }
    }
}
