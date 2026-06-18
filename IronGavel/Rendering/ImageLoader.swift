import UIKit
import ImageIO

/// Downsamples images at decode time using ImageIO, so a large photo exhibit never has to
/// be fully decoded into memory just to fit on screen.
enum ImageDownsampler {
    /// Returns an image whose largest pixel dimension is approximately `maxPixel`.
    /// nil if the file can't be read as an image.
    static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // respect EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}

/// Loads and caches display-ready images. Without this, SwiftUI re-decodes the full
/// resolution file on every body evaluation — ruinous for large photo exhibits mirrored
/// to the jury. Cache key includes the pixel cap so presenter and jury can ask for
/// different sizes.
final class ImageLoader {
    static let shared = ImageLoader()

    /// Pixel cap for full-screen exhibit display. Crisp on a 12.9" iPad / 4K courtroom
    /// panel without paying for a 40-megapixel decode.
    static let displayMaxPixel: CGFloat = 2560

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var keysByPath: [String: Set<NSString>] = [:]

    func image(at url: URL, maxPixel: CGFloat = ImageLoader.displayMaxPixel) -> UIImage? {
        let key = "\(url.path)|\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let image = ImageDownsampler.downsample(url: url, maxPixel: maxPixel)
                ?? UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        lock.lock(); keysByPath[url.path, default: []].insert(key); lock.unlock()
        return image
    }

    /// Drops every cached size for a file (e.g. if it is re-imported).
    func evict(_ url: URL) {
        lock.lock()
        let keys = keysByPath.removeValue(forKey: url.path) ?? []
        lock.unlock()
        for key in keys { cache.removeObject(forKey: key) }
    }
}
