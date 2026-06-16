import CoreMedia
import SwiftUI

struct VideoTransportControls: View {
    @Environment(AppState.self) private var state
    private var controller: VideoController { state.videoController }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Button(action: { controller.toggle() }) {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityIdentifier("video.playpause")
                .accessibilityValue(controller.isPlaying ? "playing" : "paused")

                Text(timeLabel)
                    .font(.caption.monospacedDigit())
                    .accessibilityIdentifier("video.timelabel")
            }
            scrubber
            HStack(spacing: 12) {
                Button("Set In") { controller.setIn() }
                    .accessibilityIdentifier("video.setin")
                Button("Set Out") { controller.setOut() }
                    .accessibilityIdentifier("video.setout")
                Button("Play Clip") { controller.playClip() }
                    .accessibilityIdentifier("video.playclip")
                Button("Clear") { controller.clearClip() }
                    .accessibilityIdentifier("video.clearclip")
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var scrubber: some View {
        let durSeconds = controller.duration.seconds.isFinite ? controller.duration.seconds : 0
        return Slider(
            value: Binding(
                get: {
                    let s = controller.currentTime.seconds
                    return s.isFinite ? s : 0
                },
                set: { controller.seek(to: CMTime(seconds: $0, preferredTimescale: 600)) }
            ),
            in: 0...max(durSeconds, 1)
        )
        .accessibilityIdentifier("video.scrubber")
    }

    private var timeLabel: String {
        "\(format(controller.currentTime)) / \(format(controller.duration))"
    }

    private func format(_ time: CMTime) -> String {
        let total = time.seconds.isFinite ? Int(time.seconds) : 0
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
