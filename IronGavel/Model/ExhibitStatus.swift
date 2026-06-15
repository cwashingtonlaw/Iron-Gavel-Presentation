import Foundation

enum ExhibitStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case offered
    case objected
    case admitted
    case excluded
}
