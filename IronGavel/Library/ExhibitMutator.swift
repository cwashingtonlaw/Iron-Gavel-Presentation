import Foundation

/// Pure transforms over a `Case`'s exhibits. The single place that knows how to
/// produce an updated `Case` from a per-exhibit edit, so views never re-derive it.
enum ExhibitMutator {
    /// Returns a copy of `kase` with the exhibit matching `id` replaced by `transform(exhibit)`.
    /// Non-existent id → unchanged case.
    static func replacing(_ id: String, in kase: Case, with transform: (Exhibit) -> Exhibit) -> Case {
        let exhibits = kase.exhibits.map { $0.id == id ? transform($0) : $0 }
        return Case(contractVersion: kase.contractVersion, case: kase.`case`,
                    generated: kase.generated, pathBase: kase.pathBase, exhibits: exhibits)
    }

    static func toggleKey(_ id: String, in kase: Case) -> Case {
        replacing(id, in: kase) { ex in
            Exhibit(id: ex.id, party: ex.party, description: ex.description, file: ex.file,
                    witness: ex.witness, bates: ex.bates, status: ex.status, mediaType: ex.mediaType,
                    objection: ex.objection, ruling: ex.ruling, notes: ex.notes,
                    exhibitNumber: ex.exhibitNumber, isKey: !ex.isKey, folder: ex.folder, order: ex.order)
        }
    }

    static func setFolder(_ folder: String?, for id: String, in kase: Case) -> Case {
        let normalized = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (normalized?.isEmpty ?? true) ? nil : normalized
        return replacing(id, in: kase) { ex in
            Exhibit(id: ex.id, party: ex.party, description: ex.description, file: ex.file,
                    witness: ex.witness, bates: ex.bates, status: ex.status, mediaType: ex.mediaType,
                    objection: ex.objection, ruling: ex.ruling, notes: ex.notes,
                    exhibitNumber: ex.exhibitNumber, isKey: ex.isKey, folder: value, order: ex.order)
        }
    }
}
