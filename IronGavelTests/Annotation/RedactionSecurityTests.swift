import XCTest
import PDFKit
import UIKit
@testable import IronGavel

/// Redaction must DESTROY underlying content in the exported PDF, not merely cover it.
/// A black rectangle drawn over preserved text is recoverable (text extraction, copy,
/// or removing the box) — the classic defeatable-redaction failure.
final class RedactionSecurityTests: XCTestCase {
    private let token = "TOPSECRETWITNESSNAME"

    private func makeSourcePDF(containing text: String) throws -> URL {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: pageBounds).pdfData { ctx in
            ctx.beginPage()
            (text as NSString).draw(at: CGPoint(x: 72, y: 72),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("redact-src-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    private func extractedText(of url: URL) -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        return (doc.string ?? "").components(separatedBy: .whitespacesAndNewlines).joined()
    }

    func test_redacted_text_is_not_recoverable_from_export() throws {
        let source = try makeSourcePDF(containing: token)
        defer { try? FileManager.default.removeItem(at: source) }

        // Sanity: the source genuinely has extractable text, else the test proves nothing.
        XCTAssertTrue(extractedText(of: source).contains(token),
                      "fixture must contain extractable text")

        let redaction = Annotation(tool: .redact, color: .red,
                                   bounds: NormalizedRect(x: 0, y: 0, w: 1, h: 1))
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("redact-out-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: out) }

        try AnnotationFlattener().flatten(exhibitFileURL: source, pageIndex: 0,
                                          annotations: [redaction], outputURL: out)

        XCTAssertFalse(extractedText(of: out).contains(token),
                       "REDACTION LEAK: redacted text is recoverable from the exported PDF")
    }

    func test_non_redacted_export_preserves_selectable_text() throws {
        let source = try makeSourcePDF(containing: token)
        defer { try? FileManager.default.removeItem(at: source) }

        // A highlight-only export should keep the text layer (no over-rasterization).
        let highlight = Annotation(tool: .highlight, color: .yellow,
                                   bounds: NormalizedRect(x: 0, y: 0, w: 0.5, h: 0.1))
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("redact-keep-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: out) }

        try AnnotationFlattener().flatten(exhibitFileURL: source, pageIndex: 0,
                                          annotations: [highlight], outputURL: out)

        XCTAssertTrue(extractedText(of: out).contains(token),
                      "non-redacted export should preserve selectable text")
    }
}
