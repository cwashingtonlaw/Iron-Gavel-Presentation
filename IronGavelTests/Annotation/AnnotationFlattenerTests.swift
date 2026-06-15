import XCTest
import PDFKit
import UIKit
@testable import IronGavel

final class AnnotationFlattenerTests: XCTestCase {
    /// Generates a valid single-page PDF at runtime (avoids hand-crafted xref offset bugs).
    private func makeSourcePDF() throws -> URL {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let text = "Iron Gavel" as NSString
            text.draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flatten-source-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
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
        let sourcePDF = try makeSourcePDF()
        defer { try? FileManager.default.removeItem(at: sourcePDF) }
        let output = tempOutputURL()
        defer { try? FileManager.default.removeItem(at: output) }

        let flattener = AnnotationFlattener()
        try flattener.flatten(
            exhibitFileURL: sourcePDF,
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
