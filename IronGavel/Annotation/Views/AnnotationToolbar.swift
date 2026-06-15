import SwiftUI

struct AnnotationToolbar: View {
    let exhibitId: String
    let page: Int
    let onExport: () -> Void
    @Environment(AppState.self) private var state
    @State private var showClearConfirm = false

    var body: some View {
        HStack(spacing: 14) {
            toolButton(.highlight, icon: "highlighter")
            toolButton(.redact, icon: "rectangle.fill")
            toolButton(.callout, icon: "rectangle.dashed.and.paperclip")
            toolButton(.freehand, icon: "pencil.tip")

            Divider().frame(height: 22)

            colorPicker

            Divider().frame(height: 22)

            Button(action: undo) {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .accessibilityIdentifier("annotation.undo")

            Button(action: { showClearConfirm = true }) {
                Label("Clear", systemImage: "trash")
            }
            .accessibilityIdentifier("annotation.clear")

            Spacer()

            Button(action: onExport) {
                Label("Save Copy", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("annotation.export")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .sheet(isPresented: $showClearConfirm) {
            ClearPageConfirm(
                page: page,
                onConfirm: { showClearConfirm = false; state.annotationStore.clear(exhibitId: exhibitId, page: page) },
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
        .accessibilityIdentifier("annotation.tool.\(tool.rawValue)")
    }

    private var colorPicker: some View {
        HStack(spacing: 8) {
            ForEach(AnnotationColor.allCases, id: \.self) { c in
                Button {
                    state.currentColor = c
                } label: {
                    Circle()
                        .fill(c.uiColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.primary, lineWidth: state.currentColor == c ? 2 : 0)
                        )
                }
                .accessibilityIdentifier("annotation.color.\(c.rawValue)")
            }
        }
    }

    private func undo() {
        state.annotationStore.undo(exhibitId: exhibitId, page: page)
    }
}
