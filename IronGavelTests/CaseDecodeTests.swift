import XCTest
@testable import IronGavel

final class CaseDecodeTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(bundle.url(forResource: "exhibits", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func test_decodes_fixture_sidecar() throws {
        let data = try fixtureData()
        let kase = try JSONDecoder().decode(Case.self, from: data)
        XCTAssertEqual(kase.contractVersion, "1.0")
        XCTAssertEqual(kase.case.caption, "State v. Doe")
        XCTAssertEqual(kase.case.docket, "2026-CR-00042")
        XCTAssertEqual(kase.pathBase, "sidecar_dir")
        XCTAssertEqual(kase.exhibits.count, 2)

        let d001 = kase.exhibits[0]
        XCTAssertEqual(d001.id, "D-001")
        XCTAssertEqual(d001.party, .defense)
        XCTAssertEqual(d001.status, .admitted)
        XCTAssertEqual(d001.mediaType, .pdf)
        XCTAssertEqual(d001.file, "Exhibits_Admitted/d001-intersection.pdf")
    }
}
