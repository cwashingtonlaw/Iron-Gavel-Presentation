import SwiftUI

struct ClearPageConfirm: View {
    let page: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Clear all annotations on page \(page + 1)?")
                .font(.headline)
            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Clear", role: .destructive, action: onConfirm)
                    .accessibilityIdentifier("annotation.clear.confirm")
            }
        }
        .padding()
    }
}
