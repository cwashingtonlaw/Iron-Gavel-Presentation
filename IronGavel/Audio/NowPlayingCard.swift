import CoreMedia
import SwiftUI

/// "Now playing" visual for audio exhibits (no frames to show). Reads the shared
/// AV controller for play state, elapsed time, and progress. Foreground color is
/// parameterized so it reads on both the presenter chrome and the jury background.
struct NowPlayingCard: View {
    let title: String
    let subtitle: String?
    var foreground: Color = .primary

    @Environment(AppState.self) private var state
    private var controller: VideoController { state.videoController }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: controller.isPlaying ? "waveform" : "speaker.wave.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Palette.accent)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(foreground.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            ProgressView(value: AudioProgress.fraction(current: controller.currentTime,
                                                       duration: controller.duration))
                .frame(maxWidth: 420)
            Text("\(timeString(controller.currentTime)) / \(timeString(controller.duration))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(foreground.opacity(0.8))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("audio.nowplaying")
    }

    private func timeString(_ time: CMTime) -> String {
        let total = time.seconds.isFinite ? Int(time.seconds) : 0
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
