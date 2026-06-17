import SwiftUI

/// Always-visible "what the jury sees right now" strip — a graphite broadcast monitor
/// with TrialPad's red LIVE cue, plus a prominent panic blackout. The attorney cannot
/// see the physical jury display, so this mirrors the live jury output.
struct ConfidenceMonitor: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            JuryView()
                .frame(width: 168, height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(frameColor, lineWidth: 2))
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("confidence.monitor")

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(spacing: 6) {
                    Circle().fill(frameColor).frame(width: 8, height: 8)
                    Text(stateLabel)
                        .font(.caption.weight(.heavy))
                        .tracking(0.5)
                        .foregroundStyle(frameColor)
                        .accessibilityIdentifier("confidence.status")
                    if let detail = stateDetail {
                        Text(detail)
                            .font(Theme.Typography.number)
                            .foregroundStyle(Theme.Palette.chromeText)
                    }
                }
                Button(action: toggleBlank) {
                    Label(isBlanked ? "Go Live" : "Blank Jury",
                          systemImage: isBlanked ? "play.fill" : "eye.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isBlanked ? .green : Theme.Palette.live)
                .keyboardShortcut("b", modifiers: .command)
                .accessibilityIdentifier("confidence.blank")
            }
            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.chrome, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }

    private var isBlanked: Bool { state.juryDisplay == .blank }

    private func toggleBlank() {
        if isBlanked { state.restore() } else { state.blank() }
    }

    private var frameColor: Color {
        switch state.juryDisplay {
        case .empty:                return Color.white.opacity(0.35)
        case .blank:                return .orange
        case .exhibit, .whiteboard: return Theme.Palette.live
        }
    }

    private var stateLabel: String {
        switch state.juryDisplay {
        case .empty:      return "IDLE"
        case .blank:      return "BLANKED"
        case .exhibit:    return "● LIVE"
        case .whiteboard: return "● LIVE"
        }
    }

    private var stateDetail: String? {
        switch state.juryDisplay {
        case let .exhibit(exhibit, page, _):
            return "\(exhibit.displayNumber ?? exhibit.description) · p\(page + 1)"
        case .whiteboard:
            return "Whiteboard"
        default:
            return nil
        }
    }
}
