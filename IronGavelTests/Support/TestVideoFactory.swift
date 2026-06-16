import AVFoundation
import CoreGraphics
import Foundation

/// Generates a short solid-color H.264 .mov in the temp dir for tests.
/// Throws on writer failure so callers can `XCTSkip` on a simulator codec hiccup.
enum TestVideoFactory {
    enum FactoryError: Error { case cannotAddInput, writeFailed(String) }

    static func makeShortVideo(seconds: Double = 2,
                               fps: Int32 = 30,
                               size: CGSize = CGSize(width: 320, height: 240)) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("igtest-\(UUID().uuidString).mov")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ])
        guard writer.canAdd(input) else { throw FactoryError.cannotAddInput }
        writer.add(input)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(seconds * Double(fps))
        for i in 0..<frameCount {
            while !input.isReadyForMoreMediaData { usleep(1000) }
            let buffer = try makeBuffer(pool: adaptor.pixelBufferPool!, size: size,
                                        brightness: CGFloat(i) / CGFloat(max(frameCount, 1)))
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        }
        input.markAsFinished()

        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()

        guard writer.status == .completed else {
            throw FactoryError.writeFailed(String(describing: writer.error))
        }
        return url
    }

    private static func makeBuffer(pool: CVPixelBufferPool, size: CGSize,
                                   brightness: CGFloat) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        let buffer = pb!
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        ctx.setFillColor(CGColor(red: brightness, green: 0.3, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        return buffer
    }
}
