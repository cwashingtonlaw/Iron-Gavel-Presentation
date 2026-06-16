import Foundation

/// Writes a Case to `exhibits.json` atomically. The app's write path for all
/// manifest mutations (create / import / edit).
struct CaseManifestWriter {
    func write(_ kase: Case, to caseFolder: URL) throws {
        try FileManager.default.createDirectory(at: caseFolder, withIntermediateDirectories: true)
        let url = caseFolder.appendingPathComponent("exhibits.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(kase)
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: tmp, to: url)
    }
}
