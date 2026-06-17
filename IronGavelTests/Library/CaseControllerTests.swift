import XCTest
@testable import IronGavel

@MainActor
final class CaseControllerTests: XCTestCase {
    private func writableCase() throws -> (state: AppState, folder: URL, root: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("igcc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let folder = try CaseStore(root: root).create(name: "Doe", now: "t")
        let ex = Exhibit(id: "D-001", party: .defense, description: "x", file: "Exhibits/x.pdf",
                         witness: nil, bates: nil, status: .admitted, mediaType: .pdf,
                         objection: nil, ruling: nil, notes: nil)
        let base = try CaseLoader().load(folderURL: folder)
        let kase = Case(contractVersion: base.contractVersion, case: base.`case`,
                        generated: base.generated, pathBase: base.pathBase, exhibits: [ex])
        try CaseManifestWriter().write(kase, to: folder)
        let state = AppState()
        state.apply(case: kase, folder: folder)
        state.select(ex)
        return (state, folder, root)
    }

    func test_toggleKey_persists_and_updates_state() throws {
        let (state, folder, root) = try writableCase()
        defer { try? FileManager.default.removeItem(at: root) }

        CaseController(state: state).toggleKey("D-001")

        XCTAssertEqual(state.currentCase?.exhibits.first?.isKey, true)
        XCTAssertEqual(try CaseLoader().load(folderURL: folder).exhibits.first?.isKey, true)
    }

    func test_setFolder_persists() throws {
        let (state, folder, root) = try writableCase()
        defer { try? FileManager.default.removeItem(at: root) }

        CaseController(state: state).setFolder("Witness A", for: "D-001")

        XCTAssertEqual(state.currentCase?.exhibits.first?.folder, "Witness A")
        XCTAssertEqual(try CaseLoader().load(folderURL: folder).exhibits.first?.folder, "Witness A")
    }
}
