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
    /// The human-assigned exhibit number / sticker (e.g. "D-1"). Imported documents
    /// start unmarked (nil); the attorney assigns it. Distinct from `id`, the stable
    /// internal key used to track selection, annotations, etc.
    let exhibitNumber: String?
    /// "Hot Doc" star — flags an exhibit for one-tap recall mid-testimony. Defaults false;
    /// absent in legacy/external manifests.
    let isKey: Bool
    /// Folder / group name within the case (by witness or topic). nil = "Unfiled".
    /// Absent in legacy/external manifests.
    let folder: String?

    enum CodingKeys: String, CodingKey {
        case id, party, description, file, witness, bates, status
        case mediaType = "media_type"
        case objection, ruling, notes
        case exhibitNumber = "exhibit_number"
        case isKey = "is_key"
        case folder
    }

    init(id: String, party: Party, description: String, file: String,
         witness: String?, bates: String?, status: ExhibitStatus, mediaType: MediaType,
         objection: String?, ruling: String?, notes: String?, exhibitNumber: String? = nil,
         isKey: Bool = false, folder: String? = nil) {
        self.id = id
        self.party = party
        self.description = description
        self.file = file
        self.witness = witness
        self.bates = bates
        self.status = status
        self.mediaType = mediaType
        self.objection = objection
        self.ruling = ruling
        self.notes = notes
        self.exhibitNumber = exhibitNumber
        self.isKey = isKey
        self.folder = folder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        party = try c.decode(Party.self, forKey: .party)
        description = try c.decode(String.self, forKey: .description)
        file = try c.decode(String.self, forKey: .file)
        witness = try c.decodeIfPresent(String.self, forKey: .witness)
        bates = try c.decodeIfPresent(String.self, forKey: .bates)
        status = try c.decode(ExhibitStatus.self, forKey: .status)
        mediaType = try c.decode(MediaType.self, forKey: .mediaType)
        objection = try c.decodeIfPresent(String.self, forKey: .objection)
        ruling = try c.decodeIfPresent(String.self, forKey: .ruling)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        exhibitNumber = try c.decodeIfPresent(String.self, forKey: .exhibitNumber)
        isKey = try c.decodeIfPresent(Bool.self, forKey: .isKey) ?? false
        folder = try c.decodeIfPresent(String.self, forKey: .folder)
    }

    /// The exhibit number to display, if any. Falls back to `id` for externally-authored
    /// exhibits whose id already is the number (e.g. "D-001"); nil for unmarked imports.
    var displayNumber: String? {
        if let n = exhibitNumber, !n.isEmpty { return n }
        return ExhibitNumbering.looksLikeNumber(id) ? id : nil
    }
}

enum ExhibitNumbering {
    static func looksLikeNumber(_ s: String) -> Bool {
        s.range(of: "^[A-Za-z]{1,4}-?[0-9]{1,5}$", options: .regularExpression) != nil
    }
}
