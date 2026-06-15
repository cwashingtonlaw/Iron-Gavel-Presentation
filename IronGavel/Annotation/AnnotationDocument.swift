import Foundation

struct AnnotationDocument: Codable, Hashable {
    var contractVersion: String
    var exhibitId: String
    var lastModified: String
    var pages: [String: AnnotationPage]

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case exhibitId       = "exhibit_id"
        case lastModified    = "last_modified"
        case pages
    }

    static func empty(exhibitId: String) -> AnnotationDocument {
        AnnotationDocument(
            contractVersion: AnnotationContractVersion.supported,
            exhibitId: exhibitId,
            lastModified: ISO8601DateFormatter().string(from: Date()),
            pages: [:]
        )
    }
}
