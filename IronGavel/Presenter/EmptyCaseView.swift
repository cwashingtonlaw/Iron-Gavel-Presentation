import SwiftUI

/// Onboarding shown when no case is loaded.
struct EmptyCaseView: View {
    let openCaseAction: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.accent)
            Text("Iron Gavel").font(.largeTitle.bold())
            Text("Open a case to begin presenting exhibits to the jury.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: openCaseAction) {
                Label("Open Case", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.accent)
            .accessibilityIdentifier("empty.openCase")
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("empty.case")
    }
}
