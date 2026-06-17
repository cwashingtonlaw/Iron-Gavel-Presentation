import Foundation
import UIKit

struct WhiteboardExporter {
    /// 4:3 flip-chart canvas; white base so ink/highlight read on paper.
    private let canvas = CGSize(width: 1600, height: 1200)

    func export(annotations: [Annotation], to outputURL: URL) throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let base = UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))
        }
        guard let cg = base.cgImage else { return }
        try AnnotationFlattener().flatten(image: cg, annotations: annotations, outputURL: outputURL)
    }
}
