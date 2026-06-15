import SwiftUI

struct PageAnnotationLayer: View {
    let exhibitId: String
    let exhibitFileURL: URL?
    let page: Int
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(state.annotationStore.annotations(exhibitId: exhibitId, page: page), id: \.id) { ann in
                    rendered(annotation: ann, in: geo.size)
                }
                gestureSurface(viewSize: geo.size)
            }
        }
        .accessibilityIdentifier("annotation.layer.\(exhibitId).p\(page)")
    }

    @ViewBuilder
    private func rendered(annotation: Annotation, in size: CGSize) -> some View {
        switch annotation.tool {
        case .highlight:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(annotation.color.uiColor.opacity(0.4))
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width, y: (b.y + b.h/2) * size.height)
                    .accessibilityIdentifier("annotation.highlight.\(annotation.id)")
            }
        case .redact:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width, y: (b.y + b.h/2) * size.height)
                    .accessibilityIdentifier("annotation.redact.\(annotation.id)")
            }
        case .callout:
            CalloutBubble(annotation: annotation, exhibitFileURL: exhibitFileURL, pageIndex: page)
        case .freehand:
            EmptyView()
        }
    }

    @ViewBuilder
    private func gestureSurface(viewSize: CGSize) -> some View {
        switch state.currentTool {
        case .highlight:
            Color.clear
                .contentShape(Rectangle())
                .modifier(HighlightGestureModifier(viewSize: viewSize) { rect in
                    let ann = Annotation(tool: .highlight, color: state.currentColor, bounds: rect)
                    state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
                })
        case .redact:
            Color.clear
                .contentShape(Rectangle())
                .modifier(RedactGestureModifier(viewSize: viewSize) { rect in
                    let ann = Annotation(tool: .redact, color: state.currentColor, bounds: rect)
                    state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
                })
        case .callout:
            Color.clear
                .contentShape(Rectangle())
                .modifier(CalloutGestureModifier(viewSize: viewSize) { source, bounds in
                    let ann = Annotation(tool: .callout, color: state.currentColor,
                                         bounds: bounds, calloutSource: source)
                    state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
                })
        case .freehand, .none:
            EmptyView()
        }
    }
}
