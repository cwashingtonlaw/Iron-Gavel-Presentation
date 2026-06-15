import XCTest
@testable import IronGavel

final class JuryDisplayTests: XCTestCase {
    private func makeExhibit(id: String = "D-001", status: ExhibitStatus = .admitted) -> Exhibit {
        Exhibit(
            id: id, party: .defense, description: "x",
            file: "f.pdf", witness: nil, bates: nil,
            status: status, mediaType: .pdf,
            objection: nil, ruling: nil, notes: nil
        )
    }

    func test_equality_distinguishes_states() {
        let e = makeExhibit()
        XCTAssertEqual(JuryDisplay.empty, .empty)
        XCTAssertEqual(JuryDisplay.blank, .blank)
        XCTAssertEqual(JuryDisplay.exhibit(e, page: 0, annotationsVersion: 0),
                       .exhibit(e, page: 0, annotationsVersion: 0))
        XCTAssertNotEqual(JuryDisplay.exhibit(e, page: 0, annotationsVersion: 0),
                          .exhibit(e, page: 1, annotationsVersion: 0))
        XCTAssertNotEqual(JuryDisplay.exhibit(e, page: 0, annotationsVersion: 0),
                          .exhibit(e, page: 0, annotationsVersion: 1))
    }

    func test_currentExhibit_returns_exhibit_only_when_displayed() {
        let e = makeExhibit()
        XCTAssertNil(JuryDisplay.empty.currentExhibit)
        XCTAssertNil(JuryDisplay.blank.currentExhibit)
        XCTAssertEqual(JuryDisplay.exhibit(e, page: 2, annotationsVersion: 0).currentExhibit?.id, "D-001")
    }
}
