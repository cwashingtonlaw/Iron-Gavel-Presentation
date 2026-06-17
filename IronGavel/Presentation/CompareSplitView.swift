import SwiftUI

/// Read-only render of one exhibit at a page — a pane in side-by-side compare. Reuses
/// the jury (read-only) renderers; annotations show but are not editable here.
struct ExhibitPaneView: View {
    let exhibit: Exhibit
    let page: Int
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Color.black
            if let fileURL = resolvedURL {
                ZStack {
                    media(fileURL: fileURL)
                    if exhibit.mediaType != .audio {
                        PageAnnotationLayerJury(exhibitId: exhibit.id, exhibitFileURL: fileURL, page: page)
                    }
                }
            } else {
                BlankView()
            }
            VStack {
                Spacer()
                HStack(spacing: Theme.Spacing.s) {
                    ExhibitNumberChip(number: exhibit.displayNumber)
                    Text(exhibit.description)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(Theme.Spacing.s)
                .background(.black.opacity(0.45))
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func media(fileURL: URL) -> some View {
        switch exhibit.mediaType {
        case .pdf:   PDFJuryView(fileURL: fileURL, pageIndex: page)
        case .image: ImageJuryView(fileURL: fileURL)
        case .video: VideoJuryView(player: state.videoController.player)
        case .audio: NowPlayingCard(title: exhibit.displayNumber ?? exhibit.description,
                                    subtitle: exhibit.description, foreground: .white)
        case .unknown: BlankView()
        }
    }

    private var resolvedURL: URL? {
        guard let folder = state.caseFolderURL else { return nil }
        return folder.appendingPathComponent(exhibit.file)
    }
}

/// Two exhibit panes side by side — rendered identically on presenter and jury.
struct CompareSplitView: View {
    let left: (exhibit: Exhibit, page: Int)
    let right: (exhibit: Exhibit, page: Int)

    var body: some View {
        HStack(spacing: 0) {
            ExhibitPaneView(exhibit: left.exhibit, page: left.page)
            Rectangle().fill(Theme.Palette.accent).frame(width: 2)
            ExhibitPaneView(exhibit: right.exhibit, page: right.page)
        }
        .accessibilityIdentifier("compare.split")
    }
}
