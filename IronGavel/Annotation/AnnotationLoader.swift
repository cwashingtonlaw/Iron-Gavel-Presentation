import Foundation

struct AnnotationLoader {
    func load(annotationsFolder: URL, exhibitId: String) throws -> AnnotationDocument {
        let fileURL = annotationsFolder.appendingPathComponent("\(exhibitId).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AnnotationDocument.empty(exhibitId: exhibitId)
        }

        let data: Data
        do {
            data = try readCoordinated(url: fileURL)
        } catch {
            throw AnnotationLoadError.fileAccessDenied(path: fileURL.path)
        }

        let doc: AnnotationDocument
        do {
            doc = try JSONDecoder().decode(AnnotationDocument.self, from: data)
        } catch {
            throw AnnotationLoadError.decodeFailed(message: String(describing: error))
        }

        guard doc.contractVersion == AnnotationContractVersion.supported else {
            throw AnnotationLoadError.unsupportedContractVersion(
                found: doc.contractVersion,
                supported: AnnotationContractVersion.supported
            )
        }

        return doc
    }

    private func readCoordinated(url: URL) throws -> Data {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        var data: Data?
        var readError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordinatedURL in
            do { data = try Data(contentsOf: coordinatedURL) } catch { readError = error }
        }
        if let coordError { throw coordError }
        if let readError { throw readError }
        return data ?? Data()
    }
}
