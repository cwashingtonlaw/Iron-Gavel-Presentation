import SwiftUI

struct PreviewPane: View {
    @Environment(AppState.self) private var state
    @State private var page: Int = 0
    @State private var exportToast: String?
    @State private var zoomMode = false
    @State private var laserMode = false
    @State private var spotlightMode = false
    @State private var showBinder = false
    @State private var showDisposition = false
    @State private var showEditor = false
    @State private var showComparePicker = false

    private var flattener: AnnotationFlattener {
        AnnotationFlattener(highlightOpacity: state.settings.highlightOpacity)
    }
    private let dispositionLog = DispositionLog()
    private let auditLog = AuditLog()

    var body: some View {
        VStack(spacing: 0) {
            if state.isComparing, let primary = state.comparePrimary, let secondary = state.compareExhibit {
                compareLayout(primary: primary, secondary: secondary)
            } else if let exhibit = state.selectedExhibit, let fileURL = resolvedURL(for: exhibit) {
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
                    ZStack {
                        SpotlightLayer()
                        LaserLayer()
                        if spotlightMode {
                            SpotlightDragSurface()
                        } else if laserMode {
                            LaserDragSurface()
                        } else if zoomMode && state.juryViewport.isFull {
                            ZoomSelectionView { rect in
                                state.setJuryViewport(rect)
                                zoomMode = false
                            }
                        }
                    }
                }
                .overlay(alignment: .leading) {
                    if state.currentTool != nil {
                        ToolOptionsPalette()
                            .padding(.leading, Theme.Spacing.s)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.18), value: state.currentTool)
                .padding(.horizontal, 12)
                .accessibilityIdentifier("preview.pane")
                if let notes = exhibit.notes, !notes.isEmpty {
                    presenterNotes(notes)
                }
                presenterControls()
                binderControls(exhibit: exhibit)
                if exhibit.mediaType == .pdf || exhibit.mediaType == .image {
                    zoomControls()
                }
                if exhibit.mediaType == .pdf {
                    pageControls(fileURL: fileURL)
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
                    onSave: { edited in showEditor = false; CaseController(state: state).replace(edited) },
                    onDelete: { showEditor = false; CaseController(state: state).delete(exhibit) },
                    onCancel: { showEditor = false }
                )
            }
        }
        .sheet(isPresented: $showBinder) {
            BinderView(onDismiss: { showBinder = false })
        }
        .sheet(isPresented: $showComparePicker) { compareePicker }
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
            applyRequestedPageIfNeeded(state.requestedPreviewPage)
        }
        .onChange(of: state.requestedPreviewPage) { _, requested in
            applyRequestedPageIfNeeded(requested)
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
            Button { CaseController(state: state).toggleKey(exhibit.id) } label: {
                Image(systemName: exhibit.isKey ? "star.fill" : "star")
            }
            .accessibilityIdentifier("exhibit.key")
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

    private func applyRequestedPageIfNeeded(_ requested: Int?) {
        guard let requested,
              let exhibit = state.selectedExhibit,
              exhibit.mediaType == .pdf else { return }
        page = requested
        state.requestedPreviewPage = nil
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

    private func compareLayout(primary: (exhibit: Exhibit, page: Int), secondary: Exhibit) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                Label("Side-by-Side", systemImage: "rectangle.split.2x1")
                    .font(Theme.Typography.itemTitle)
                Spacer()
                Button(role: .destructive) { state.stopCompare() } label: {
                    Label("Stop", systemImage: "xmark.circle")
                }
                .accessibilityIdentifier("compare.stop")
            }
            .tint(Theme.Palette.accent)
            .padding(.horizontal, Theme.Spacing.m)
            CompareSplitView(left: primary, right: (secondary, state.comparePage))
                .padding(.horizontal, 12)
                .accessibilityIdentifier("preview.pane")
        }
    }

    private func presenterControls() -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                laserMode.toggle()
                if !laserMode { state.clearLaser() }
            } label: {
                Label(laserMode ? "Laser On" : "Laser", systemImage: "dot.scope")
            }
            .tint(laserMode ? Theme.Palette.live : Theme.Palette.control)
            .accessibilityIdentifier("laser.toggle")

            Button {
                spotlightMode.toggle()
                if spotlightMode { laserMode = false; state.clearLaser() }
                else { state.clearSpotlight() }
            } label: {
                Label(spotlightMode ? "Spotlight On" : "Spotlight", systemImage: "viewfinder")
            }
            .tint(spotlightMode ? Theme.Palette.live : Theme.Palette.control)
            .accessibilityIdentifier("spotlight.toggle")

            Button { showComparePicker = true } label: {
                Label("Compare", systemImage: "rectangle.split.2x1")
            }
            .tint(Theme.Palette.control)
            .disabled(state.comparePrimary == nil)
            .accessibilityIdentifier("compare.open")
            Spacer()
        }
        .buttonStyle(.bordered)
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private func binderControls(exhibit: Exhibit) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                state.addBinderStep(exhibitId: exhibit.id, page: page)
            } label: {
                Label("Add to Binder", systemImage: "text.badge.plus")
            }
            .accessibilityIdentifier("binder.add")

            Button { showBinder = true } label: {
                Label("Binder", systemImage: "books.vertical")
            }
            .accessibilityIdentifier("binder.open")

            if !state.binderSteps.isEmpty {
                Divider().frame(height: 18)
                Button("◀︎") { state.backBinder() }
                    .disabled(!state.canBackBinder)
                    .accessibilityIdentifier("binder.back")
                Text("Step \(state.binderIndex + 1) of \(state.binderSteps.count)")
                    .font(.caption).monospacedDigit()
                Button("▶︎") { state.advanceBinder() }
                    .disabled(!state.canAdvanceBinder)
                    .accessibilityIdentifier("binder.advance")
            }
            Spacer()
        }
        .buttonStyle(.bordered)
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private func presenterNotes(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "note.text").foregroundStyle(Theme.Palette.accent)
            Text(notes).font(.callout)
            Spacer()
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .padding(.horizontal, 12)
        .accessibilityIdentifier("presenter.notes")
    }

    private var otherExhibits: [Exhibit] {
        let primaryID = state.comparePrimary?.exhibit.id
        return (state.currentCase?.exhibits ?? []).filter { $0.id != primaryID }
    }

    private var compareePicker: some View {
        NavigationStack {
            List(otherExhibits) { exhibit in
                Button {
                    state.startCompare(with: exhibit)
                    showComparePicker = false
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        ExhibitNumberChip(number: exhibit.displayNumber)
                        Text(exhibit.description).foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .accessibilityIdentifier("compare.pick.\(exhibit.id)")
            }
            .navigationTitle("Compare With…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showComparePicker = false }
                }
            }
        }
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

    private func pageControls(fileURL: URL) -> some View {
        let count = PDFDocumentCache.shared.document(for: fileURL)?.pageCount ?? 0
        return HStack(spacing: Theme.Spacing.m) {
            Button("◀︎") { page = PageNavigation.clampPage(page - 1, count: count) }
                .disabled(page <= 0)
                .accessibilityIdentifier("page.prev")

            if count > 0 {
                Menu {
                    ForEach(0..<count, id: \.self) { i in
                        Button("Page \(i + 1)") { page = PageNavigation.clampPage(i, count: count) }
                    }
                } label: {
                    Text("Page \(page + 1) of \(count)")
                        .monospacedDigit()
                }
                .accessibilityIdentifier("page.jump")
            } else {
                Text("Page \(page + 1)").monospacedDigit()
            }

            Button("▶︎") { page = PageNavigation.clampPage(page + 1, count: count) }
                .disabled(count > 0 && page >= count - 1)
                .accessibilityIdentifier("page.next")
        }
        .buttonStyle(.bordered)
        .padding(.vertical, 4)
        .onChange(of: count) { _, newCount in
            // A newly-loaded/shorter document must not leave us past the last page.
            page = PageNavigation.clampPage(page, count: newCount)
        }
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
