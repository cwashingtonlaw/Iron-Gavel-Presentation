import SwiftUI

struct PreviewPane: View {
    @Environment(AppState.self) private var state
    @State private var page: Int = 0
    @State private var exportToast: String?
    @State private var zoomMode = false
    @State private var showDisposition = false
    @State private var showEditor = false

    private let flattener = AnnotationFlattener()
    private let dispositionLog = DispositionLog()
    private let auditLog = AuditLog()
    private let manifestWriter = CaseManifestWriter()

    var body: some View {
        VStack(spacing: 0) {
            if let exhibit = state.selectedExhibit, let fileURL = resolvedURL(for: exhibit) {
                header(for: exhibit)
                ViewportContainer(viewport: state.juryViewport) {
                    ZStack {
                        content(exhibit: exhibit, fileURL: fileURL)
                        if showsAnnotationLayer(for: exhibit) {
                            PageAnnotationLayer(
                                exhibitId: exhibit.id,
                                exhibitFileURL: fileURL,
                                page: page
                            )
                        }
                    }
                }
                .overlay {
                    if zoomMode && state.juryViewport.isFull {
                        ZoomSelectionView { rect in
                            state.setJuryViewport(rect)
                            zoomMode = false
                        }
                    }
                }
                .padding(.horizontal, 12)
                .accessibilityIdentifier("preview.pane")
                if exhibit.mediaType == .pdf || exhibit.mediaType == .image {
                    zoomControls()
                }
                if exhibit.mediaType == .pdf {
                    pageControls()
                }
                if exhibit.mediaType == .video || exhibit.mediaType == .audio {
                    VideoTransportControls()
                }
                if exhibit.mediaType != .audio {
                    AnnotationToolbar(
                        exhibitId: exhibit.id,
                        page: page,
                        onExport: { exportFlattened(exhibit: exhibit, fileURL: fileURL) }
                    )
                }
                if let toast = exportToast {
                    Text(toast)
                        .font(.caption)
                        .padding(6)
                        .background(Color.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            } else {
                Spacer()
                Text("Select an exhibit").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showEditor) {
            if let exhibit = state.selectedExhibit {
                ExhibitEditorSheet(
                    exhibit: exhibit,
                    onSave: { edited in showEditor = false; updateExhibit(original: exhibit, edited: edited) },
                    onDelete: { showEditor = false; deleteExhibit(exhibit) },
                    onCancel: { showEditor = false }
                )
            }
        }
        .sheet(isPresented: $showDisposition) {
            if let exhibit = state.selectedExhibit {
                DispositionSheet(
                    exhibitId: exhibit.id,
                    onSave: { objection, ruling, note in
                        showDisposition = false
                        logDisposition(exhibit: exhibit, objection: objection, ruling: ruling, note: note)
                    },
                    onCancel: { showDisposition = false }
                )
            }
        }
        .onChange(of: state.selectedExhibit?.id) { _, _ in
            page = 0
            loadVideoIfNeeded()
        }
        .onAppear { loadVideoIfNeeded() }
        .onChange(of: videoSecond) { _, sec in
            if state.selectedExhibit?.mediaType == .video { page = sec }
        }
        .onChange(of: page) { _, newValue in
            if let exhibit = state.selectedExhibit,
               case let .exhibit(currentExhibit, _, _) = state.juryDisplay,
               currentExhibit.id == exhibit.id {
                state.setPage(newValue)
            }
        }
    }

    private func header(for exhibit: Exhibit) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            ExhibitNumberChip(number: exhibit.displayNumber)
            Text(exhibit.description)
                .font(Theme.Typography.caseTitle)
                .lineLimit(1)
            StatusBadge(status: exhibit.status)
            Spacer(minLength: Theme.Spacing.m)
            Button { showEditor = true } label: {
                Image(systemName: "pencil")
            }
            .accessibilityIdentifier("exhibit.edit")
            Button { showDisposition = true } label: {
                Image(systemName: "exclamationmark.bubble")
            }
            .accessibilityIdentifier("disposition.open")
        }
        .tint(Theme.Palette.accent)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.xs)
    }

    private func updateExhibit(original: Exhibit, edited: Exhibit) {
        guard let folder = state.caseFolderURL, let kase = state.currentCase else { return }
        let exhibits = kase.exhibits.map { $0.file == original.file ? edited : $0 }
        persist(kase: kase, exhibits: exhibits, folder: folder, select: edited)
    }

    private func deleteExhibit(_ exhibit: Exhibit) {
        guard let folder = state.caseFolderURL, let kase = state.currentCase else { return }
        let exhibits = kase.exhibits.filter { $0.file != exhibit.file }
        persist(kase: kase, exhibits: exhibits, folder: folder, select: nil)
    }

