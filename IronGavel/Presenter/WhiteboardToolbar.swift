import SwiftUI

struct WhiteboardToolbar: View {
    let onExport: () -> Void
    @Environment(AppState.self) private var state
    @State private var showClearConfirm = false

    private var exhibitId: String { AppState.whiteboardExhibitId }
    private let page = 0

    var body: some View {
        HStack(spacing: 14) {
            toolButton(.freehand, icon: "pencil.tip")
            toolButton(.highlight, icon: "highlighter")

            Divider().frame(height: 22)
            colorPicker
            Divider().frame(height: 22)

            Button { state.annotationStore.undo(exhibitId: exhibitId, page: page) } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .accessibilityIdentifier("whiteboard.undo")

            Button { showClearConfirm = true } label: {
                Label("Clear", systemImage: "trash")
            }
            .accessibilityIdentifier("whiteboard.clear")

            Spacer()

            Button(action: onExport) {
                Label("Save PDF", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("whiteboard.export")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .sheet(isPresented: $showClearConfirm) {
            ClearPageConfirm(
                page: page,
                onConfirm: { showClearConfirm = false; state.clearWhiteboard() },
                onCancel: { showClearConfirm = false }
            )
        }
    }

    @ViewBuilder
    private func toolButton(_ tool: AnnotationTool, icon: String) -> some View {
        Button {
            state.currentTool = (state.currentTool == tool) ? nil : tool
        } label: {
            Image(systemName: icon)
                .padding(6)
                .background(state.currentTool == tool ? Color.accentColor.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityIdentifier("whiteboard.tool.\(tool.rawValue)")
    }

    private var colorPicker: some View {
        HStack(spacing: 8) {
            ForEach(AnnotationColor.allCases, id: \.self) { c in
                Button { state.currentColor = c } label: {
                    Circle()
                        .fill(c.uiColor)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.primary, lineWidth: state.currentColor == c ? 2 : 0))
                }
                .accessibilityIdentifier("whiteboard.color.\(c.rawValue)")
            }
        }
    }
}
