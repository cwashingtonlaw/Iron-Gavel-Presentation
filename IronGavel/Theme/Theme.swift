import SwiftUI

/// Iron Gavel design system — a refined, editorial-legal aesthetic. Serif for titles,
/// monospaced numerals for exhibit numbers / Bates, a restrained brass-on-ink palette.
/// The jury display stays minimal/high-contrast and does not consume these accents.
enum Theme {
    enum Palette {
        /// Brass-gavel accent.
        static let accent = Color(red: 0.62, green: 0.50, blue: 0.24)
        static let accentDeep = Color(red: 0.42, green: 0.32, blue: 0.13)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let groupedBackground = Color(uiColor: .systemGroupedBackground)
        static let hairline = Color.primary.opacity(0.10)
        static let mutedText = Color.secondary
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Radius {
        static let chip: CGFloat = 6
        static let card: CGFloat = 10
    }

    enum Typography {
        /// Serif display for case names / screen titles.
        static let caseTitle = Font.system(.title2, design: .serif).weight(.semibold)
        static let screenTitle = Font.system(.largeTitle, design: .serif).weight(.semibold)
        /// Document / exhibit name (primary row text).
        static let itemTitle = Font.system(.body).weight(.semibold)
        /// Monospaced for exhibit numbers and Bates.
        static let number = Font.system(.footnote, design: .monospaced).weight(.semibold)
        static let sectionLabel = Font.system(.caption, design: .default).weight(.semibold)
        static let meta = Font.caption
    }

    /// Single source of truth for exhibit-status colors (badges, status text, etc.).
    /// Slightly desaturated for an editorial, less-toy feel.
    static func statusColor(_ status: ExhibitStatus) -> Color {
        switch status {
        case .pending:  return Color(red: 0.45, green: 0.45, blue: 0.48)
        case .offered:  return Color(red: 0.20, green: 0.42, blue: 0.66)
        case .objected: return Color(red: 0.78, green: 0.50, blue: 0.12)
        case .admitted: return Color(red: 0.18, green: 0.49, blue: 0.30)
        case .excluded: return Color(red: 0.66, green: 0.22, blue: 0.20)
        }
    }
}

/// The exhibit-number "sticker" chip (monospaced) — or a subtle "Unmarked" chip.
struct ExhibitNumberChip: View {
    let number: String?

    var body: some View {
        if let number {
            Text(number)
                .font(Theme.Typography.number)
                .foregroundStyle(Theme.Palette.accentDeep)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.Palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.accent.opacity(0.35), lineWidth: 0.75))
        } else {
            Text("Unmarked")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Palette.mutedText)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.Palette.hairline, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        }
    }
}
