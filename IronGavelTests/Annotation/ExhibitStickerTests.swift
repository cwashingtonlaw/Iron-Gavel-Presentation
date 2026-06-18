import XCTest
@testable import IronGavel

final class ExhibitStickerTests: XCTestCase {
    private func ex(id: String, number: String?, bates: String?) -> Exhibit {
        Exhibit(id: id, party: .defense, description: "d", file: "f.pdf",
                witness: nil, bates: bates, status: .admitted, mediaType: .pdf,
                objection: nil, ruling: nil, notes: nil, exhibitNumber: number)
    }

    func test_label_uses_display_number() {
        XCTAssertEqual(ExhibitSticker.label(for: ex(id: "x", number: "D-1", bates: nil)), "EXHIBIT D-1")
    }

    func test_label_falls_back_to_numberlike_id() {
        XCTAssertEqual(ExhibitSticker.label(for: ex(id: "D-001", number: nil, bates: nil)), "EXHIBIT D-001")
    }

    func test_label_nil_for_unmarked_exhibit() {
        XCTAssertNil(ExhibitSticker.label(for: ex(id: "scratch", number: nil, bates: nil)))
    }

    func test_bates_passthrough_trims_empty() {
        XCTAssertEqual(ExhibitSticker.bates(for: ex(id: "x", number: nil, bates: "BEER-0001")), "BEER-0001")
        XCTAssertNil(ExhibitSticker.bates(for: ex(id: "x", number: nil, bates: "  ")))
        XCTAssertNil(ExhibitSticker.bates(for: ex(id: "x", number: nil, bates: nil)))
    }
}
