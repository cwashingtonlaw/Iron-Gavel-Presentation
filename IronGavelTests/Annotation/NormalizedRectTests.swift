import XCTest
@testable import IronGavel

final class NormalizedRectTests: XCTestCase {
    func test_roundtrip_through_view_size() {
        let n = NormalizedRect(x: 0.25, y: 0.10, w: 0.50, h: 0.20)
        let view = CGSize(width: 800, height: 1000)
        let cg = n.toCGRect(in: view)
        XCTAssertEqual(cg.origin.x, 200, accuracy: 0.001)
        XCTAssertEqual(cg.origin.y, 100, accuracy: 0.001)
        XCTAssertEqual(cg.size.width, 400, accuracy: 0.001)
        XCTAssertEqual(cg.size.height, 200, accuracy: 0.001)

        let back = NormalizedRect(cgRect: cg, in: view)
        XCTAssertEqual(back.x, n.x, accuracy: 0.0001)
        XCTAssertEqual(back.y, n.y, accuracy: 0.0001)
        XCTAssertEqual(back.w, n.w, accuracy: 0.0001)
        XCTAssertEqual(back.h, n.h, accuracy: 0.0001)
    }

    func test_clamps_negative_values_to_zero() {
        let n = NormalizedRect(x: -0.5, y: -0.1, w: 0.5, h: 0.5)
        XCTAssertEqual(n.clamped().x, 0)
        XCTAssertEqual(n.clamped().y, 0)
    }

    func test_clamps_overflow_to_one() {
        let n = NormalizedRect(x: 0.8, y: 0.9, w: 0.5, h: 0.5)
        let c = n.clamped()
        XCTAssertEqual(c.x + c.w, 1.0, accuracy: 0.0001)
        XCTAssertEqual(c.y + c.h, 1.0, accuracy: 0.0001)
    }
}
