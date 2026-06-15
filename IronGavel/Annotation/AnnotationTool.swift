import Foundation

enum AnnotationTool: String, Codable, CaseIterable, Hashable {
    case highlight
    case redact
    case callout
    case freehand
}
