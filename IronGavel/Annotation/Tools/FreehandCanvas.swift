import SwiftUI
import PencilKit

struct FreehandCanvas: UIViewRepresentable {
    @Binding var drawingData: Data
    let inkColor: UIColor
    let isPresenter: Bool
    var lineWidth: CGFloat = 4

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: lineWidth)
        canvas.isUserInteractionEnabled = isPresenter
        if let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isPresenter
        uiView.tool = PKInkingTool(.pen, color: inkColor, width: lineWidth)
        if let drawing = try? PKDrawing(data: drawingData), drawing != uiView.drawing {
            uiView.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: FreehandCanvas
        init(_ parent: FreehandCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()
            if data != parent.drawingData {
                parent.drawingData = data
            }
        }
    }
}
