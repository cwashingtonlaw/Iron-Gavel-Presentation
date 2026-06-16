import SwiftUI

struct StatusBadge: View {
    let status: ExhibitStatus

    var body: some View {
        let color = Theme.statusColor(status)
        return Text(status.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.13), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.30), lineWidth: 0.75))
            .accessibilityIdentifier("status.badge.\(status.rawValue)")
    }
}
