import XCTest
@testable import IronGavel

final class PageNavigationTests: XCTestCase {
    func test_clamps_within_bounds() {
        XCTAssertEqual(PageNavigation.clampPage(3, count: 10), 3)
        XCTAssertEqual(PageNavigation.clampPage(0, count: 10), 0)
        XCTAssertEqual(PageNavigation.clampPage(9, count: 10), 9)
    }

    func test_clamps_below_zero_to_zero() {
        XCTAssertEqual(PageNavigation.clampPage(-5, count: 10), 0)
    }

    func test_clamps_above_last_to_last() {
        XCTAssertEqual(PageNavigation.clampPage(99, count: 10), 9)
    }

    func test_zero_or_unknown_count_returns_zero() {
        XCTAssertEqual(PageNavigation.clampPage(5, count: 0), 0)
        XCTAssertEqual(PageNavigation.clampPage(5, count: -1), 0)
    }
}
