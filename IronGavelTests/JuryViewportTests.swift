import XCTest
@testable import IronGavel

final class JuryViewportTests: XCTestCase {
    func test_full_viewport_is_identity() {
        let v = JuryViewport.full
        XCTAssertTrue(v.isFull)
        XCTAssertEqual(v.scale, 1, accuracy: 0.0001)
        let off = v.offset(in: CGSize(width: 800, height: 600))
        XCTAssertEqual(off.width, 0, accuracy: 0.0001)
        XCTAssertEqual(off.height, 0, accuracy: 0.0001)
    }

    func test_half_width_region_doubles_scale() {
        let v = JuryViewport(region: NormalizedRect(x: 0.25, y: 0.25, w: 0.5, h: 0.5))
        XCTAssertFalse(v.isFull)
        XCTAssertEqual(v.scale, 2, accuracy: 0.0001)
    }

    func test_region_offset_brings_origin_to_top_left() {
        // Region starting at (0.25, 0.5) with width 0.5 → scale 2.
        let v = JuryViewport(region: NormalizedRect(x: 0.25, y: 0.5, w: 0.5, h: 0.5))
        let size = CGSize(width: 800, height: 600)
        let off = v.offset(in: size)
        // offsetX = -0.25 * 800 * 2 = -400 ; offsetY = -0.5 * 600 * 2 = -600
        XCTAssertEqual(off.width, -400, accuracy: 0.001)
        XCTAssertEqual(off.height, -600, accuracy: 0.001)
    }
}

@MainActor
final class AppStateViewportTests: XCTestCase {
    private func exhibit(_ id: String, status: ExhibitStatus) -> Exhibit {
        Exhibit(id: id, party: .defense, description: id, file: "f.pdf",
                witness: nil, bates: nil, status: status, mediaType: .pdf,
                objection: nil, ruling: nil, notes: nil)
    }
    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(contractVersion: "1.0", case: .init(caption: "X", docket: "Y", court: "Z"),
             generated: "2026-06-16T00:00:00-05:00", pathBase: "sidecar_dir", exhibits: exhibits)
    }

    func test_set_and_reset_viewport() {
        let state = AppState()
        XCTAssertTrue(state.juryViewport.isFull)
        state.setJuryViewport(NormalizedRect(x: 0.1, y: 0.1, w: 0.4, h: 0.4))
        XCTAssertFalse(state.juryViewport.isFull)
        state.resetJuryViewport()
        XCTAssertTrue(state.juryViewport.isFull)
    }

    func test_publish_and_page_change_reset_zoom() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()
        state.setJuryViewport(NormalizedRect(x: 0.2, y: 0.2, w: 0.3, h: 0.3))
        XCTAssertFalse(state.juryViewport.isFull)
        state.setPage(1)
        XCTAssertTrue(state.juryViewport.isFull, "changing page resets zoom")
    }
}
