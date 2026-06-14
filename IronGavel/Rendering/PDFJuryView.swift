import SwiftUI
import PDFKit

struct PDFJuryView: UIViewRepresentable {
    let fileURL: URL
    let pageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.backgroundColor = .black
        view.document = PDFDocumentCache.shared.document(for: fileURL)
        goToPage(in: view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != fileURL {
            view.document = PDFDocumentCache.shared.document(for: fileURL)
        }
        goToPage(in: view)
    }

    private func goToPage(in view: PDFView) {
        guard let doc = view.document, pageIndex >= 0, pageIndex < doc.pageCount,
              let page = doc.page(at: pageIndex) else { return }
        view.go(to: page)
    }
}
