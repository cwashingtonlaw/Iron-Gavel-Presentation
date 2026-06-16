import Foundation
import PDFKit
import PencilKit
import UIKit

struct AnnotationFlattener {
    enum FlattenError: Error {
        case cannotOpenSource
        case cannotResolvePage
        case writeFailed(message: String)
    }

    func flatten(
        exhibitFileURL: URL,
        pageIndex: Int,
        annotations: [Annotation],
        outputURL: URL
    ) throws {
        guard let source = PDFDocument(url: exhibitFileURL) else { throw FlattenError.cannotOpenSource }
        guard let page = source.page(at: pageIndex) else { throw FlattenError.cannotResolvePage }
        let pageBounds = page.bounds(for: .mediaBox)

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext
            cg.saveGState()
            cg.translateBy(x: 0, y: pageBounds.height)
            cg.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: cg)
            cg.restoreGState()

            for annotation in annotations {
                draw(annotation, in: pageBounds, cg: cg)
            }
        }

        try writeAtomically(data, to: outputURL)
    }

    func flatten(
        image: CGImage,
        annotations: [Annotation],
        outputURL: URL
    ) throws {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext
            cg.saveGState()
            cg.translateBy(x: 0, y: bounds.height)
            cg.scaleBy(x: 1, y: -1)
            cg.draw(image, in: bounds)
            cg.restoreGState()

            for annotation in annotations {
                draw(annotation, in: bounds, cg: cg)
            }
        }
        try writeAtomically(data, to: outputURL)
    }

    private func writeAtomically(_ data: Data, to outputURL: URL) throws {
        let tmp = outputURL.deletingLastPathComponent()
            .appendingPathComponent(outputURL.lastPathComponent + ".tmp")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.removeItem(at: outputURL)
            try FileManager.default.moveItem(at: tmp, to: outputURL)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw FlattenError.writeFailed(message: String(describing: error))
        }
    }

    private func draw(_ annotation: Annotation, in pageBounds: CGRect, cg: CGContext) {
        switch annotation.tool {
        case .highlight:
            if let b = annotation.bounds {
                let rect = pageRect(from: b, pageBounds: pageBounds)
                cg.setFillColor(uiColor(annotation.color).withAlphaComponent(0.4).cgColor)
                cg.fill(rect)
            }
        case .redact:
            if let b = annotation.bounds {
                let rect = pageRect(from: b, pageBounds: pageBounds)
                cg.setFillColor(UIColor.black.cgColor)
                cg.fill(rect)
            }
        case .callout:
            if let b = annotation.bounds {
                let rect = pageRect(from: b, pageBounds: pageBounds)
                cg.setStrokeColor(uiColor(annotation.color).cgColor)
                cg.setLineWidth(3)
                cg.stroke(rect)
            }
        case .freehand:
            if let b64 = annotation.inkDataBase64,
               let data = Data(base64Encoded: b64),
               let drawing = try? PKDrawing(data: data) {
                let image = drawing.image(from: pageBounds, scale: 2)
                if let cgImage = image.cgImage {
                    cg.draw(cgImage, in: pageBounds)
                }
            }
        }
    }

    private func pageRect(from norm: NormalizedRect, pageBounds: CGRect) -> CGRect {
        CGRect(
            x: norm.x * pageBounds.width,
            y: norm.y * pageBounds.height,
            width: norm.w * pageBounds.width,
            height: norm.h * pageBounds.height
        )
    }

    private func uiColor(_ c: AnnotationColor) -> UIColor {
        switch c {
        case .yellow: return UIColor(red: 1.00, green: 0.84, blue: 0.04, alpha: 1)
        case .orange: return UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1)
        case .red:    return UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1)
        case .blue:   return UIColor(red: 0.04, green: 0.52, blue: 1.00, alpha: 1)
        case .green:  return UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1)
        }
    }
}
