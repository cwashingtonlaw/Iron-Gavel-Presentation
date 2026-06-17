import XCTest
@testable import IronGavel

private func ex(_ id: String, order: Int? = nil) -> Exhibit {
    Exhibit(id: id, party: .defense, description: id, file: "f.pdf",
            witness: nil, bates: nil, status: .admitted, mediaType: .pdf,
            objection: nil, ruling: nil, notes: nil, order: order)
}

final class ExhibitReorderTests: XCTestCase {
    func test_sorted_puts_ordered_first_then_unordered_by_import_order() {
        let input = [ex("A"), ex("B", order: 1), ex("C"), ex("D", order: 0)]
        let out = ExhibitReorder.sorted(input)
        // D(0), B(1) come first; A, C keep their import order after.
        XCTAssertEqual(out.map(\.id), ["D", "B", "A", "C"])
    }

    func test_sorted_is_stable_for_equal_orders() {
        let input = [ex("A", order: 5), ex("B", order: 5), ex("C", order: 5)]
        XCTAssertEqual(ExhibitReorder.sorted(input).map(\.id), ["A", "B", "C"])
    }

    func test_move_reassigns_dense_order() {
        let section = [ex("A", order: 0), ex("B", order: 1), ex("C", order: 2)]
        // Move "C" (index 2) to the front (offset 0).
        let out = ExhibitReorder.move(section, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(out.map(\.id), ["C", "A", "B"])
        XCTAssertEqual(out.map(\.order), [0, 1, 2])
    }

    func test_move_assigns_order_to_previously_unordered() {
        let section = [ex("A"), ex("B"), ex("C")]
        let out = ExhibitReorder.move(section, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(out.map(\.id), ["B", "C", "A"])
        XCTAssertEqual(out.map(\.order), [0, 1, 2])
    }
}
