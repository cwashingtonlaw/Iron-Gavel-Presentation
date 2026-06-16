import Foundation

struct CaseLoader {
    func load(folderURL: URL) throws -> Case {
        let rootSidecar = folderURL.appendingPathComponent("exhibits.json")
        let trialSidecar = folderURL.appendingPathComponent("Trial/exhibits.json")
        let sidecarURL: URL
        if FileManager.default.fileExists(atPath: rootSidecar.path) {
            sidecarURL = rootSidecar
        } else if FileManager.default.fileExists(atPath: trialSidecar.path) {
            sidecarURL = trialSidecar
        } else {
            throw CaseLoadError.missingSidecar(path: rootSidecar.path)
        }

        let data: Data
        do {
            data = try readCoordinated(url: sidecarURL)
        } catch {
            throw CaseLoadError.fileAccessDenied(path: sidecarURL.path)
        }

        let kase: Case
        do {
            kase = try JSONDecoder().decode(Case.self, from: data)
        } catch {
            throw CaseLoadError.decodeFailed(message: String(describing: error))
        }

        guard kase.contractVersion == ContractVersion.supported else {
            throw CaseLoadError.unsupportedContractVersion(
                found: kase.contractVersion,
                supported: ContractVersion.supported
            )
        }

        return kase
    }

    private func readCoordinated(url: URL) throws -> Data {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        var data: Data?
        var readError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordinatedURL in
            do {
                data = try Data(contentsOf: coordinatedURL)
            } catch {
                readError = error
            }
        }
        if let coordError { throw coordError }
        if let readError { throw readError }
        return data ?? Data()
    }
}
