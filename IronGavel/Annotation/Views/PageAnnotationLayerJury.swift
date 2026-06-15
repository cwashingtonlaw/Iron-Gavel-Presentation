import SwiftUI

struct PageAnnotationLayerJury: View {
    let exhibitId: String
    let exhibitFileURL: URL?
    let page: Int
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(state.annotationStore.annotations(exhibitId: exhibitId, page: page), id: \.id) { ann in
                    rendered(ann, in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityIdentifier("jury.annotation.layer.\(exhibitId).p\(page)")
    }

    @ViewBuilder
    private func rendered(_ annotation: Annotation, in size: CGSize) -> some View {
        switch annotation.tool {
        case .highlight:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(annotation.color.uiColor.opacity(0.4))
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width, y: (b.y + b.h/2) * size.height)
            }
        case .redact:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width, y: (b.y + b.h/2) * size.height)
            }
        case .callout:
            CalloutBubble(annotation: annotation, exhibitFileURL: exhibitFileURL, pageIndex: page)
        case .freehand:
            if let b64 = annotation.inkDataBase64, let data = Data(base64Encoded: b64) {
                FreehandCanvas(
                    drawingData: .constant(data),
                    inkColor: UIColor(annotation.color.uiColor),
                    isPresenter: false
                )
            }
        }
    }
}
