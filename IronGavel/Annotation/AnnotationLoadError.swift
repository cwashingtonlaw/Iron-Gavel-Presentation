import Foundation

enum AnnotationLoadError: Error, Equatable {
    case decodeFailed(message: String)
    case unsupportedContractVersion(found: String, supported: String)
    case fileAccessDenied(path: String)
}
