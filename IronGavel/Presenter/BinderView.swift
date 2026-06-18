import SwiftUI

/// Assemble / reorder / remove the presentation binder (run-of-show). Each row is an
/// exhibit at a page; tapping jumps the jury to that step.
struct BinderView: View {
    @Environment(AppState.self) private var state
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if state.binderSteps.isEmpty {
                    ContentUnavailableView(
                        "No Binder Steps",
                        systemImage: "books.vertical",
                        description: Text("Use “Add to Binder” on an exhibit to build your run-of-show."))
                } else {
                    List {
                        ForEach(Array(state.binderSteps.enumerated()), id: \.element.id) { index, step in
                            Button {
                                state.goToBinderStep(index)
                                onDismiss()
                            } label: {
                                stepRow(index: index, step: step)
                            }
                            .accessibilityIdentifier("binder.row.\(index)")
                        }
                        .onMove { from, to in state.moveBinderStep(from: from, to: to) }
                        .onDelete { offsets in state.removeBinderStep(at: offsets) }
                    }
                }
            }
            .navigationTitle("Presentation Binder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss).accessibilityIdentifier("binder.done")
                }
            }
        }
    }

    @ViewBuilder
    private func stepRow(index: Int, step: BinderStep) -> some View {
        let title = exhibitTitle(for: step.exhibitId)
        HStack(spacing: Theme.Spacing.m) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.Palette.accentDeep)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Typography.itemTitle).lineLimit(1)
                Text("Page \(step.page + 1)").font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.mutedText)
            }
            Spacer()
            if index == state.binderIndex {
                Image(systemName: "play.circle.fill").foregroundStyle(Theme.Palette.live)
            }
        }
        .padding(.vertical, 2)
    }

    private func exhibitTitle(for id: String) -> String {
        guard let ex = state.currentCase?.exhibits.first(where: { $0.id == id }) else {
            return "\(id) (missing)"
        }
        if let n = ex.displayNumber { return "\(n) — \(ex.description)" }
        return ex.description
    }
}
