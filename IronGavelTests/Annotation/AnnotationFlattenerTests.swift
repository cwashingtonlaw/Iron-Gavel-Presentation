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

    /// The injected highlightOpacity must actually change the baked output: a more opaque
    /// yellow highlight over a white base drives the blue channel lower. Guards feature #1.
    func test_highlightOpacity_setting_changes_rendered_pixels() throws {
        let annotations: [Annotation] = [
            Annotation(tool: .highlight, color: .yellow,
                       bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.6, h: 0.2))
        ]
        let faint = try minBlueChannel(flattening: annotations, opacity: 0.2)
        let strong = try minBlueChannel(flattening: annotations, opacity: 0.9)
        XCTAssertLessThan(strong, faint - 30,
                          "Higher opacity should bake a more saturated yellow (lower blue)")
    }

    /// Flattens with the given opacity, rasterizes the page, and returns the minimum blue
    /// channel value found across all pixels (the most-saturated yellow).
    private func minBlueChannel(flattening annotations: [Annotation], opacity: Double) throws -> Int {
        let sourcePDF = try makeSourcePDF()
        defer { try? FileManager.default.removeItem(at: sourcePDF) }
        let output = tempOutputURL()
        defer { try? FileManager.default.removeItem(at: output) }

        try AnnotationFlattener(highlightOpacity: opacity).flatten(
            exhibitFileURL: sourcePDF, pageIndex: 0,
            annotations: annotations, outputURL: output)

        let doc = try XCTUnwrap(PDFDocument(url: output))
        let page = try XCTUnwrap(doc.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        let img = UIGraphicsImageRenderer(size: bounds.size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(bounds)
            ctx.cgContext.translateBy(x: 0, y: bounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        let cg = try XCTUnwrap(img.cgImage)
        let width = cg.width, height = cg.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = try XCTUnwrap(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minBlue = 255
        var i = 0
        while i < pixels.count {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            // Only consider yellow-ish pixels (high red+green, lower blue) to ignore base text.
            if r > 180 && g > 150 && b < minBlue { minBlue = b }
            i += 4
        }
        return minBlue
    }
}
