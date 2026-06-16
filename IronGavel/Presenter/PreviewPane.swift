import SwiftUI

struct PreviewPane: View {
    @Environment(AppState.self) private var state
    @State private var page: Int = 0
    @State private var exportToast: String?

    private let flattener = AnnotationFlattener()

    var body: some View {
        VStack(spacing: 0) {
            if let exhibit = state.selectedExhibit, let fileURL = resolvedURL(for: exhibit) {
                header(for: exhibit)
                ZStack {
                    content(exhibit: exhibit, fileURL: fileURL)
                    if !(exhibit.mediaType == .video && state.videoController.isPlaying) {
                        PageAnnotationLayer(
                            exhibitId: exhibit.id,
                            exhibitFileURL: fileURL,
                            page: page
                        )
                    }
                }
                .padding(.horizontal, 12)
                .accessibilityIdentifier("preview.pane")
                if exhibit.mediaType == .pdf {
                    pageControls()
                }
                if exhibit.mediaType == .video {
                    VideoTransportControls()
                }
                AnnotationToolbar(
                    exhibitId: exhibit.id,
                    page: page,
                    onExport: { exportFlattened(exhibit: exhibit, fileURL: fileURL) }
                )
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
        HStack {
            Text("\(exhibit.id) — \(exhibit.description)").font(.headline)
            Spacer()
            StatusBadge(status: exhibit.status)
        }
        .padding(.horizontal, 12)
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
        case .unknown:
            Text("Unsupported media type").foregroundStyle(.secondary)
        }
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
              exhibit.mediaType == .video,
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
