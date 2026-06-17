import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class VideoController {
    private(set) var url: URL?
    private(set) var isPlaying = false
    private(set) var currentTime: CMTime = .zero
    private(set) var duration: CMTime = .zero
    private(set) var clip = ClipRange()
    private(set) var volume: Float = 1.0
    private(set) var isMuted: Bool = false

    @ObservationIgnored let player = AVPlayer()
    /// Fired when the integer-second of `currentTime` changes. Wiring uses this
    /// to mirror the frame-markup page to the jury.
    @ObservationIgnored var onFrameChange: ((Int) -> Void)?

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var lastSecond = -1

    init() {
        // Keep video inside our jury AVPlayerLayer; never hand it off to AirPlay.
        player.allowsExternalPlayback = false
        let interval = CMTime(value: 1, timescale: 10) // 0.1s
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.observePlayback(time)
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    func load(url: URL) {
        guard url != self.url else { return }
        self.url = url
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        isPlaying = false
        currentTime = .zero
        duration = .zero
        clip = ClipRange()
        lastSecond = -1
        Task { [weak self] in
            let loaded = (try? await item.asset.load(.duration)) ?? .zero
            await MainActor.run { self?.duration = loaded }
        }
    }

    func play() { player.play(); isPlaying = true }
    func pause() { player.pause(); isPlaying = false }
    func toggle() { isPlaying ? pause() : play() }

    func seek(to time: CMTime) {
        let clamped = clampToBounds(time)
        updateCurrentTime(clamped)
        player.seek(to: clamped, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setIn() {
        clip.start = currentTime
        clip = clip.clampingEnd(to: duration)
    }

    func setOut() {
        clip.end = currentTime
    }

    func clearClip() { clip = ClipRange() }

    func setVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        volume = clamped
        player.volume = clamped
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    func playClip() {
        guard clip.isValid, let start = clip.start else { return }
        seek(to: start)
        play()
    }

    private func observePlayback(_ time: CMTime) {
        updateCurrentTime(time)
        if isPlaying, clip.isValid, let end = clip.end, time >= end {
            pause()
            player.seek(to: end, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    private func updateCurrentTime(_ time: CMTime) {
        currentTime = time
        let sec = time.seconds.isFinite ? Int(time.seconds.rounded(.down)) : 0
        if sec != lastSecond {
            lastSecond = sec
            onFrameChange?(sec)
        }
    }

    private func clampToBounds(_ time: CMTime) -> CMTime {
        var t = time
        if t < .zero { t = .zero }
        if duration > .zero, t > duration { t = duration }
        return t
    }
}
