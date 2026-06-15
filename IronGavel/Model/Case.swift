import Foundation

struct Case: Codable, Hashable {
    let contractVersion: String
    let `case`: CaseIdentity
    let generated: String
    let pathBase: String
    let exhibits: [Exhibit]

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case `case`
        case generated
        case pathBase = "path_base"
        case exhibits
    }
}

struct CaseIdentity: Codable, Hashable {
    let caption: String
    let docket: String
    let court: String
}
