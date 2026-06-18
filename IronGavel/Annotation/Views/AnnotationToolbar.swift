import SwiftUI

struct AnnotationToolbar: View {
    let exhibitId: String
    let page: Int
    let onExport: () -> Void
    @Environment(AppState.self) private var state
    @State private var showClearConfirm = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            // Segmented "tools" pill — TrialPad's defining control. Active tool = red fill.
            HStack(spacing: 2) {
                toolButton(.callout, label: "CALLOUT", icon: "rectangle.dashed.and.paperclip")
                toolButton(.highlight, label: "HIGHLIGHT", icon: "highlighter")
                toolButton(.freehand, label: "PEN", icon: "pencil.tip")
                toolButton(.redact, label: "REDACT", icon: "rectangle.fill")
            }
            .padding(3)
            .background(Theme.Palette.control.opacity(0.16), in: Capsule())

            Spacer(minLength: Theme.Spacing.s)

            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .accessibilityLabel("Undo")
            .accessibilityIdentifier("annotation.undo")

            Button(action: { showClearConfirm = true }) {
                Image(systemName: "trash")
            }
            .tint(Theme.Palette.live)
            .accessibilityLabel("Clear")
            .accessibilityIdentifier("annotation.clear")

            Button(action: onExport) {
                Image(systemName: "square.and.arrow.down")
            }
            .accessibilityLabel("Save Copy")
            .accessibilityIdentifier("annotation.export")
        }
        .font(.callout)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .sheet(isPresented: $showClearConfirm) {
            ClearPageConfirm(
                page: page,
                onConfirm: { showClearConfirm = false; state.annotationStore.clear(exhibitId: exhibitId, page: page) },
                onCancel: { showClearConfirm = false }
            )
        }
    }

    @ViewBuilder
    private func toolButton(_ tool: AnnotationTool, label: String, icon: String) -> some View {
        let active = state.currentTool == tool
        Button {
            state.currentTool = active ? nil : tool
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).imageScale(.small)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .tracking(0.4)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 6)
            .foregroundStyle(active ? Color.white : Theme.Palette.control)
            .background(active ? Theme.Palette.live : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("annotation.tool.\(tool.rawValue)")
    }

    private func undo() {
        state.annotationStore.undo(exhibitId: exhibitId, page: page)
    }
}
