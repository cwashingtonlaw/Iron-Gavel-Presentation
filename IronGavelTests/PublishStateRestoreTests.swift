import XCTest
@testable import IronGavel

@MainActor
final class PublishStateRestoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "tier1-publishstate-\(UUID().uuidString)")!
    }

    private func exhibit(_ id: String, status: ExhibitStatus) -> Exhibit {
        Exhibit(id: id, party: .defense, description: id, file: "f.pdf",
                witness: nil, bates: nil, status: status, mediaType: .pdf,
                objection: nil, ruling: nil, notes: nil)
    }

    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(contractVersion: "1.0",
             case: .init(caption: "X", docket: "Y", court: "Z"),
             generated: "2026-06-16T00:00:00-05:00",
             pathBase: "sidecar_dir",
             exhibits: exhibits)
    }

    func test_store_roundtrips_state() {
        let store = PublishStateStore(defaults: freshDefaults())
        XCTAssertNil(store.load())
        store.save(.init(exhibitId: "D-001", page: 3, blanked: false))
        XCTAssertEqual(store.load(), .init(exhibitId: "D-001", page: 3, blanked: false))
        store.clear()
        XCTAssertNil(store.load())
    }

    func test_publish_then_relaunch_restores_exhibit_and_page() {
        let store = PublishStateStore(defaults: freshDefaults())
        let admitted = exhibit("D-001", status: .admitted)

        let first = AppState(publishStateStore: store)
        first.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        first.select(admitted)
        first.publishSelected()
        first.setPage(2)

        // Simulate relaunch: a fresh AppState backed by the same store.
        let relaunched = AppState(publishStateStore: store)
        relaunched.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        relaunched.restorePublishedState()

        XCTAssertEqual(relaunched.juryDisplay, .exhibit(admitted, page: 2, annotationsVersion: 0))
    }

    func test_blank_then_relaunch_restores_blank() {
        let store = PublishStateStore(defaults: freshDefaults())
        let admitted = exhibit("D-001", status: .admitted)

        let first = AppState(publishStateStore: store)
        first.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        first.select(admitted)
        first.publishSelected()
        first.blank()

        let relaunched = AppState(publishStateStore: store)
        relaunched.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        relaunched.restorePublishedState()

        XCTAssertEqual(relaunched.juryDisplay, .blank)
    }

    func test_restore_skips_when_saved_exhibit_no_longer_admitted() {
        let store = PublishStateStore(defaults: freshDefaults())
        store.save(.init(exhibitId: "D-001", page: 0, blanked: false))

        let pendingNow = exhibit("D-001", status: .pending)
        let state = AppState(publishStateStore: store)
        state.apply(case: makeCase([pendingNow]), folder: URL(fileURLWithPath: "/tmp"))
        state.restorePublishedState()

        XCTAssertEqual(state.juryDisplay, .empty)
    }
}
