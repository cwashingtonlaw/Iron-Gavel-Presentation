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
    /// Number of connected UIScreens (1 = just the iPad). Driven by ScreenMonitor.
    var screenCount: Int = 1

    static let whiteboardExhibitId = "__whiteboard__"

    /// A second physical/AirPlay screen exists but our external jury scene did NOT
    /// connect → the OS is mirroring the presenter UI (private notes) to the room.
    var airPlayMirroringSuspected: Bool { screenCount > 1 && !externalConnected }

    var currentTool: AnnotationTool?
    var currentColor: AnnotationColor = .yellow
    private(set) var juryViewport: JuryViewport = .full
    /// Normalized (0...1) laser-pointer position, mirrored to the jury. nil = hidden.
    private(set) var laserPoint: CGPoint?
    /// Normalized region to spotlight (rest of the exhibit dimmed), mirrored to the jury. nil = off.
    private(set) var spotlight: NormalizedRect?
    /// Second exhibit shown alongside the published one in side-by-side compare. nil = off.
    private(set) var compareExhibit: Exhibit?
    private(set) var comparePage: Int = 0
    let annotationStore = AnnotationStore()
    let videoController = VideoController()
    let settings: SettingsStore

    /// Ordered presentation binder (run-of-show). Persisted to Trial/binder.json.
    private(set) var binderSteps: [BinderStep] = []
    /// Index of the binder step currently being shown. Only meaningful when stepping.
    private(set) var binderIndex: Int = 0

    @ObservationIgnored private var saveTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let writer = AnnotationWriter()
    @ObservationIgnored private let publishStateStore: PublishStateStore
    @ObservationIgnored private let binderStore = BinderStore()

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
        let switchingCase = previousCase == nil || self.caseFolderURL != folder
        self.currentCase = kase
        self.caseFolderURL = folder
        if switchingCase {
            binderSteps = binderStore.load(from: folder)
            binderIndex = 0
        }

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
        spotlight = nil
        persistPublishState()
    }

    func setPage(_ page: Int) {
        if case let .exhibit(exhibit, _, _) = juryDisplay {
            let v = annotationStore.pageVersion(exhibitId: exhibit.id, page: page)
            juryDisplay = .exhibit(exhibit, page: page, annotationsVersion: v)
            lastPublished = (exhibit, page)
            juryViewport = .full
            spotlight = nil
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

    // MARK: Spotlight

    func setSpotlight(_ region: NormalizedRect) { spotlight = region.clamped() }
    func clearSpotlight() { spotlight = nil }

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

    // MARK: Whiteboard

    func showWhiteboard() {
        let v = annotationStore.pageVersion(exhibitId: Self.whiteboardExhibitId, page: 0)
        juryDisplay = .whiteboard(annotationsVersion: v)
        lastStatusBanner = nil
        juryViewport = .full
        persistPublishState()
    }

    func clearWhiteboard() {
        annotationStore.clear(exhibitId: Self.whiteboardExhibitId, page: 0)
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
        case .empty, .whiteboard:
            publishStateStore.clear()
        }
    }

    func dismissBanner() {
        lastStatusBanner = nil
    }

    // MARK: Presentation binder

    var canAdvanceBinder: Bool { binderIndex + 1 < binderSteps.count }
    var canBackBinder: Bool { binderIndex > 0 && !binderSteps.isEmpty }

    func addBinderStep(exhibitId: String, page: Int) {
        binderSteps.append(BinderStep(exhibitId: exhibitId, page: page))
        persistBinder()
    }

    func removeBinderStep(at offsets: IndexSet) {
        binderSteps.remove(atOffsets: offsets)
        binderIndex = min(binderIndex, max(0, binderSteps.count - 1))
        persistBinder()
    }

    func moveBinderStep(from: IndexSet, to: Int) {
        binderSteps.move(fromOffsets: from, toOffset: to)
        persistBinder()
    }

    /// Selects and publishes the step at `index` (if the exhibit exists and is admitted).
    func goToBinderStep(_ index: Int) {
        guard binderSteps.indices.contains(index), let kase = currentCase else { return }
        let step = binderSteps[index]
        guard let exhibit = kase.exhibits.first(where: { $0.id == step.exhibitId }),
              exhibit.status == .admitted else { return }
        binderIndex = index
        selectedExhibit = exhibit
        let v = annotationStore.pageVersion(exhibitId: exhibit.id, page: step.page)
        juryDisplay = .exhibit(exhibit, page: step.page, annotationsVersion: v)
        lastPublished = (exhibit, step.page)
        lastStatusBanner = nil
        juryViewport = .full
        spotlight = nil
        persistPublishState()
    }

    func advanceBinder() { if canAdvanceBinder { goToBinderStep(binderIndex + 1) } }
    func backBinder() { if canBackBinder { goToBinderStep(binderIndex - 1) } }

    private func persistBinder() {
        guard let folder = caseFolderURL else { return }
        try? binderStore.save(binderSteps, to: folder)
    }

    private func handleAnnotationChange(for exhibitId: String) {
        if case let .exhibit(published, page, _) = juryDisplay, published.id == exhibitId {
            let v = annotationStore.pageVersion(exhibitId: exhibitId, page: page)
            juryDisplay = .exhibit(published, page: page, annotationsVersion: v)
        } else if case .whiteboard = juryDisplay, exhibitId == Self.whiteboardExhibitId {
            let v = annotationStore.pageVersion(exhibitId: exhibitId, page: 0)
            juryDisplay = .whiteboard(annotationsVersion: v)
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
