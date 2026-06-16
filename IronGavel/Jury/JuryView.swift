import SwiftUI

struct JuryView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .accessibilityIdentifier("jury.view")
    }

    @ViewBuilder
    private var content: some View {
        switch state.juryDisplay {
        case .empty:
            EmptyView()
        case .blank:
            BlankView()
        case let .exhibit(exhibit, page, _):
            if let fileURL = resolvedURL(for: exhibit) {
                ViewportContainer(viewport: state.juryViewport) {
                    ZStack {
                        mediaContent(exhibit: exhibit, fileURL: fileURL, page: page)
                        if !(exhibit.mediaType == .video && state.videoController.isPlaying) {
                            PageAnnotationLayerJury(
                                exhibitId: exhibit.id,
                                exhibitFileURL: fileURL,
                                page: page
                            )
                        }
                    }
                }
            } else {
                BlankView()
            }
        }
    }

    @ViewBuilder
    private func mediaContent(exhibit: Exhibit, fileURL: URL, page: Int) -> some View {
        switch exhibit.mediaType {
        case .pdf:
            PDFJuryView(fileURL: fileURL, pageIndex: page)
        case .image:
            ImageJuryView(fileURL: fileURL)
        case .video:
            VideoJuryView(player: state.videoController.player)
        case .unknown:
            BlankView()
        }
    }

    private func resolvedURL(for exhibit: Exhibit) -> URL? {
        guard let folder = state.caseFolderURL else { return nil }
        return folder.appendingPathComponent(exhibit.file)
    }
}
