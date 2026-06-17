import SwiftUI
import PDFKit

struct CalloutBubble: View {
    let annotation: Annotation
    let exhibitFileURL: URL?
    let pageIndex: Int

    var body: some View {
        GeometryReader { geo in
            if let bounds = annotation.bounds {
                let frame = bounds.toCGRect(in: geo.size)
                ZStack {
                    sourceImage(in: frame.size)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(annotation.color.uiColor, lineWidth: 3)
                        )
                }
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityIdentifier("annotation.callout.\(annotation.id)")
            }
        }
    }

    @ViewBuilder
    private func sourceImage(in size: CGSize) -> some View {
        if let image = rasterizedSource(targetSize: size) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Color.gray.opacity(0.2)
        }
    }

    private func rasterizedSource(targetSize: CGSize) -> UIImage? {
        guard let url = exhibitFileURL,
              let source = annotation.calloutSource,
              let doc = PDFDocument(url: url),
              let page = doc.page(at: pageIndex)
        else { return nil }

        let pageBounds = page.bounds(for: .mediaBox)
        let srcRect = CGRect(
            x: source.x * pageBounds.width,
            y: source.y * pageBounds.height,
            width: source.w * pageBounds.width,
            height: source.h * pageBounds.height
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: targetSize.width / srcRect.width,
                                  y: -targetSize.height / srcRect.height)
            ctx.cgContext.translateBy(x: -srcRect.minX, y: -srcRect.minY)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}
