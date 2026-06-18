import UIKit
import PDFKit

/// Generates and caches small thumbnails for the exhibit sidebar rows (TrialPad shows a
/// page-1 preview per document). PDFs render their first page; images downsample; A/V
/// return nil so the row falls back to a media-type glyph.
final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for url: URL, mediaType: MediaType, maxPixel: CGFloat = 128) -> UIImage? {
        let key = "\(url.path)|\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let image: UIImage?
        switch mediaType {
        case .pdf:                     image = pdfThumbnail(url: url, maxPixel: maxPixel)
        case .image:                   image = ImageDownsampler.downsample(url: url, maxPixel: maxPixel)
        case .video, .audio, .unknown: image = nil
        }
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    private func pdfThumbnail(url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        let box = page.bounds(for: .mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = maxPixel / max(box.width, box.height)
        let size = CGSize(width: box.width * scale, height: box.height * scale)
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