    private func persist(kase: Case, exhibits: [Exhibit], folder: URL, select: Exhibit?) {
        let updated = Case(contractVersion: kase.contractVersion, case: kase.`case`,
                           generated: kase.generated, pathBase: kase.pathBase, exhibits: exhibits)
        try? manifestWriter.write(updated, to: folder)
        state.apply(case: updated, folder: folder)
        state.selectedExhibit = select
    }

    private func logDisposition(exhibit: Exhibit, objection: String, ruling: String, note: String) {
        guard let folder = state.caseFolderURL else { return }
        let time = ISO8601DateFormatter().string(from: Date())
        try? dispositionLog.append(
            .init(time: time, exhibitId: exhibit.id, objection: objection, ruling: ruling, note: note),
            to: folder)
        try? auditLog.append(
            .init(time: time, kind: "disposition", detail: "\(exhibit.id): \(ruling)"),
            to: folder)
    }

    @ViewBuilder
    private func content(exhibit: Exhibit, fileURL: URL) -> some View {
        switch exhibit.mediaType {
        case .pdf:
            PDFPreview(fileURL: fileURL, pageIndex: $page)
        case .image:
            ImagePreview(fileURL: fileURL)
        case .video:
            VideoPresenterView(player: state.videoController.player)
        case .audio:
            NowPlayingCard(title: exhibit.id, subtitle: exhibit.description)
        case .unknown:
            Text("Unsupported media type").foregroundStyle(.secondary)
        }
    }

    private func showsAnnotationLayer(for exhibit: Exhibit) -> Bool {
        if exhibit.mediaType == .audio { return false }
        if exhibit.mediaType == .video && state.videoController.isPlaying { return false }
        return true
    }

    @ViewBuilder
    private func zoomControls() -> some View {
        HStack(spacing: 12) {
            if state.juryViewport.isFull {
                Button(zoomMode ? "Cancel Zoom" : "Zoom to Region") { zoomMode.toggle() }
                    .accessibilityIdentifier("zoom.toggle")
            } else {
                Label("Zoomed", systemImage: "plus.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reset Zoom") { state.resetJuryViewport() }
                    .accessibilityIdentifier("zoom.reset")
            }
        }
        .buttonStyle(.bordered)
        .font(.caption)
        .padding(.vertical, 2)
    }

    private func pageControls() -> some View {
        HStack {
            Button("◀︎") { page = max(0, page - 1) }
            Text("Page \(page + 1)")
            Button("▶︎") { page += 1 }
        }
        .buttonStyle(.bordered)
        .padding(.vertical, 4)
    }

    private func resolvedURL(for exhibit: Exhibit) -> URL? {
        guard let folder = state.caseFolderURL else { return nil }
        return folder.appendingPathComponent(exhibit.file)
    }

    private var videoSecond: Int {
        let s = state.videoController.currentTime.seconds
        return s.isFinite ? Int(s) : 0
    }

    private func loadVideoIfNeeded() {
        guard let exhibit = state.selectedExhibit,
              exhibit.mediaType == .video || exhibit.mediaType == .audio,
              let url = resolvedURL(for: exhibit) else { return }
        state.videoController.load(url: url)
    }

    private func exportFlattened(exhibit: Exhibit, fileURL: URL) {
        guard let folder = state.caseFolderURL else { return }
        let outDir = folder.appendingPathComponent("Trial/Annotated")
        do {
            if exhibit.mediaType == .video {
                let time = state.videoController.currentTime
                let second = time.seconds.isFinite ? Int(time.seconds) : 0
                let frame = try VideoFrameGrabber().image(at: time, url: fileURL)
                let outURL = outDir.appendingPathComponent("\(exhibit.id)-t\(second).pdf")
                let annotations = state.annotationStore.annotations(exhibitId: exhibit.id, page: second)
                try flattener.flatten(image: frame, annotations: annotations, outputURL: outURL)
                exportToast = "Saved to \(outURL.path)"
            } else {
                let outURL = outDir.appendingPathComponent("\(exhibit.id)-p\(page).pdf")
                let annotations = state.annotationStore.annotations(exhibitId: exhibit.id, page: page)
                try flattener.flatten(
                    exhibitFileURL: fileURL,
                    pageIndex: page,
                    annotations: annotations,
                    outputURL: outURL
                )
                exportToast = "Saved to \(outURL.path)"
            }
        } catch {
            exportToast = "Could not save annotated copy: \(error)"
        }
    }
}
