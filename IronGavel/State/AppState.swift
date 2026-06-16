import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private(set) var currentCase: Case?
    private(set) var caseFolderURL: URL?
    var selectedExhibit: Exhibit?
    private(set) var juryDisplay: JuryDisplay = .empty
    private(set) var lastPublished: (exhibit: Exhibit, page: Int)?
    var externalConnected: Bool = false
    var lastStatusBanner: String?

    var currentTool: AnnotationTool?
    var currentColor: AnnotationColor = .yellow
    let annotationStore = AnnotationStore()
    let videoController = VideoController()

    @ObservationIgnored private var saveTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let writer = AnnotationWriter()
    @ObservationIgnored private let publishStateStore: PublishStateStore

    init(publishStateStore: PublishStateStore = PublishStateStore()) {
        self.publishStateStore = publishStateStore
        annotationStore.onChange = { [weak self] exhibitId in
            self?.handleAnnotationChange(for: exhibitId)
        }
    }

    func apply(case kase: Case, folder: URL) {
        let previousCase = self.currentCase
        self.currentCase = kase
        self.caseFolderURL = folder

        if let previousCase, case let .exhibit(published, page, _) = juryDisplay {
            let updated = kase.exhibits.first(where: { $0.id == published.id })
            if let updated, updated.status != .admitted, published.status == .admitted {
                juryDisplay = .blank
                lastStatusBanner = "Exhibit \(published.id) status changed to \(updated.status.rawValue). Jury display blanked."
            }
            _ = previousCase
            _ = page
        }
    }

    func select(_ exhibit: Exhibit) {
        selectedExhibit = exhibit
    }

    func publishSelected() {
        guard let exhibit = selectedExhibit, exhibit.status == .admitted else { return }
        let v = annotationStore.pageVersion(exhibitId: exhibit.id, page: 0)
        juryDisplay = .exhibit(exhibit, page: 0, annotationsVersion: v)
        lastPublished = (exhibit, 0)
        lastStatusBanner = nil
        persistPublishState()
    }

    func setPage(_ page: Int) {
        if case let .exhibit(exhibit, _, _) = juryDisplay {
            let v = annotationStore.pageVersion(exhibitId: exhibit.id, page: page)
            juryDisplay = .exhibit(exhibit, page: page, annotationsVersion: v)
            lastPublished = (exhibit, page)
            persistPublishState()
        }
    }

    func blank() {
        juryDisplay = .blank
        persistPublishState()
    }

    func restore() {
        if let last = lastPublished {
            let v = annotationStore.pageVersion(exhibitId: last.exhibit.id, page: last.page)
            juryDisplay = .exhibit(last.exhibit, page: last.page, annotationsVersion: v)
            persistPublishState()
        }
    }

    /// Re-publishes whatever the jury was last showing, after a relaunch.
    /// Only restores if the saved exhibit still exists in the loaded case and is admitted.
    func restorePublishedState() {
        guard let saved = publishStateStore.load(),
              let kase = currentCase,
              let exhibit = kase.exhibits.first(where: { $0.id == saved.exhibitId }),
              exhibit.status == .admitted else { return }
        let v = annotationStore.pageVersion(exhibitId: exhibit.id, page: saved.page)
        juryDisplay = .exhibit(exhibit, page: saved.page, annotationsVersion: v)
        lastPublished = (exhibit, saved.page)
        if saved.blanked { juryDisplay = .blank }
    }

    private func persistPublishState() {
        switch juryDisplay {
        case let .exhibit(exhibit, page, _):
            publishStateStore.save(.init(exhibitId: exhibit.id, page: page, blanked: false))
        case .blank:
            if let last = lastPublished {
                publishStateStore.save(.init(exhibitId: last.exhibit.id, page: last.page, blanked: true))
            }
        case .empty:
            publishStateStore.clear()
        }
    }

    func dismissBanner() {
        lastStatusBanner = nil
    }

    private func handleAnnotationChange(for exhibitId: String) {
        if case let .exhibit(published, page, _) = juryDisplay, published.id == exhibitId {
            let v = annotationStore.pageVersion(exhibitId: exhibitId, page: page)
            juryDisplay = .exhibit(published, page: page, annotationsVersion: v)
        }
        scheduleSave(exhibitId: exhibitId)
    }

    private func scheduleSave(exhibitId: String) {
        guard let folder = caseFolderURL else { return }
        saveTasks[exhibitId]?.cancel()
        saveTasks[exhibitId] = Task { [annotationStore, writer] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            let doc = await annotationStore.document(exhibitId: exhibitId)
            let annotationsFolder = folder.appendingPathComponent("Trial/Annotations")
            try? writer.write(doc, to: annotationsFolder)
        }
    }
}
