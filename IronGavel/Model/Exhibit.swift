import Foundation

struct Exhibit: Codable, Hashable, Identifiable {
    let id: String
    let party: Party
    let description: String
    let file: String
    let witness: String?
    let bates: String?
    let status: ExhibitStatus
    let mediaType: MediaType
    let objection: String?
    let ruling: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, party, description, file, witness, bates, status
        case mediaType = "media_type"
        case objection, ruling, notes
    }
}
