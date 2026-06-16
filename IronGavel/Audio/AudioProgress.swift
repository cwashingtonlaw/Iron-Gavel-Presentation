import CoreMedia

/// Pure progress fraction (0...1) for the now-playing bar.
enum AudioProgress {
    static func fraction(current: CMTime, duration: CMTime) -> Double {
        let c = current.seconds
        let d = duration.seconds
        guard d.isFinite, d > 0, c.isFinite else { return 0 }
        return min(1, max(0, c / d))
    }
}
