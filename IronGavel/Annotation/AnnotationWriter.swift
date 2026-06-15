import Foundation

struct AnnotationWriter {
    func write(_ document: AnnotationDocument, to annotationsFolder: URL) throws {
        try FileManager.default.createDirectory(at: annotationsFolder, withIntermediateDirectories: true)

        let finalURL = annotationsFolder.appendingPathComponent("\(document.exhibitId).json")
        let tmpURL = annotationsFolder.appendingPathComponent("\(document.exhibitId).json.tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)

        try writeCoordinated(data: data, to: tmpURL)
        _ = try? FileManager.default.removeItem(at: finalURL)
        try FileManager.default.moveItem(at: tmpURL, to: finalURL)
    }

    private func writeCoordinated(data: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        var writeError: Error?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordinated in
            do {
                try data.write(to: coordinated, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordError { throw coordError }
        if let writeError { throw writeError }
    }
}
