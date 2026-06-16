import SwiftUI

struct PresenterToolbar: View {
    @Environment(AppState.self) private var state
    let openCaseAction: () -> Void
    let importAction: () -> Void

    @State private var showSettings = false
    @State private var showChecklist = false
    private let exporter = ExhibitListExporter()
    private let audit = AuditLog()

    var body: some View {
        HStack(spacing: 16) {
            Button("Open Case", action: openCaseAction)
                .accessibilityIdentifier("toolbar.openCase")

            Button(action: importAction) {
                Label("Import", systemImage: "square.and.arrow.down.on.square")
            }
            .disabled(state.currentCase == nil)
            .accessibilityIdentifier("toolbar.import")

            Button(action: exportList) {
                Label("Export List", systemImage: "square.and.arrow.up")
            }
            .disabled(state.currentCase == nil)
            .accessibilityIdentifier("toolbar.exportList")

            Button { showChecklist = true } label: {
                Label("Checklist", systemImage: "checklist")
            }
            .accessibilityIdentifier("toolbar.checklist")

            Button { showSettings = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityIdentifier("toolbar.settings")

            Spacer()

            Button(action: publish) {
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
        .tint(Theme.Palette.accent)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: state.settings) { showSettings = false }
        }
        .sheet(isPresented: $showChecklist) {
            ChecklistView { showChecklist = false }
        }
    }

    private var canPublish: Bool {
        state.selectedExhibit?.status == .admitted
    }

    private var isBlanked: Bool {
        state.juryDisplay == .blank
    }

    private func publish() {
        state.publishSelected()
        logAudit(kind: "publish", detail: state.selectedExhibit?.id ?? "")
    }

    private func toggleBlank() {
        if isBlanked {
            state.restore()
            logAudit(kind: "restore", detail: "")
        } else {
            state.blank()
            logAudit(kind: "blank", detail: "")
        }
    }

    private func exportList() {
        guard let kase = state.currentCase, let folder = state.caseFolderURL else { return }
        try? exporter.write(kase, to: folder)
    }

    private func logAudit(kind: String, detail: String) {
        guard let folder = state.caseFolderURL else { return }
        let time = ISO8601DateFormatter().string(from: Date())
        try? audit.append(.init(time: time, kind: kind, detail: detail), to: folder)
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
