import XCTest
@testable import IronGavel

private func ex(_ id: String, desc: String? = nil, status: ExhibitStatus = .admitted,
                number: String? = nil, order: Int? = nil) -> Exhibit {
    Exhibit(id: id, party: .defense, description: desc ?? id, file: "f.pdf",
            witness: nil, bates: nil, status: status, mediaType: .pdf,
            objection: nil, ruling: nil, notes: nil, exhibitNumber: number, order: order)
}

final class ExhibitSorterTests: XCTestCase {
    func test_custom_uses_manual_order_then_import_order() {
        let input = [ex("A"), ex("B", order: 1), ex("C"), ex("D", order: 0)]
        XCTAssertEqual(ExhibitSorter.sorted(input, by: .custom).map(\.id), ["D", "B", "A", "C"])
    }

    func test_name_sorts_case_insensitively_by_description() {
        let input = [ex("1", desc: "banana"), ex("2", desc: "Apple"), ex("3", desc: "cherry")]
        XCTAssertEqual(ExhibitSorter.sorted(input, by: .name).map(\.id), ["2", "1", "3"])
    }

    func test_exhibitNumber_is_numeric_aware_and_unnumbered_last() {
        let input = [ex("a", number: "D-10"), ex("b", number: "D-2"),
                     ex("c", number: nil), ex("d", number: "D-1")]
        // D-1, D-2, D-10 (numeric, not lexical), then the unnumbered one.
        XCTAssertEqual(ExhibitSorter.sorted(input, by: .exhibitNumber).map(\.id),
                       ["d", "b", "a", "c"])
    }

    func test_admitted_groups_admitted_first_stably() {
        let input = [ex("p", status: .offered), ex("q", status: .admitted),
                     ex("r", status: .pending), ex("s", status: .admitted)]
        XCTAssertEqual(ExhibitSorter.sorted(input, by: .admitted).map(\.id),
                       ["q", "s", "p", "r"])
    }
}
