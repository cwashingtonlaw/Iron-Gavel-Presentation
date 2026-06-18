import XCTest
import UIKit
@testable import IronGavel

final class ImageLoaderTests: XCTestCase {
    /// Writes a deliberately large opaque JPEG so we can prove downsampling shrinks it.
    private func makeLargeImage(_ size: CGSize) throws -> URL {
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let data = try XCTUnwrap(img.jpegData(compressionQuality: 0.8))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("imgload-\(UUID().uuidString).jpg")
        try data.write(to: url)
        return url
    }

    func test_downsample_caps_largest_dimension() throws {
        let url = try makeLargeImage(CGSize(width: 4000, height: 3000))
        defer { try? FileManager.default.removeItem(at: url) }

        let img = try XCTUnwrap(ImageDownsampler.downsample(url: url, maxPixel: 1024))
        let longest = max(img.size.width * img.scale, img.size.height * img.scale)
        XCTAssertLessThanOrEqual(longest, 1025)   // ImageIO may round up by a pixel
        XCTAssertGreaterThan(longest, 0)
    }

    func test_downsample_returns_nil_for_nonimage() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notimg-\(UUID().uuidString).jpg")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(ImageDownsampler.downsample(url: url, maxPixel: 512))
    }

    func test_loader_caches_same_instance_per_key() throws {
        let url = try makeLargeImage(CGSize(width: 2000, height: 1500))
        defer { try? FileManager.default.removeItem(at: url) }

        let loader = ImageLoader()
        let a = try XCTUnwrap(loader.image(at: url, maxPixel: 800))
        let b = try XCTUnwrap(loader.image(at: url, maxPixel: 800))
        XCTAssertTrue(a === b, "Second load should be served from cache, not re-decoded")

        loader.evict(url)
        let c = try XCTUnwrap(loader.image(at: url, maxPixel: 800))
        XCTAssertFalse(a === c, "After eviction the image is decoded fresh")
    }
}
