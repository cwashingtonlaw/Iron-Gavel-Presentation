import AVFoundation
import CoreGraphics

/// Grabs a single decoded frame from a video file at a given time.
struct VideoFrameGrabber {
    enum GrabError: Error { case generationFailed(message: String) }

    func image(at time: CMTime, url: URL) throws -> CGImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        do {
            return try generator.copyCGImage(at: time, actualTime: nil)
        } catch {
            throw GrabError.generationFailed(message: String(describing: error))
        }
    }
}
