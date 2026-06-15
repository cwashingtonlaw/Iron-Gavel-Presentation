import SwiftUI

struct PreviewPane: View {
    @Environment(AppState.self) private var state
    @State private var page: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            if let exhibit = state.selectedExhibit, let fileURL = resolvedURL(for: exhibit) {
                header(for: exhibit)
                content(exhibit: exhibit, fileURL: fileURL)
                if exhibit.mediaType == .pdf {
                    pageControls()
                }
            } else {
                Text("Select an exhibit").foregroundStyle(.secondary)
            }
        }
        .padding()
        .onChange(of: state.selectedExhibit?.id) { _, _ in
            page = 0
        }
        .onChange(of: page) { _, newValue in
            if let exhibit = state.selectedExhibit,
               case let .exhibit(currentExhibit, _) = state.juryDisplay,
               currentExhibit.id == exhibit.id {
                state.setPage(newValue)
            }
        }
        .accessibilityIdentifier("preview.pane")
    }

    private func header(for exhibit: Exhibit) -> some View {
        HStack {
            Text("\(exhibit.id) — \(exhibit.description)").font(.headline)
            Spacer()
            StatusBadge(status: exhibit.status)
        }
    }

    @ViewBuilder
    private func content(exhibit: Exhibit, fileURL: URL) -> some View {
        switch exhibit.mediaType {
        case .pdf:
            PDFPreview(fileURL: fileURL, pageIndex: $page)
        case .image:
            ImagePreview(fileURL: fileURL)
        case .video, .unknown:
            Text("Unsupported media type in Phase 1").foregroundStyle(.secondary)
        }
    }

    private func pageControls() -> some View {
        HStack {
            Button("◀︎") { page = max(0, page - 1) }
            Text("Page \(page + 1)")
            Button("▶︎") { page += 1 }
        }
        .buttonStyle(.bordered)
    }

    private func resolvedURL(for exhibit: Exhibit) -> URL? {
        guard let folder = state.caseFolderURL else { return nil }
        return folder.appendingPathComponent(exhibit.file)
    }
}
