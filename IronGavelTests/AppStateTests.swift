import XCTest
@testable import IronGavel

@MainActor
final class AppStateTests: XCTestCase {
    private func exhibit(_ id: String, status: ExhibitStatus, file: String = "f.pdf") -> Exhibit {
        Exhibit(
            id: id, party: .defense, description: id,
            file: file, witness: nil, bates: nil,
            status: status, mediaType: .pdf,
            objection: nil, ruling: nil, notes: nil
        )
    }

    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(
            contractVersion: "1.0",
            case: .init(caption: "X", docket: "Y", court: "Z"),
            generated: "2026-06-14T00:00:00-05:00",
            pathBase: "sidecar_dir",
            exhibits: exhibits
        )
    }

    func test_publish_admitted_exhibit_sets_jury_display() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()
        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 0))
    }

    func test_publish_non_admitted_exhibit_is_no_op() {
        let pending = exhibit("S-014", status: .pending)
        let state = AppState()
        state.apply(case: makeCase([pending]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(pending)
        state.publishSelected()
        XCTAssertEqual(state.juryDisplay, .empty)
    }

    func test_blank_then_restore_returns_to_last_published() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()
        state.setPage(3)
        state.blank()
        XCTAssertEqual(state.juryDisplay, .blank)
        state.restore()
        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 3))
    }

    func test_status_downgrade_on_published_exhibit_auto_blanks() {
        let admitted = exhibit("D-001", status: .admitted)
        let downgraded = exhibit("D-001", status: .objected)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        state.apply(case: makeCase([downgraded]), folder: URL(fileURLWithPath: "/tmp"))

        XCTAssertEqual(state.juryDisplay, .blank)
        XCTAssertNotNil(state.lastStatusBanner)
        XCTAssertTrue(state.lastStatusBanner?.contains("D-001") ?? false)
    }

    func test_status_change_on_non_published_exhibit_does_not_blank() {
        let admitted = exhibit("D-001", status: .admitted)
        let other = exhibit("S-014", status: .pending)
        let otherChanged = exhibit("S-014", status: .objected)
        let state = AppState()
        state.apply(case: makeCase([admitted, other]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        state.apply(case: makeCase([admitted, otherChanged]), folder: URL(fileURLWithPath: "/tmp"))

        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 0))
        XCTAssertNil(state.lastStatusBanner)
    }
}
