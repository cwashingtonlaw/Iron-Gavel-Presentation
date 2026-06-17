import Foundation

/// Assembles a self-contained trial-record package under `Trial/Record-<date>/`:
/// a freshly generated exhibit-list CSV plus copies of the audit log, dispositions,
/// and every annotated exhibit PDF. One folder the attorney can hand to the clerk or
/// archive after trial.
struct RecordExporter {
    @discardableResult
    func export(kase: Case, caseFolder: URL, stamp: String) throws -> URL {
        let fm = FileManager.default
        let trial = caseFolder.appendingPathComponent("Trial")
        let recordDir = trial.appendingPathComponent("Record-\(stamp)")
        try fm.createDirectory(at: recordDir, withIntermediateDirectories: true)

        // 1. Freshly generate the exhibit list from the live case (never stale).
        let csv = ExhibitListExporter().csv(for: kase)
        try Data(csv.utf8).write(to: recordDir.appendingPathComponent(ExhibitListExporter.fileName),
                                 options: .atomic)

        // 2. Copy the record sidecars when present.
        for name in [AuditLog.fileName, DispositionLog.fileName] {
            let src = trial.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = recordDir.appendingPathComponent(name)
            try? fm.removeItem(at: dst)
            try fm.copyItem(at: src, to: dst)
        }

        // 3. Copy annotated exhibit PDFs into an Annotated/ subfolder.
        let annotatedSrc = trial.appendingPathComponent("Annotated")
        let pdfs = (try? fm.contentsOfDirectory(at: annotatedSrc, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "pdf" } ?? []
        if !pdfs.isEmpty {
            let annotatedDst = recordDir.appendingPathComponent("Annotated")
            try fm.createDirectory(at: annotatedDst, withIntermediateDirectories: true)
            for pdf in pdfs {
                let dst = annotatedDst.appendingPathComponent(pdf.lastPathComponent)
                try? fm.removeItem(at: dst)
                try fm.copyItem(at: pdf, to: dst)
            }
        }
        return recordDir
    }
}
