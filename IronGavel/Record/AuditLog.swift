import Foundation

/// Append-only, timestamped record of courtroom actions (publish/blank/restore/
/// disposition) written to <CASE_ROOT>/Trial/audit-log.jsonl for making a record.
struct AuditLog {
    static let fileName = "audit-log.jsonl"

    struct Event: Codable, Equatable {
        let time: String   // ISO-8601; injected by caller for testability
        let kind: String
        let detail: String
    }

    func append(_ event: Event, to caseFolder: URL) throws {
        let dir = caseFolder.appendingPathComponent("Trial")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(AuditLog.fileName)
        var data = (try? Data(contentsOf: url)) ?? Data()
        data.append(try JSONEncoder().encode(event))
        data.append(0x0A) // newline
        try data.write(to: url, options: .atomic)
    }

    func load(from caseFolder: URL) -> [Event] {
        let url = caseFolder.appendingPathComponent("Trial/\(AuditLog.fileName)")
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap {
            try? JSONDecoder().decode(Event.self, from: Data($0.utf8))
        }
    }
}
