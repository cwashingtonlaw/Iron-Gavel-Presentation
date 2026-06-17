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

    private func multiExhibitCase() throws -> (state: AppState, folder: URL, root: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("igcc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let folder = try CaseStore(root: root).create(name: "Doe", now: "t")
        func ex(_ id: String) -> Exhibit {
            Exhibit(id: id, party: .defense, description: id, file: "Exhibits/\(id).pdf",
                    witness: nil, bates: nil, status: .admitted, mediaType: .pdf,
                    objection: nil, ruling: nil, notes: nil)
        }
        let base = try CaseLoader().load(folderURL: folder)
        let kase = Case(contractVersion: base.contractVersion, case: base.`case`,
                        generated: base.generated, pathBase: base.pathBase,
                        exhibits: [ex("A"), ex("B"), ex("C")])
        try CaseManifestWriter().write(kase, to: folder)
        let state = AppState()
        state.apply(case: kase, folder: folder)
        return (state, folder, root)
    }

    func test_reorder_persists_dense_order_for_section() throws {
        let (state, folder, root) = try multiExhibitCase()
        defer { try? FileManager.default.removeItem(at: root) }

        let section = state.currentCase!.exhibits   // [A, B, C], all .defense, unordered
        // Move C (index 2) to the front.
        CaseController(state: state).reorder(section: section, from: IndexSet(integer: 2), to: 0)

        let reloaded = try CaseLoader().load(folderURL: folder)
        let byId = Dictionary(uniqueKeysWithValues: reloaded.exhibits.map { ($0.id, $0.order) })
        XCTAssertEqual(byId["C"], 0)
        XCTAssertEqual(byId["A"], 1)
        XCTAssertEqual(byId["B"], 2)
        // Grouped+sorted view now leads with C.
        let grouped = ExhibitGrouping.sections(for: reloaded.exhibits, mode: .party)
        XCTAssertEqual(grouped.first?.exhibits.map(\.id), ["C", "A", "B"])
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
