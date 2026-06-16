import SwiftUI

/// Always-visible "what the jury sees right now" strip for the presenter, plus a
/// prominent panic blackout. The attorney cannot see the physical jury display, so
/// this mirrors the live jury output (empty / blank / exhibit / video).
struct ConfidenceMonitor: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 12) {
            JuryView()
                .frame(width: 160, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.6)))
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("confidence.monitor")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("JURY DISPLAY").font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(statusText)
                        .font(.caption.bold())
                        .foregroundStyle(statusColor)
                        .accessibilityIdentifier("confidence.status")
                }
                Button(action: toggleBlank) {
                    Label(isBlanked ? "Go Live" : "Blank Jury",
                          systemImage: isBlanked ? "play.fill" : "eye.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isBlanked ? .green : .red)
                .keyboardShortcut("b", modifiers: .command)
                .accessibilityIdentifier("confidence.blank")
            }
            Spacer()
        }
        .padding(8)
    }

    private var isBlanked: Bool { state.juryDisplay == .blank }

    private func toggleBlank() {
        if isBlanked { state.restore() } else { state.blank() }
    }

    private var statusText: String {
        switch state.juryDisplay {
        case .empty: return "Nothing published"
        case .blank: return "BLANKED"
        case let .exhibit(exhibit, page, _): return "\(exhibit.id) · p\(page + 1)"
        }
    }

    private var statusColor: Color {
        switch state.juryDisplay {
        case .empty: return .secondary
        case .blank: return .orange
        case .exhibit: return .green
        }
    }
}
