import XCTest
@testable import IronGavel

final class CaseLoaderTests: XCTestCase {
    private func fixtureFolderURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let jsonURL = try XCTUnwrap(bundle.url(forResource: "exhibits", withExtension: "json"))
        return jsonURL.deletingLastPathComponent()
    }

    func test_loads_fixture_case_successfully() throws {
        let loader = CaseLoader()
        let kase = try loader.load(folderURL: try fixtureFolderURL())
        XCTAssertEqual(kase.contractVersion, "1.0")
        XCTAssertEqual(kase.exhibits.count, 2)
    }

    func test_missing_sidecar_throws() {
        let loader = CaseLoader()
        let bogus = URL(fileURLWithPath: "/tmp/iron-gavel-nonexistent-\(UUID().uuidString)")
        XCTAssertThrowsError(try loader.load(folderURL: bogus)) { err in
            guard case CaseLoadError.missingSidecar = err else {
                return XCTFail("expected .missingSidecar, got \(err)")
            }
        }
    }
}
