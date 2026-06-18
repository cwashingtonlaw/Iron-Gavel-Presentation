import SwiftUI

/// Iron Gavel design system — modeled on TrialPad's look & feel: a confident crimson-red
/// primary accent used throughout (active tools, controls, output cue), clean light
/// surfaces, pill-shaped control clusters, and a graphite "broadcast monitor" chrome.
/// Clean system sans; monospaced numerals for exhibit numbers / Bates. Inactive controls
/// read as neutral gray so the red always means "active / live". The jury display itself
/// stays minimal and high-contrast.
enum Theme {
    enum Palette {
        /// Primary interactive accent — TrialPad crimson.
        static let accent = Color(red: 0.85, green: 0.21, blue: 0.18)
        static let accentDeep = Color(red: 0.66, green: 0.13, blue: 0.11)
        /// "You are LIVE to the jury" — TrialPad's signature output cue (same red family).
        static let live = Color(red: 0.84, green: 0.23, blue: 0.22)
        /// Neutral color for inactive/idle controls, so red consistently signals "active".
        static let control = Color(uiColor: .systemGray)
        /// Legal exhibit-sticker yellow (matches the physical sticker on the document).
        static let exhibitSticker = Color(red: 0.99, green: 0.84, blue: 0.24)
        static let exhibitStickerText = Color(red: 0.18, green: 0.14, blue: 0.02)
        /// Dark graphite chrome (toolbars, the jury-monitor frame).
        static let chrome = Color(red: 0.13, green: 0.15, blue: 0.18)
        static let chromeText = Color.white.opacity(0.92)
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
        static let caseTitle = Font.system(.title2).weight(.semibold)
        static let screenTitle = Font.system(.largeTitle).weight(.bold)
        static let itemTitle = Font.system(.body).weight(.semibold)
        /// Monospaced for exhibit numbers and Bates.
        static let number = Font.system(.footnote, design: .monospaced).weight(.semibold)
        static let sectionLabel = Font.system(.caption, design: .default).weight(.semibold)
        static let meta = Font.caption
    }

    /// Single source of truth for exhibit-status colors (badges, status text, etc.).
    static func statusColor(_ status: ExhibitStatus) -> Color {
        switch status {
        case .pending:  return Color(red: 0.45, green: 0.45, blue: 0.48)
        case .offered:  return Color(red: 0.20, green: 0.42, blue: 0.66)
        case .objected: return Color(red: 0.80, green: 0.52, blue: 0.10)
        case .admitted: return Color(red: 0.16, green: 0.52, blue: 0.30)
        case .excluded: return Color(red: 0.74, green: 0.24, blue: 0.22)
        }
    }
}

/// The exhibit-number "sticker" chip (monospaced) — or a subtle "Unmarked" chip.
struct ExhibitNumberChip: View {
    let number: String?

    var body: some View {
        if let number {
            // Yellow legal exhibit-sticker, echoing the physical sticker burned on the doc.
            Text(number)
                .font(Theme.Typography.number)
                .foregroundStyle(Theme.Palette.exhibitStickerText)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.Palette.exhibitSticker, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.exhibitStickerText.opacity(0.35), lineWidth: 0.75))
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
