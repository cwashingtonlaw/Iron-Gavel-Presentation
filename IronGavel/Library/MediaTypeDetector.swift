import Foundation

/// Maps a file extension to a MediaType for imported exhibit files.
enum MediaTypeDetector {
    static func detect(fileExtension ext: String) -> MediaType {
        switch ext.lowercased() {
        case "pdf": return .pdf
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp": return .image
        case "mov", "mp4", "m4v": return .video
        case "m4a", "mp3", "wav", "caf", "aac": return .audio
        default: return .unknown
        }
    }

    static func detect(url: URL) -> MediaType { detect(fileExtension: url.pathExtension) }
}
