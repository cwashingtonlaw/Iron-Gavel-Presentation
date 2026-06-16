import Foundation

/// Generates the clerk's exhibit list (offered/admitted list) from the case.
struct ExhibitListExporter {
    static let fileName = "exhibit-list.csv"

    func csv(for kase: Case) -> String {
        var rows = ["ID,Party,Description,Witness,Bates,Status,Objection,Ruling"]
        let sorted = kase.exhibits.sorted {
            ($0.party.rawValue, $0.id) < ($1.party.rawValue, $1.id)
        }
        for e in sorted {
            let fields = [e.id, e.party.rawValue, e.description, e.witness ?? "",
                          e.bates ?? "", e.status.rawValue, e.objection ?? "", e.ruling ?? ""]
            rows.append(fields.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    @discardableResult
    func write(_ kase: Case, to caseFolder: URL) throws -> URL {
        let dir = caseFolder.appendingPathComponent("Trial")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(ExhibitListExporter.fileName)
        try Data(csv(for: kase).utf8).write(to: url, options: .atomic)
        return url
    }

    private func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}
