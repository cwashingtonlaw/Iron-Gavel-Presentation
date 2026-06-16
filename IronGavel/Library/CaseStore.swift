import Foundation

/// Manages on-device cases under `Documents/Cases/`. Each case is a folder with an
/// `exhibits.json` manifest and an `Exhibits/` subfolder for imported files.
struct CaseStore {
    let root: URL
    private let writer = CaseManifestWriter()

    init(root: URL) { self.root = root }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.root = docs.appendingPathComponent("Cases")
    }

    func url(for name: String) -> URL { root.appendingPathComponent(name) }

    func list() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.filter {
            FileManager.default.fileExists(atPath: url(for: $0).appendingPathComponent("exhibits.json").path)
        }.sorted()
    }

    @discardableResult
    func create(name: String, now: String) throws -> URL {
        let folder = url(for: name)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Exhibits"),
                                                withIntermediateDirectories: true)
        let kase = Case(contractVersion: ContractVersion.supported,
                        case: .init(caption: name, docket: "", court: ""),
                        generated: now, pathBase: "sidecar_dir", exhibits: [])
        try writer.write(kase, to: folder)
        return folder
    }

    func delete(name: String) throws { try FileManager.default.removeItem(at: url(for: name)) }

    func rename(_ name: String, to newName: String) throws {
        try FileManager.default.moveItem(at: url(for: name), to: url(for: newName))
    }
}
