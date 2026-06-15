import XCTest
@testable import IronGavel

final class AnnotationLoaderTests: XCTestCase {
    private func fixtureFolderURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let json = try XCTUnwrap(bundle.url(forResource: "D-001", withExtension: "json"))
        return json.deletingLastPathComponent()
    }

    func test_loads_existing_annotation_document() throws {
        let loader = AnnotationLoader()
        let folder = try fixtureFolderURL()
        let doc = try loader.load(annotationsFolder: folder, exhibitId: "D-001")
        XCTAssertEqual(doc.contractVersion, "1.0")
        XCTAssertEqual(doc.exhibitId, "D-001")
    }

    func test_missing_file_returns_empty_document_for_exhibit_id() throws {
        let loader = AnnotationLoader()
        let bogus = URL(fileURLWithPath: "/tmp/iron-gavel-no-annotations-\(UUID().uuidString)")
        let doc = try loader.load(annotationsFolder: bogus, exhibitId: "X-999")
        XCTAssertEqual(doc.exhibitId, "X-999")
        XCTAssertEqual(doc.pages.count, 0)
    }
}
