import SwiftUI

struct StatusBadge: View {
    let status: ExhibitStatus

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .accessibilityIdentifier("status.badge.\(status.rawValue)")
    }

    private var background: Color {
        switch status {
        case .pending:  return .gray
        case .offered:  return .blue
        case .objected: return .orange
        case .admitted: return .green
        case .excluded: return .red
        }
    }
}
