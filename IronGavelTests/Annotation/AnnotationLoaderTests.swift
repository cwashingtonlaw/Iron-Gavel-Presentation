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

extension AnnotationLoaderTests {
    private func resourceFolder(named name: String) throws -> URL {
        let bundle = Bundle(for: type(of: self))
        return try XCTUnwrap(bundle.url(forResource: name, withExtension: nil))
    }

    func test_unsupported_contract_version_throws() throws {
        let loader = AnnotationLoader()
        let folder = try resourceFolder(named: "AnnotationsBadVersion")
        XCTAssertThrowsError(try loader.load(annotationsFolder: folder, exhibitId: "D-001")) { err in
            guard case let AnnotationLoadError.unsupportedContractVersion(found, supported) = err else {
                return XCTFail("expected .unsupportedContractVersion, got \(err)")
            }
            XCTAssertEqual(found, "2.0")
            XCTAssertEqual(supported, "1.0")
        }
    }

    func test_bad_json_throws_decode_failed() throws {
        let loader = AnnotationLoader()
        let folder = try resourceFolder(named: "AnnotationsBadJSON")
        XCTAssertThrowsError(try loader.load(annotationsFolder: folder, exhibitId: "D-001")) { err in
            guard case AnnotationLoadError.decodeFailed = err else {
                return XCTFail("expected .decodeFailed, got \(err)")
            }
        }
    }
}
