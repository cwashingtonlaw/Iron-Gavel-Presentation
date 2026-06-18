import XCTest
@testable import IronGavel

@MainActor
final class BinderNavigationTests: XCTestCase {
    private func exhibit(_ id: String, status: ExhibitStatus = .admitted) -> Exhibit {
        Exhibit(id: id, party: .defense, description: id, file: "f.pdf",
                witness: nil, bates: nil, status: status, mediaType: .pdf,
                objection: nil, ruling: nil, notes: nil)
    }
    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(contractVersion: "1.0", case: .init(caption: "X", docket: "Y", court: "Z"),
             generated: "t", pathBase: "p", exhibits: exhibits)
    }

    /// A unique temp folder per test so the binder's on-disk persistence cannot leak
    /// between tests (each AppState.apply loads binder.json from this folder).
    private func uniqueFolder() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("igbn-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: u) }
        return u
    }

    private func seeded() -> AppState {
        let s = AppState()
        s.apply(case: makeCase([exhibit("D-001"), exhibit("D-002")]), folder: uniqueFolder())
        s.addBinderStep(exhibitId: "D-001", page: 0)
        s.addBinderStep(exhibitId: "D-002", page: 3)
        return s
    }

    func test_add_appends_steps() {
        let s = seeded()
        XCTAssertEqual(s.binderSteps.map(\.exhibitId), ["D-001", "D-002"])
        XCTAssertEqual(s.binderSteps.map(\.page), [0, 3])
    }

    func test_goToBinderStep_publishes_exhibit_at_page() {
        let s = seeded()
        s.goToBinderStep(1)
        XCTAssertEqual(s.binderIndex, 1)
        guard case let .exhibit(ex, page, _) = s.juryDisplay else { return XCTFail("not exhibit") }
        XCTAssertEqual(ex.id, "D-002")
        XCTAssertEqual(page, 3)
        XCTAssertEqual(s.selectedExhibit?.id, "D-002")
    }

    func test_advance_and_back_walk_the_binder() {
        let s = seeded()
        s.goToBinderStep(0)
        XCTAssertTrue(s.canAdvanceBinder)
        XCTAssertFalse(s.canBackBinder)
        s.advanceBinder()
        XCTAssertEqual(s.binderIndex, 1)
        XCTAssertFalse(s.canAdvanceBinder)
        XCTAssertTrue(s.canBackBinder)
        s.backBinder()
        XCTAssertEqual(s.binderIndex, 0)
    }

    func test_out_of_range_step_is_ignored() {
        let s = seeded()
        s.goToBinderStep(0)
        s.goToBinderStep(99)   // no-op
        XCTAssertEqual(s.binderIndex, 0)
        s.backBinder()         // already at first → stays
        XCTAssertEqual(s.binderIndex, 0)
    }

    func test_unadmitted_step_does_not_publish() {
        let s = AppState()
        s.apply(case: makeCase([exhibit("D-001", status: .offered)]), folder: uniqueFolder())
        s.addBinderStep(exhibitId: "D-001", page: 0)
        s.goToBinderStep(0)
        if case .exhibit = s.juryDisplay { XCTFail("should not publish an unadmitted exhibit") }
    }

    func test_remove_clamps_index() {
        let s = seeded()
        s.goToBinderStep(1)
        s.removeBinderStep(at: IndexSet(integer: 1))
        XCTAssertEqual(s.binderSteps.count, 1)
        XCTAssertLessThan(s.binderIndex, s.binderSteps.count)
    }
}
