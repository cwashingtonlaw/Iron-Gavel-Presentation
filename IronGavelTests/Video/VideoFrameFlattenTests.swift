import XCTest
import AVFoundation
import PDFKit
import CoreGraphics
@testable import IronGavel

final class VideoFrameFlattenTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("igvff-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func solidImage(w: Int, h: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    func test_flatten_image_writes_pdf_matching_image_size() throws {
        let img = solidImage(w: 320, h: 240)
        let out = tmp.appendingPathComponent("D-009-t3.pdf")
        let anns = [Annotation(tool: .highlight, color: .yellow,
                               bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.3, h: 0.2))]
        try AnnotationFlattener().flatten(image: img, annotations: anns, outputURL: out)

        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        let doc = try XCTUnwrap(PDFDocument(url: out))
        XCTAssertEqual(doc.pageCount, 1)
        let bounds = try XCTUnwrap(doc.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 320, accuracy: 1)
        XCTAssertEqual(bounds.height, 240, accuracy: 1)
    }

    func test_flatten_image_is_atomic_no_tmp_left() throws {
        let img = solidImage(w: 100, h: 100)
        let out = tmp.appendingPathComponent("D-009-t0.pdf")
        try AnnotationFlattener().flatten(image: img, annotations: [], outputURL: out)
        let contents = try FileManager.default.contentsOfDirectory(atPath: tmp.path)
        XCTAssertTrue(contents.contains("D-009-t0.pdf"))
        XCTAssertFalse(contents.contains { $0.hasSuffix(".tmp") })
    }

    func test_grabber_returns_frame_then_flattens_to_pdf() throws {
        let videoURL: URL
        do { videoURL = try TestVideoFactory.makeShortVideo() }
        catch { throw XCTSkip("video fixture unavailable on this runner: \(error)") }
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let frame = try VideoFrameGrabber().image(at: CMTime(seconds: 1, preferredTimescale: 600),
                                                  url: videoURL)
        XCTAssertGreaterThan(frame.width, 0)

        let out = tmp.appendingPathComponent("D-009-t1.pdf")
        try AnnotationFlattener().flatten(image: frame, annotations: [], outputURL: out)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
    }
}
