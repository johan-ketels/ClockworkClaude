import Foundation

struct SlashCommand: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let source: String // "project" or "global"
    let filePath: String
    let content: String

    var displayName: String {
        "/\(name)"
    }
}
