import CoreGraphics
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
    /// Presenter-only: a page the doc-search wants the preview to jump to after selecting
    /// an exhibit. NOT mirrored to the jury. PreviewPane consumes and clears it.
    var requestedPreviewPage: Int?

    var currentTool: AnnotationTool?
    var currentColor: AnnotationColor = .yellow
    private(set) var juryViewport: JuryViewport = .full
    /// Normalized (0...1) laser-pointer position, mirrored to the jury. nil = hidden.
    private(set) var laserPoint: CGPoint?
    /// Second exhibit shown alongside the published one in side-by-side compare. nil = off.
    private(set) var compareExhibit: Exhibit?
    private(set) var comparePage: Int = 0
    let annotationStore = AnnotationStore()
    let videoController = VideoController()
    let settings: SettingsStore

    @ObservationIgnored private var saveTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let writer = AnnotationWriter()
    @ObservationIgnored private let publishStateStore: PublishStateStore

    init(publishStateStore: PublishStateStore = PublishStateStore(),
         settings: SettingsStore? = nil) {
        self.publishStateStore = publishStateStore
        let resolvedSettings = settings ?? SettingsStore()
        self.settings = resolvedSettings
        self.currentColor = resolvedSettings.defaultAnnotationColor
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
            if let updated, updated.status != .admitted, published.status == .admitted,
               settings.autoBlankOnDowngrade {
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
        juryViewport = .full
        persistPublishState()
    }

    func setPage(_ page: Int) {
        if case let .exhibit(exhibit, _, _) = juryDisplay {
            let v = annotationStore.pageVersion(exhibitId: exhibit.id, page: page)
            juryDisplay = .exhibit(exhibit, page: page, annotationsVersion: v)
            lastPublished = (exhibit, page)
            juryViewport = .full
            persistPublishState()
        }
    }

    /// Zoom the jury (and presenter) to a normalized region of the current exhibit.
    func setJuryViewport(_ region: NormalizedRect) {
        juryViewport = JuryViewport(region: region.clamped())
    }

    func resetJuryViewport() {
        juryViewport = .full
    }

    // MARK: Laser pointer

    func setLaser(_ point: CGPoint) { laserPoint = point }
    func clearLaser() { laserPoint = nil }

    // MARK: Side-by-side compare

    var isComparing: Bool { compareExhibit != nil }

    /// The published exhibit acting as the left/primary pane during compare, if any.
    var comparePrimary: (exhibit: Exhibit, page: Int)? {
        if case let .exhibit(exhibit, page, _) = juryDisplay { return (exhibit, page) }
        return nil
    }

    func startCompare(with exhibit: Exhibit) {
        compareExhibit = exhibit
        comparePage = 0
    }

    func stopCompare() {
        compareExhibit = nil
        comparePage = 0
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
