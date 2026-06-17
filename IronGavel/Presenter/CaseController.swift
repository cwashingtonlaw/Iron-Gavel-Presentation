import Foundation

/// Coordinates a `Case` mutation → atomic manifest write → AppState refresh → re-select.
/// One place for the persist-and-reload dance that key/folder toggles and the editor share.
@MainActor
struct CaseController {
    let state: AppState
    private let writer = CaseManifestWriter()

    init(state: AppState) { self.state = state }

    /// Apply a pure transform to the current case, persist it, and refresh state,
    /// keeping `selectId` selected (nil to clear). Returns false if there is no open case
    /// or the write fails (state is left untouched on failure).
    @discardableResult
    func apply(_ transform: (Case) -> Case, selectId: String?) -> Bool {
        guard let folder = state.caseFolderURL, let kase = state.currentCase else { return false }
        let updated = transform(kase)
        do { try writer.write(updated, to: folder) } catch { return false }
        state.apply(case: updated, folder: folder)
        state.selectedExhibit = selectId.flatMap { id in updated.exhibits.first { $0.id == id } }
        return true
    }

    func toggleKey(_ id: String) {
        apply({ ExhibitMutator.toggleKey(id, in: $0) }, selectId: state.selectedExhibit?.id)
    }

    func setFolder(_ folder: String?, for id: String) {
        apply({ ExhibitMutator.setFolder(folder, for: id, in: $0) }, selectId: state.selectedExhibit?.id)
    }

    /// Persist a drag-reorder of one grouping section. `section` is the section's currently
    /// displayed (sorted) exhibits; `from`/`to` are the SwiftUI `.onMove` offsets.
    func reorder(section: [Exhibit], from: IndexSet, to: Int) {
        let moved = ExhibitReorder.move(section, fromOffsets: from, toOffset: to)
        let orders = Dictionary(uniqueKeysWithValues: moved.map { ($0.id, $0.order) })
        apply({ kase in
            let exhibits = kase.exhibits.map { ex -> Exhibit in
                if let newOrder = orders[ex.id] { return ex.withOrder(newOrder) }
                return ex
            }
            return Case(contractVersion: kase.contractVersion, case: kase.`case`,
                        generated: kase.generated, pathBase: kase.pathBase, exhibits: exhibits)
        }, selectId: state.selectedExhibit?.id)
    }

    /// Replace an exhibit wholesale (used by the editor), keyed by its stable `id`.
    func replace(_ edited: Exhibit) {
        apply({ ExhibitMutator.replacing(edited.id, in: $0) { _ in edited } }, selectId: edited.id)
    }

    func delete(_ exhibit: Exhibit) {
        apply({ kase in
            Case(contractVersion: kase.contractVersion, case: kase.`case`,
                 generated: kase.generated, pathBase: kase.pathBase,
                 exhibits: kase.exhibits.filter { $0.id != exhibit.id })
        }, selectId: nil)
    }
}
