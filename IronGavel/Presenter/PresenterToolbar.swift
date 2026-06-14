import SwiftUI

struct PresenterToolbar: View {
    @Environment(AppState.self) private var state
    let openCaseAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button("Open Case", action: openCaseAction)
                .accessibilityIdentifier("toolbar.openCase")

            Spacer()

            Button(action: { state.publishSelected() }) {
                Label("Publish", systemImage: "tv")
            }
            .disabled(!canPublish)
            .accessibilityIdentifier("toolbar.publish")

            Button(action: toggleBlank) {
                Label(isBlanked ? "Live" : "Blank", systemImage: isBlanked ? "play.fill" : "eye.slash")
            }
            .accessibilityIdentifier("toolbar.blank")

            externalIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var canPublish: Bool {
        state.selectedExhibit?.status == .admitted
    }

    private var isBlanked: Bool {
        state.juryDisplay == .blank
    }

    private func toggleBlank() {
        if isBlanked { state.restore() } else { state.blank() }
    }

    private var externalIndicator: some View {
        Label(
            state.externalConnected ? "External: Connected" : "External: Not connected",
            systemImage: state.externalConnected ? "rectangle.connected.to.line.below" : "rectangle.dashed"
        )
        .font(.caption)
        .foregroundStyle(state.externalConnected ? .green : .secondary)
        .accessibilityIdentifier("toolbar.external")
    }
}
