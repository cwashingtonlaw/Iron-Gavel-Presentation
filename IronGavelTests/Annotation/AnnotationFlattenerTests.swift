import XCTest
import PDFKit
@testable import IronGavel

final class AnnotationFlattenerTests: XCTestCase {
    private func sourcePDFURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let folder = try XCTUnwrap(bundle.url(forResource: "FlattenSource", withExtension: nil))
        return folder.appendingPathComponent("sample.pdf")
    }

    private func tempOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("flatten-\(UUID().uuidString).pdf")
    }

    func test_flatten_produces_single_page_pdf_with_input_dimensions() throws {
        let annotations: [Annotation] = [
            Annotation(tool: .highlight, color: .yellow,
                       bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.5, h: 0.05))
        ]
        let output = tempOutputURL()
        defer { try? FileManager.default.removeItem(at: output) }

        let flattener = AnnotationFlattener()
        try flattener.flatten(
            exhibitFileURL: try sourcePDFURL(),
            pageIndex: 0,
            annotations: annotations,
            outputURL: output
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let doc = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(doc.pageCount, 1)
        let page = try XCTUnwrap(doc.page(at: 0))
        XCTAssertEqual(page.bounds(for: .mediaBox).width, 612, accuracy: 0.5)
        XCTAssertEqual(page.bounds(for: .mediaBox).height, 792, accuracy: 0.5)
    }
}
