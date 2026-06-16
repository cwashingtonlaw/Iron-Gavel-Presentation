import SwiftUI
import UniformTypeIdentifiers

struct PresenterScene: View {
    @Environment(AppState.self) private var state
    @State private var showFolderPicker = false
    @State private var showImporter = false
    @State private var loadError: String?
    @State private var watcher: CaseWatcher?

    private let loader = CaseLoader()
    private let bookmarks = BookmarkStore()

    var body: some View {
        NavigationSplitView {
            ExhibitSidebar()
        } detail: {
            VStack(spacing: 0) {
                PresenterToolbar(openCaseAction: { showFolderPicker = true },
                                 importAction: { showImporter = true })
                Divider()
                if state.currentCase == nil {
                    CaseLibraryView(
                        onOpen: { url in openFolder(url, persistBookmark: true) },
                        onOpenExternal: { showFolderPicker = true }
                    )
                } else {
                    if let banner = state.lastStatusBanner {
                        bannerView(text: banner)
                    }
                    ConfidenceMonitor()
                    Divider()
                    PreviewPane()
                }
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker { url in
                showFolderPicker = false
                openFolder(url, persistBookmark: true)
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.pdf, .image, .audiovisualContent, .audio],
                      allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .alert("Cannot load case", isPresented: errorBinding, presenting: loadError) { _ in
            Button("OK", role: .cancel) { loadError = nil }
        } message: { message in
            Text(message)
        }
        .onAppear(perform: restoreLastCase)
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let folder = state.caseFolderURL, case let .success(urls) = result else { return }
        var accessed: [URL] = []
        for u in urls where u.startAccessingSecurityScopedResource() { accessed.append(u) }
        defer { accessed.forEach { $0.stopAccessingSecurityScopedResource() } }
        do {
            let updated = try ExhibitImporter().importFiles(urls, into: folder)
            state.apply(case: updated, folder: folder)
        } catch {
            loadError = "Import failed: \(error)"
        }
    }

    private func bannerView(text: String) -> some View {
        HStack {
            Text(text).font(.callout)
            Spacer()
            Button("Dismiss") { state.dismissBanner() }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.25))
    }

    private func openFolder(_ url: URL, persistBookmark: Bool) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { /* hold scope for app lifetime */ } }
        do {
            let kase = try loader.load(folderURL: url)
            state.apply(case: kase, folder: url)
            preloadAnnotations(folder: url, exhibits: kase.exhibits)
            watcher = CaseWatcher(folderURL: url) {
                if let newCase = try? loader.load(folderURL: url) {
                    state.apply(case: newCase, folder: url)
                }
            }
            if persistBookmark {
                let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                bookmarks.save(data)
            }
        } catch CaseLoadError.unsupportedContractVersion(let found, let supported) {
            loadError = "This case uses contract \(found); app supports \(supported). Update the app."
        } catch CaseLoadError.missingSidecar(let path) {
            loadError = "exhibits.json not found at \(path)."
        } catch CaseLoadError.decodeFailed(let message) {
            loadError = "Could not read exhibits.json: \(message)"
        } catch {
            loadError = String(describing: error)
        }
    }

    private func restoreLastCase() {
        guard let data = bookmarks.load() else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            bookmarks.clear()
            return
        }
        if stale { bookmarks.clear(); return }
        openFolder(url, persistBookmark: false)
        // Relaunch restoration: re-publish whatever the jury was last showing.
        state.restorePublishedState()
    }

    private func preloadAnnotations(folder: URL, exhibits: [Exhibit]) {
        let annotationsFolder = folder.appendingPathComponent("Trial/Annotations")
        let loader = AnnotationLoader()
        for exhibit in exhibits {
            if let doc = try? loader.load(annotationsFolder: annotationsFolder, exhibitId: exhibit.id) {
                state.annotationStore.apply(doc)
            }
        }
    }
}
