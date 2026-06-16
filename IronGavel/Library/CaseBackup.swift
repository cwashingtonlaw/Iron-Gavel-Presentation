import Foundation

/// Copies a case folder to/from a backup root (e.g. the app's iCloud container).
/// A deliberate snapshot, not live sync — so eviction can't break a case mid-trial.
struct CaseBackup {
    @discardableResult
    func backup(caseFolder: URL, to backupRoot: URL) throws -> URL {
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let dest = backupRoot.appendingPathComponent(caseFolder.lastPathComponent)
        _ = try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: caseFolder, to: dest)
        return dest
    }

    @discardableResult
    func restore(from backupFolder: URL, to casesRoot: URL) throws -> URL {
        try FileManager.default.createDirectory(at: casesRoot, withIntermediateDirectories: true)
        let dest = casesRoot.appendingPathComponent(backupFolder.lastPathComponent)
        _ = try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: backupFolder, to: dest)
        return dest
    }
}
