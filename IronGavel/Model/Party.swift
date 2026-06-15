import Foundation

enum Party: String, Codable, CaseIterable, Hashable {
    case defense = "Defense"
    case state = "State"
    case joint = "Joint"
    case court = "Court"
}
