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
                    .fill(annotation.color.uiColor.opacity(state.settings.highlightOpacity))
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width, y: (b.y + b.h/2) * size.height)
                    .accessibilityElement()
                    .accessibilityIdentifier("annotation.highlight.\(annotation.id)")
            }
        case .redact:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width, y: (b.y + b.h/2) * size.height)
                    .accessibilityElement()
                    .accessibilityIdentifier("annotation.redact.\(annotation.id)")
            }
        case .callout:
            ZStack(alignment: .topLeading) {
                CalloutBubble(annotation: annotation, exhibitFileURL: exhibitFileURL, pageIndex: page)
                if state.currentTool == nil, let b = annotation.bounds {
                    Button {
                        state.annotationStore.remove(id: annotation.id, exhibitId: exhibitId, page: page)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                    }
                    .accessibilityLabel("Delete callout")
                    .accessibilityIdentifier("annotation.callout.delete.\(annotation.id)")
                    .position(x: (b.x + b.w) * size.width, y: b.y * size.height)
                }
            }
            .frame(width: size.width, height: size.height)
        case .freehand:
            FreehandReadOnly(annotation: annotation, color: annotation.color.uiColor,
                             lineWidth: CGFloat(state.settings.freehandPenWidth))
                .allowsHitTesting(false)
                .accessibilityIdentifier("annotation.freehand.\(annotation.id)")
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
        case .freehand:
            FreehandActive(exhibitId: exhibitId, page: page, viewSize: viewSize)
        case .none:
            EmptyView()
        }
    }
}

private struct FreehandReadOnly: View {
    let annotation: Annotation
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        let data = decodedData()
        FreehandCanvas(
            drawingData: .constant(data),
            inkColor: UIColor(color),
            isPresenter: false,
            lineWidth: lineWidth
        )
    }

    private func decodedData() -> Data {
        guard let b64 = annotation.inkDataBase64,
              let d = Data(base64Encoded: b64) else { return Data() }
        return d
    }
}

private struct FreehandActive: View {
    let exhibitId: String
    let page: Int
    let viewSize: CGSize
    @Environment(AppState.self) private var state
    @State private var data: Data = Data()

    var body: some View {
        FreehandCanvas(
            drawingData: $data,
            inkColor: UIColor(state.currentColor.uiColor),
            isPresenter: true,
            lineWidth: CGFloat(state.settings.freehandPenWidth)
        )
        .onChange(of: data) { _, newValue in
            let b64 = newValue.base64EncodedString()
            let ann = Annotation(tool: .freehand,
                                 color: state.currentColor,
                                 inkDataBase64: b64)
            state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
        }
        .onAppear {
            let existing = state.annotationStore.annotations(exhibitId: exhibitId, page: page)
                .first(where: { $0.tool == .freehand })
            if let b64 = existing?.inkDataBase64, let d = Data(base64Encoded: b64) {
                data = d
            }
        }
    }
}
