import SwiftUI

struct StatusBadge: View {
    let status: ExhibitStatus

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.statusColor(status))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .accessibilityIdentifier("status.badge.\(status.rawValue)")
    }
}
