import SwiftUI

/// Pure text for the exhibit sticker + Bates stamp shown on a displayed document.
enum ExhibitSticker {
    /// "EXHIBIT <number>" for marked exhibits; nil if the exhibit has no number.
    static func label(for exhibit: Exhibit) -> String? {
        guard let n = exhibit.displayNumber else { return nil }
        return "EXHIBIT \(n)"
    }

    /// The Bates stamp, trimmed; nil if absent/blank.
    static func bates(for exhibit: Exhibit) -> String? {
        guard let b = exhibit.bates?.trimmingCharacters(in: .whitespacesAndNewlines),
              !b.isEmpty else { return nil }
        return b
    }
}

/// Burns a yellow exhibit sticker (bottom-trailing) and a Bates stamp (top-trailing) onto
/// the displayed document — TrialPad's signature exhibit marking, so the courtroom always
/// sees which exhibit is on screen. Visual overlay only; not written into source files.
struct ExhibitStickerOverlay: View {
    let exhibit: Exhibit

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            if let bates = ExhibitSticker.bates(for: exhibit) {
                Text(bates)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.6), lineWidth: 0.75))
                    .padding(.top, 14)
                    .padding(.trailing, 16)
                    .accessibilityIdentifier("exhibit.sticker.bates")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let label = ExhibitSticker.label(for: exhibit) {
                VStack(spacing: 1) {
                    Text(label)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                }
                .foregroundStyle(Theme.Palette.exhibitStickerText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.Palette.exhibitSticker, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.Palette.exhibitStickerText.opacity(0.55), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .padding(.bottom, 16)
                .padding(.trailing, 16)
                .accessibilityIdentifier("exhibit.sticker.label")
            }
        }
        .allowsHitTesting(false)
    }
}
