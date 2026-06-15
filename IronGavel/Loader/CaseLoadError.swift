import Foundation

enum CaseLoadError: Error, Equatable {
    case missingSidecar(path: String)
    case decodeFailed(message: String)
    case unsupportedContractVersion(found: String, supported: String)
    case fileAccessDenied(path: String)
}
