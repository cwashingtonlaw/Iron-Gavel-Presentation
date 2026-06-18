import XCTest
import PDFKit
import UIKit
@testable import IronGavel

final class ThumbnailProviderTests: XCTestCase {
    private func makePDF() throws -> URL {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
            ctx.beginPage()
            ("Exhibit" as NSString).draw(at: CGPoint(x: 72, y: 72),
                                         withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    func test_pdf_thumbnail_is_generated_and_bounded() throws {
        let url = try makePDF(); defer { try? FileManager.default.removeItem(at: url) }
        let img = try XCTUnwrap(ThumbnailProvider().thumbnail(for: url, mediaType: .pdf, maxPixel: 96))
        let longest = max(img.size.width, img.size.height)
        XCTAssertGreaterThan(longest, 0)
        XCTAssertLessThanOrEqual(longest, 97)
    }

    func test_missing_file_returns_nil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nope.pdf")
        XCTAssertNil(ThumbnailProvider().thumbnail(for: url, mediaType: .pdf))
    }

    func test_audio_returns_nil() throws {
        let url = try makePDF(); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(ThumbnailProvider().thumbnail(for: url, mediaType: .audio))
    }

    func test_caches_same_instance() throws {
        let url = try makePDF(); defer { try? FileManager.default.removeItem(at: url) }
        let p = ThumbnailProvider()
        let a = try XCTUnwrap(p.thumbnail(for: url, mediaType: .pdf, maxPixel: 96))
        let b = try XCTUnwrap(p.thumbnail(for: url, mediaType: .pdf, maxPixel: 96))
        XCTAssertTrue(a === b)
    }
}
