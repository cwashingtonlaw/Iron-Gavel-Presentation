import Foundation

/// Imports source files into a case: copies them into `Exhibits/`, detects media
/// type, creates exhibits with auto-assigned ids, and rewrites the manifest.
struct ExhibitImporter {
    enum ImportError: Error { case cannotLoadCase, copyFailed(String) }

    private let writer = CaseManifestWriter()
    private let loader = CaseLoader()

    @discardableResult
    func importFiles(_ sources: [URL], into caseFolder: URL, defaultParty: Party = .defense) throws -> Case {
        let existingCase: Case
        do { existingCase = try loader.load(folderURL: caseFolder) }
        catch { throw ImportError.cannotLoadCase }

        var exhibits = existingCase.exhibits
        let exhibitsDir = caseFolder.appendingPathComponent("Exhibits")
        try FileManager.default.createDirectory(at: exhibitsDir, withIntermediateDirectories: true)

        for src in sources {
            let destName = uniqueName(for: src.lastPathComponent, in: exhibitsDir)
            let dest = exhibitsDir.appendingPathComponent(destName)
            do { try FileManager.default.copyItem(at: src, to: dest) }
            catch { throw ImportError.copyFailed(src.lastPathComponent) }

            let exhibit = Exhibit(
                id: ExhibitIDAllocator.nextID(existing: exhibits, party: defaultParty),
                party: defaultParty,
                description: (destName as NSString).deletingPathExtension,
                file: "Exhibits/\(destName)",
                witness: nil, bates: nil,
                status: .pending,
                mediaType: MediaTypeDetector.detect(url: dest),
                objection: nil, ruling: nil, notes: nil
            )
            exhibits.append(exhibit)
        }

        let updated = Case(contractVersion: existingCase.contractVersion,
                           case: existingCase.`case`,
                           generated: existingCase.generated,
                           pathBase: existingCase.pathBase,
                           exhibits: exhibits)
        try writer.write(updated, to: caseFolder)
        return updated
    }

    private func uniqueName(for name: String, in dir: URL) -> String {
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path) else { return name }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var i = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)"
            if !FileManager.default.fileExists(atPath: dir.appendingPathComponent(candidate).path) { return candidate }
            i += 1
        }
    }
}
