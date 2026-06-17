import XCTest
import CoreGraphics
@testable import IronGavel

@MainActor
final class LaserCompareTests: XCTestCase {
    private func exhibit(_ id: String, status: ExhibitStatus) -> Exhibit {
        Exhibit(id: id, party: .defense, description: id, file: "f.pdf",
                witness: nil, bates: nil, status: status, mediaType: .pdf,
                objection: nil, ruling: nil, notes: nil)
    }
    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(contractVersion: "1.0", case: .init(caption: "X", docket: "Y", court: "Z"),
             generated: "2026-06-16T00:00:00-05:00", pathBase: "p", exhibits: exhibits)
    }

    func test_laser_set_and_clear() {
        let s = AppState()
        XCTAssertNil(s.laserPoint)
        s.setLaser(CGPoint(x: 0.5, y: 0.25))
        XCTAssertEqual(s.laserPoint, CGPoint(x: 0.5, y: 0.25))
        s.clearLaser()
        XCTAssertNil(s.laserPoint)
    }

    func test_compare_primary_is_the_published_exhibit() {
        let admitted = exhibit("D-001", status: .admitted)
        let s = AppState()
        s.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        XCTAssertNil(s.comparePrimary)            // nothing published yet
        s.select(admitted)
        s.publishSelected()
        XCTAssertEqual(s.comparePrimary?.exhibit.id, "D-001")
    }

    func test_start_and_stop_compare() {
        let admitted = exhibit("D-001", status: .admitted)
        let other = exhibit("D-002", status: .admitted)
        let s = AppState()
        s.apply(case: makeCase([admitted, other]), folder: URL(fileURLWithPath: "/tmp"))
        s.select(admitted)
        s.publishSelected()

        XCTAssertFalse(s.isComparing)
        s.startCompare(with: other)
        XCTAssertTrue(s.isComparing)
        XCTAssertEqual(s.compareExhibit?.id, "D-002")
        s.stopCompare()
        XCTAssertFalse(s.isComparing)
        XCTAssertNil(s.compareExhibit)
    }
}
