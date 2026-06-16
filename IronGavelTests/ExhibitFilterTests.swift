import XCTest
@testable import IronGavel

final class ExhibitFilterTests: XCTestCase {
    private func ex(id: String, description: String = "", witness: String? = nil, bates: String? = nil) -> Exhibit {
        Exhibit(id: id, party: .defense, description: description, file: "f.pdf",
                witness: witness, bates: bates, status: .admitted, mediaType: .pdf,
                objection: nil, ruling: nil, notes: nil)
    }

    func test_empty_query_matches_everything() {
        XCTAssertTrue(ExhibitFilter.matches(ex(id: "D-001"), query: ""))
        XCTAssertTrue(ExhibitFilter.matches(ex(id: "D-001"), query: "   "))
    }

    func test_matches_id_case_insensitively() {
        XCTAssertTrue(ExhibitFilter.matches(ex(id: "D-014"), query: "d-014"))
        XCTAssertTrue(ExhibitFilter.matches(ex(id: "D-014"), query: "014"))
        XCTAssertFalse(ExhibitFilter.matches(ex(id: "D-014"), query: "S-014"))
    }

    func test_matches_witness_description_and_bates() {
        let e = ex(id: "D-002", description: "Intersection photo", witness: "Off. Smith", bates: "DEF0002")
        XCTAssertTrue(ExhibitFilter.matches(e, query: "smith"))
        XCTAssertTrue(ExhibitFilter.matches(e, query: "intersection"))
        XCTAssertTrue(ExhibitFilter.matches(e, query: "def0002"))
        XCTAssertFalse(ExhibitFilter.matches(e, query: "jones"))
    }
}
