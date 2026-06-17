import Foundation
import PDFKit

struct DocumentSearchHit: Hashable, Identifiable {
    let id = UUID()
    let exhibitId: String
    let exhibitDescription: String
    let page: Int       // 0-based, ready for the preview page binding / state.setPage
    let snippet: String

    static func == (l: DocumentSearchHit, r: DocumentSearchHit) -> Bool {
        l.exhibitId == r.exhibitId && l.page == r.page
    }
    func hash(into h: inout Hasher) { h.combine(exhibitId); h.combine(page) }
}

/// Full-text search across a case's PDF exhibits. `documentProvider` is injected so
/// tests can supply fixtures; production passes `PDFDocumentCache.shared.document`.
struct DocumentSearch {
    func search(query rawQuery: String,
                in exhibits: [Exhibit],
                caseFolder: URL,
                documentProvider: (URL) -> PDFDocument?) -> [DocumentSearchHit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }

        var hits: [DocumentSearchHit] = []
        for exhibit in exhibits where exhibit.mediaType == .pdf {
            let url = caseFolder.appendingPathComponent(exhibit.file)
            guard let doc = documentProvider(url) else { continue }
            let selections = doc.findString(query, withOptions: [.caseInsensitive])
            var seenPages = Set<Int>()
            for selection in selections {
                guard let page = selection.pages.first else { continue }
                let pageIndex = doc.index(for: page)
                guard !seenPages.contains(pageIndex) else { continue }
                seenPages.insert(pageIndex)
                hits.append(DocumentSearchHit(
                    exhibitId: exhibit.id,
                    exhibitDescription: exhibit.description,
                    page: pageIndex,
                    snippet: snippet(for: selection, on: page)
                ))
            }
        }
        return hits
    }

    /// A short context string around the match (the matched line, trimmed).
    private func snippet(for selection: PDFSelection, on page: PDFPage) -> String {
        let matched = selection.string ?? ""
        let pageText = page.string ?? ""
        guard !matched.isEmpty, let range = pageText.range(of: matched, options: .caseInsensitive)
        else { return matched }
        let lower = pageText.index(range.lowerBound, offsetBy: -30, limitedBy: pageText.startIndex)
            ?? pageText.startIndex
        let upper = pageText.index(range.upperBound, offsetBy: 30, limitedBy: pageText.endIndex)
            ?? pageText.endIndex
        return "…" + pageText[lower..<upper].trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
