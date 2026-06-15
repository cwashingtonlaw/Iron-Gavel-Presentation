import XCTest
@testable import IronGavel

final class AnnotationDocumentCodableTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        return try XCTUnwrap(bundle.url(forResource: "D-001", withExtension: "json"))
    }

    func test_decodes_valid_fixture() throws {
        let data = try Data(contentsOf: fixtureURL())
        let doc = try JSONDecoder().decode(AnnotationDocument.self, from: data)

        XCTAssertEqual(doc.contractVersion, "1.0")
        XCTAssertEqual(doc.exhibitId, "D-001")
        XCTAssertEqual(doc.pages["0"]?.count, 3)

        let highlight = doc.pages["0"]?[0]
        XCTAssertEqual(highlight?.tool, .highlight)
        XCTAssertEqual(highlight?.color, .yellow)
        XCTAssertEqual(Double(highlight?.bounds?.x ?? -1), 0.1, accuracy: 0.0001)

        let callout = doc.pages["0"]?[1]
        XCTAssertEqual(callout?.tool, .callout)
        XCTAssertNotNil(callout?.calloutSource)

        let freehand = doc.pages["0"]?[2]
        XCTAssertEqual(freehand?.tool, .freehand)
        XCTAssertEqual(freehand?.inkDataBase64, "")
    }

    func test_round_trip_encode_decode_preserves_all_fields() throws {
        let original = try JSONDecoder().decode(AnnotationDocument.self, from: Data(contentsOf: fixtureURL()))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnnotationDocument.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func test_empty_pages_decode_as_empty_dictionary() throws {
        let json = #"{"contract_version":"1.0","exhibit_id":"D-001","last_modified":"2026-06-15T03:00:00Z","pages":{}}"#
        let doc = try JSONDecoder().decode(AnnotationDocument.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(doc.pages.count, 0)
    }
}
