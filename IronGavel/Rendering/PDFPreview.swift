import SwiftUI
import PDFKit

struct PDFPreview: UIViewRepresentable {
    let fileURL: URL
    @Binding var pageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.document = PDFDocumentCache.shared.document(for: fileURL)
        goToPage(in: view, index: pageIndex)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != fileURL {
            view.document = PDFDocumentCache.shared.document(for: fileURL)
        }
        goToPage(in: view, index: pageIndex)
    }

    private func goToPage(in view: PDFView, index: Int) {
        guard let doc = view.document, index >= 0, index < doc.pageCount,
              let page = doc.page(at: index) else { return }
        if view.currentPage != page {
            view.go(to: page)
        }
    }
}
