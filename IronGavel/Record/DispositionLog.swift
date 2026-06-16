import Foundation

/// Logs objection/ruling dispositions entered live during trial to a sidecar
/// (<CASE_ROOT>/Trial/dispositions.json). Purely additive — it never modifies the
/// generated exhibits.json or the publish gate.
struct DispositionLog {
    static let fileName = "dispositions.json"

    struct Entry: Codable, Equatable {
        let time: String       // ISO-8601; injected for testability
        let exhibitId: String
        let objection: String
        let ruling: String
        let note: String
    }

    func load(from caseFolder: URL) -> [Entry] {
        let url = caseFolder.appendingPathComponent("Trial/\(DispositionLog.fileName)")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    func append(_ entry: Entry, to caseFolder: URL) throws {
        var all = load(from: caseFolder)
        all.append(entry)
        let dir = caseFolder.appendingPathComponent("Trial")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(DispositionLog.fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(all).write(to: url, options: .atomic)
    }
}
