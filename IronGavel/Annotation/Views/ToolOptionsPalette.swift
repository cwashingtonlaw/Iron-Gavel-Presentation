import SwiftUI

/// Floating vertical palette of options for the active annotation tool — TrialPad shows
/// this on the document's edge when a drawing tool is picked: close, color swatches, and
/// (for the pen) stroke widths.
struct ToolOptionsPalette: View {
    @Environment(AppState.self) private var state

    private let penWidths: [Double] = [2, 4, 8]

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Button { state.currentTool = nil } label: {
                Image(systemName: "xmark").font(.headline)
            }
            .tint(Theme.Palette.live)
            .accessibilityLabel("Close tool")
            .accessibilityIdentifier("tool.close")

            Divider().frame(width: 26)

            ForEach(AnnotationColor.allCases, id: \.self) { color in
                Button { state.currentColor = color } label: {
                    Circle()
                        .fill(color.uiColor)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.primary,
                                                 lineWidth: state.currentColor == color ? 2.5 : 0))
                        .overlay(Circle().stroke(Theme.Palette.hairline, lineWidth: 0.75))
                }
                .accessibilityIdentifier("annotation.color.\(color.rawValue)")
            }

            if state.currentTool == .freehand {
                Divider().frame(width: 26)
                ForEach(penWidths, id: \.self) { width in
                    Button { state.settings.freehandPenWidth = width } label: {
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: 24, height: max(2, width))
                            .frame(height: 18)
                            .padding(.horizontal, 4)
                            .background(state.settings.freehandPenWidth == width
                                        ? Theme.Palette.live.opacity(0.18) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 5))
                    }
                    .accessibilityIdentifier("pen.width.\(Int(width))")
                }
            }
        }
        .padding(Theme.Spacing.s)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Palette.hairline, lineWidth: 0.75))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .accessibilityIdentifier("tool.palette")
    }
}
