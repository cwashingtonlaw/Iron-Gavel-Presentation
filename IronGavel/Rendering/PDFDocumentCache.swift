import Foundation
import PDFKit

final class PDFDocumentCache {
    static let shared = PDFDocumentCache()

    private let cache: NSCache<NSURL, PDFDocument> = {
        let c = NSCache<NSURL, PDFDocument>()
        // Bound how many large PDFs stay resident at once; NSCache also evicts under
        // memory pressure. A trial rarely needs more than a handful open simultaneously.
        c.countLimit = 8
        return c
    }()

    func document(for url: URL) -> PDFDocument? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let doc = PDFDocument(url: url) else { return nil }
        cache.setObject(doc, forKey: url as NSURL)
        return doc
    }

    func evict(_ url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}
