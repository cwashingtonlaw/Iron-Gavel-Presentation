import SwiftUI

/// Iron Gavel design tokens — a small, cohesive system for the presenter chrome.
/// The jury display deliberately stays minimal/high-contrast and does not consume
/// these accent colors.
enum Theme {
    enum Palette {
        /// Brass-gavel accent.
        static let accent = Color(red: 0.62, green: 0.50, blue: 0.24)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 20
    }

    enum Radius {
        static let card: CGFloat = 8
    }

    /// Single source of truth for exhibit-status colors (badges, status text, etc.).
    static func statusColor(_ status: ExhibitStatus) -> Color {
        switch status {
        case .pending:  return .gray
        case .offered:  return .blue
        case .objected: return .orange
        case .admitted: return .green
        case .excluded: return .red
        }
    }
}
