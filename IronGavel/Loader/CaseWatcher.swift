import Foundation

@MainActor
final class CaseWatcher: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = OperationQueue.main

    private let onChange: () -> Void

    init(folderURL: URL, onChange: @escaping () -> Void) {
        self.presentedItemURL = folderURL.appendingPathComponent("exhibits.json")
        self.onChange = onChange
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    nonisolated func presentedItemDidChange() {
        Task { @MainActor in onChange() }
    }
}
