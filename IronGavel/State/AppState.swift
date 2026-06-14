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

    func apply(case kase: Case, folder: URL) {
        let previousCase = self.currentCase
        self.currentCase = kase
        self.caseFolderURL = folder

        if let previousCase, case let .exhibit(published, _) = juryDisplay {
            let updated = kase.exhibits.first(where: { $0.id == published.id })
            if let updated, updated.status != .admitted, published.status == .admitted {
                juryDisplay = .blank
                lastStatusBanner = "Exhibit \(published.id) status changed to \(updated.status.rawValue). Jury display blanked."
            }
            _ = previousCase
        }
    }

    func select(_ exhibit: Exhibit) {
        selectedExhibit = exhibit
    }

    func publishSelected() {
        guard let exhibit = selectedExhibit, exhibit.status == .admitted else { return }
        let display: JuryDisplay = .exhibit(exhibit, page: 0)
        juryDisplay = display
        lastPublished = (exhibit, 0)
        lastStatusBanner = nil
    }

    func setPage(_ page: Int) {
        if case let .exhibit(exhibit, _) = juryDisplay {
            juryDisplay = .exhibit(exhibit, page: page)
            lastPublished = (exhibit, page)
        }
    }

    func blank() {
        juryDisplay = .blank
    }

    func restore() {
        if let last = lastPublished {
            juryDisplay = .exhibit(last.exhibit, page: last.page)
        }
    }

    func dismissBanner() {
        lastStatusBanner = nil
    }
}
