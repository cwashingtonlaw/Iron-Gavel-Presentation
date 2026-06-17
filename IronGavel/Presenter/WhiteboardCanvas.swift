import SwiftUI

/// The blank diagram surface. Reuses the annotation engine via the reserved
/// `AppState.whiteboardExhibitId`, page 0. Presenter is interactive; jury is read-only.
struct WhiteboardCanvas: View {
    let isPresenter: Bool
    @Environment(AppState.self) private var state

    var body: some View {
        ViewportContainer(viewport: state.juryViewport) {
            ZStack {
                boardBackground
                if isPresenter {
                    PageAnnotationLayer(
                        exhibitId: AppState.whiteboardExhibitId,
                        exhibitFileURL: nil,
                        page: 0
                    )
                } else {
                    PageAnnotationLayerJury(
                        exhibitId: AppState.whiteboardExhibitId,
                        exhibitFileURL: nil,
                        page: 0
                    )
                }
            }
        }
        .accessibilityIdentifier(isPresenter ? "whiteboard.presenter" : "whiteboard.jury")
    }

    private var boardBackground: some View {
        Rectangle()
            .fill(boardColor)
            .overlay(Rectangle().stroke(Color.gray.opacity(0.25), lineWidth: 1))
    }

    private var boardColor: Color {
        state.settings.juryBackground == .white ? .white : Color(white: 0.97)
    }
}
