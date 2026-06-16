# Iron Gavel — Phase 3 Implementation Plan (Video)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `video` exhibits first-class in Iron Gavel: a presenter video player with play/pause/scrub, clip in/out markers for segment playback, and frame markup (annotate a paused frame, flatten to PDF), all mirrored live to the jury display.

**Architecture:** One shared `AVPlayer` (owned by a new `@MainActor @Observable VideoController` on `AppState`) renders through two `AVPlayerLayer`s — presenter and jury — which stay frame-synced automatically. The Phase 2 annotation layer is reused over the paused frame, keyed by `page = Int(currentTime.seconds)`. Export grabs the current frame via `AVAssetImageGenerator` and reuses the Phase 2 flattener's draw logic on the image.

**Tech Stack:** Swift 5.9, SwiftUI, AVFoundation (`AVPlayer`, `AVPlayerLayer`, `AVURLAsset`, `AVAssetImageGenerator`, `AVAssetWriter` for the test fixture), CoreMedia (`CMTime`), PDFKit/CoreGraphics (flatten), XCTest, XCUITest. iPadOS 17+. XcodeGen.

**Reference:** `docs/superpowers/specs/2026-06-15-iron-gavel-phase-3-design.md`.

---

## Conventions (read once, applies to every task)

1. **Repo root:** `/Volumes/WD_4TB/Code/Iron-Gavel-Presentation`. Branch: `iron-gavel-phase-3` (already created; the spec is committed there).

2. **XcodeGen drives the project.** Files under `IronGavel/`, `IronGavelTests/`, `IronGavelUITests/` are auto-included via source globs. Create files, then run `xcodegen generate`. Only Task 4 and Task 10 touch nothing in `project.yml` (the video fixture is generated at runtime / the UI-test exhibit is JSON only — no folder reference needed).

3. **Build / test commands** (from repo root):

   ```bash
   xcodegen generate
   xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
     -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -20

   xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
     -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -60
   ```

   If "iPad (A16)" is unavailable pick another from `xcrun simctl list devices available | grep iPad`. Re-run a flaky simulator launch once before treating it as broken.

4. **Baseline:** 49 tests pass on `main` and at the start of this branch. They must stay green at the end of every task.

5. **Co-author trailer** on every commit:
   ```
   Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
   ```

---

## File Structure

New (`IronGavel/Video/`):

```
ClipRange.swift                 # pure CMTime in/out value type
VideoController.swift           # @Observable; shared AVPlayer, transport, clip, frame hook
VideoPresenterView.swift        # UIViewRepresentable AVPlayerLayer (presenter)
VideoJuryView.swift             # UIViewRepresentable AVPlayerLayer (jury, display-only)
VideoTransportControls.swift    # presenter SwiftUI controls
VideoFrameGrabber.swift         # AVAssetImageGenerator -> CGImage at a CMTime
```

Modified:

```
IronGavel/Annotation/Export/AnnotationFlattener.swift   # add image entry point; share draw + atomic write
IronGavel/State/AppState.swift                          # own VideoController
IronGavel/Presenter/PreviewPane.swift                   # .video case: player + transport + overlay + load-on-select + video Save Copy
IronGavel/Jury/JuryView.swift                           # .video case: jury player + jury annotation layer (paused only)
IronGavel/Resources/ui-test-exhibits.json               # add an admitted video exhibit
```

New tests:

```
IronGavelTests/Video/ClipRangeTests.swift
IronGavelTests/Video/VideoControllerTests.swift
IronGavelTests/Video/VideoFrameFlattenTests.swift
IronGavelTests/Support/TestVideoFactory.swift           # runtime-generates a short .mov
IronGavelUITests/VideoFlowUITest.swift
```

---

## Task 1: `ClipRange` — pure in/out value type

**Files:**
- Create: `IronGavel/Video/ClipRange.swift`
- Create: `IronGavelTests/Video/ClipRangeTests.swift`

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/Video/ClipRangeTests.swift`:

```swift
import XCTest
import CoreMedia
@testable import IronGavel

final class ClipRangeTests: XCTestCase {
    private func t(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    func test_empty_or_half_set_range_is_invalid() {
        XCTAssertFalse(ClipRange().isValid)
        XCTAssertFalse(ClipRange(start: t(1)).isValid)
        XCTAssertFalse(ClipRange(end: t(2)).isValid)
    }

    func test_start_before_end_is_valid() {
        XCTAssertTrue(ClipRange(start: t(1), end: t(2)).isValid)
    }

    func test_start_not_before_end_is_invalid() {
        XCTAssertFalse(ClipRange(start: t(2), end: t(2)).isValid)
        XCTAssertFalse(ClipRange(start: t(3), end: t(2)).isValid)
    }

    func test_contains_within_inclusive_bounds() {
        let r = ClipRange(start: t(1), end: t(3))
        XCTAssertTrue(r.contains(t(1)))
        XCTAssertTrue(r.contains(t(2)))
        XCTAssertTrue(r.contains(t(3)))
        XCTAssertFalse(r.contains(t(0.5)))
        XCTAssertFalse(r.contains(t(3.5)))
    }

    func test_contains_is_false_for_invalid_range() {
        XCTAssertFalse(ClipRange(start: t(1)).contains(t(1)))
    }

    func test_clamping_end_shrinks_to_duration() {
        let clamped = ClipRange(start: t(1), end: t(10)).clampingEnd(to: t(5))
        XCTAssertEqual(clamped.start, t(1))
        XCTAssertEqual(clamped.end, t(5))
    }

    func test_clamping_end_leaves_shorter_end_untouched() {
        XCTAssertEqual(ClipRange(start: t(1), end: t(3)).clampingEnd(to: t(5)).end, t(3))
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -30
```

Expected: `Cannot find 'ClipRange' in scope`.

- [ ] **Step 3: Implement `ClipRange.swift`**

Create `IronGavel/Video/ClipRange.swift`:

```swift
import CoreMedia
import Foundation

/// In/out markers for a video segment. Pure value type — no playback.
/// `CMTime` is Comparable, so `<`, `<=`, `>=`, and `min` work directly.
struct ClipRange: Equatable {
    var start: CMTime?
    var end: CMTime?

    init(start: CMTime? = nil, end: CMTime? = nil) {
        self.start = start
        self.end = end
    }

    /// Playable only when both ends are set and start strictly precedes end.
    var isValid: Bool {
        guard let start, let end else { return false }
        return start < end
    }

    func contains(_ time: CMTime) -> Bool {
        guard isValid, let start, let end else { return false }
        return time >= start && time <= end
    }

    /// A copy whose `end` is shrunk to not exceed `duration`.
    func clampingEnd(to duration: CMTime) -> ClipRange {
        guard let end else { return self }
        return ClipRange(start: start, end: min(end, duration))
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Total ≥ 56 tests, 0 failures (49 baseline + 7 here).

- [ ] **Step 5: Commit**

```bash
git add IronGavel/Video/ClipRange.swift IronGavelTests/Video/ClipRangeTests.swift
git commit -m "$(cat <<'EOF'
feat(video): add ClipRange in/out value type

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `AnnotationFlattener` image entry point (refactor + add)

**Files:**
- Modify: `IronGavel/Annotation/Export/AnnotationFlattener.swift`
- Create: `IronGavelTests/Video/VideoFrameFlattenTests.swift`

The existing `flatten(exhibitFileURL:pageIndex:annotations:outputURL:)` stays. We extract its atomic-write into a private helper and add an image-based overload that reuses the existing private `draw(_:in:cg:)`. The image path flips the CGImage (UIKit-oriented PDF context draws CGImages upside down) then draws annotations unflipped — identical orientation handling to the PDF-page path.

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/Video/VideoFrameFlattenTests.swift`:

```swift
import XCTest
import PDFKit
import CoreGraphics
@testable import IronGavel

final class VideoFrameFlattenTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("igvff-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func solidImage(w: Int, h: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    func test_flatten_image_writes_pdf_matching_image_size() throws {
        let img = solidImage(w: 320, h: 240)
        let out = tmp.appendingPathComponent("D-009-t3.pdf")
        let anns = [Annotation(tool: .highlight, color: .yellow,
                               bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.3, h: 0.2))]
        try AnnotationFlattener().flatten(image: img, annotations: anns, outputURL: out)

        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        let doc = try XCTUnwrap(PDFDocument(url: out))
        XCTAssertEqual(doc.pageCount, 1)
        let bounds = try XCTUnwrap(doc.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 320, accuracy: 1)
        XCTAssertEqual(bounds.height, 240, accuracy: 1)
    }

    func test_flatten_image_is_atomic_no_tmp_left() throws {
        let img = solidImage(w: 100, h: 100)
        let out = tmp.appendingPathComponent("D-009-t0.pdf")
        try AnnotationFlattener().flatten(image: img, annotations: [], outputURL: out)
        let contents = try FileManager.default.contentsOfDirectory(atPath: tmp.path)
        XCTAssertTrue(contents.contains("D-009-t0.pdf"))
        XCTAssertFalse(contents.contains { $0.hasSuffix(".tmp") })
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Expected: `extra argument 'image' in call` / no matching `flatten(image:...)`.

- [ ] **Step 3: Refactor + add the image overload**

In `IronGavel/Annotation/Export/AnnotationFlattener.swift`, add the new method and a shared private writer. Insert this method immediately after the existing `flatten(exhibitFileURL:...)` method:

```swift
    func flatten(
        image: CGImage,
        annotations: [Annotation],
        outputURL: URL
    ) throws {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext
            cg.saveGState()
            cg.translateBy(x: 0, y: bounds.height)
            cg.scaleBy(x: 1, y: -1)
            cg.draw(image, in: bounds)
            cg.restoreGState()

            for annotation in annotations {
                draw(annotation, in: bounds, cg: cg)
            }
        }
        try writeAtomically(data, to: outputURL)
    }
```

Then add this private helper (place it next to `pageRect`):

```swift
    private func writeAtomically(_ data: Data, to outputURL: URL) throws {
        let tmp = outputURL.deletingLastPathComponent()
            .appendingPathComponent(outputURL.lastPathComponent + ".tmp")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.removeItem(at: outputURL)
            try FileManager.default.moveItem(at: tmp, to: outputURL)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw FlattenError.writeFailed(message: String(describing: error))
        }
    }
```

Finally, replace the inline write block at the end of the existing `flatten(exhibitFileURL:...)` method. Find this block:

```swift
        let tmp = outputURL.deletingLastPathComponent()
            .appendingPathComponent(outputURL.lastPathComponent + ".tmp")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.removeItem(at: outputURL)
            try FileManager.default.moveItem(at: tmp, to: outputURL)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw FlattenError.writeFailed(message: String(describing: error))
        }
```

and replace it with:

```swift
        try writeAtomically(data, to: outputURL)
```

- [ ] **Step 4: Run tests — expect pass**

The 2 new tests pass; existing `AnnotationFlattenerTests` still pass (the PDF path now routes through `writeAtomically` but behaves identically). Total ≥ 58.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/Annotation/Export/AnnotationFlattener.swift IronGavelTests/Video/VideoFrameFlattenTests.swift
git commit -m "$(cat <<'EOF'
feat(annotation): AnnotationFlattener can flatten a CGImage + annotations to PDF

Shared atomic-write helper; reuses the existing per-annotation draw logic
for the video frame-markup export path.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `VideoFrameGrabber`

**Files:**
- Create: `IronGavel/Video/VideoFrameGrabber.swift`
- Create: `IronGavelTests/Support/TestVideoFactory.swift`
- Modify: `IronGavelTests/Video/VideoFrameFlattenTests.swift` (append one integration test)

`TestVideoFactory` is created here because both this task and Task 4 need a real on-disk video. It generates a tiny solid-color H.264 `.mov` at runtime (no binary blob in git), mirroring Phase 2's runtime-generated PDF fixture.

- [ ] **Step 1: Create `TestVideoFactory`**

Create `IronGavelTests/Support/TestVideoFactory.swift`:

```swift
import AVFoundation
import CoreGraphics
import Foundation

/// Generates a short solid-color H.264 .mov in the temp dir for tests.
/// Throws on writer failure so callers can `XCTSkip` on a simulator codec hiccup.
enum TestVideoFactory {
    enum FactoryError: Error { case cannotAddInput, writeFailed(String) }

    static func makeShortVideo(seconds: Double = 2,
                               fps: Int32 = 30,
                               size: CGSize = CGSize(width: 320, height: 240)) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("igtest-\(UUID().uuidString).mov")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ])
        guard writer.canAdd(input) else { throw FactoryError.cannotAddInput }
        writer.add(input)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(seconds * Double(fps))
        for i in 0..<frameCount {
            while !input.isReadyForMoreMediaData { usleep(1000) }
            let buffer = try makeBuffer(pool: adaptor.pixelBufferPool!, size: size,
                                        brightness: CGFloat(i) / CGFloat(max(frameCount, 1)))
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        }
        input.markAsFinished()

        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()

        guard writer.status == .completed else {
            throw FactoryError.writeFailed(String(describing: writer.error))
        }
        return url
    }

    private static func makeBuffer(pool: CVPixelBufferPool, size: CGSize,
                                   brightness: CGFloat) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        let buffer = pb!
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        ctx.setFillColor(CGColor(red: brightness, green: 0.3, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        return buffer
    }
}
```

- [ ] **Step 2: Append the failing integration test**

Append to `IronGavelTests/Video/VideoFrameFlattenTests.swift` (inside the file, after the existing methods, still in the same class — add these methods):

```swift
    func test_grabber_returns_frame_then_flattens_to_pdf() throws {
        let videoURL: URL
        do { videoURL = try TestVideoFactory.makeShortVideo() }
        catch { throw XCTSkip("video fixture unavailable on this runner: \(error)") }
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let frame = try VideoFrameGrabber().image(at: CMTime(seconds: 1, preferredTimescale: 600),
                                                  url: videoURL)
        XCTAssertGreaterThan(frame.width, 0)

        let out = tmp.appendingPathComponent("D-009-t1.pdf")
        try AnnotationFlattener().flatten(image: frame, annotations: [], outputURL: out)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
    }
```

Add `import AVFoundation` to the top of the file (next to the existing imports).

- [ ] **Step 3: Run tests — expect failure**

Expected: `Cannot find 'VideoFrameGrabber' in scope`.

- [ ] **Step 4: Implement `VideoFrameGrabber.swift`**

Create `IronGavel/Video/VideoFrameGrabber.swift`:

```swift
import AVFoundation
import CoreGraphics

/// Grabs a single decoded frame from a video file at a given time.
struct VideoFrameGrabber {
    enum GrabError: Error { case generationFailed(message: String) }

    func image(at time: CMTime, url: URL) throws -> CGImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        do {
            return try generator.copyCGImage(at: time, actualTime: nil)
        } catch {
            throw GrabError.generationFailed(message: String(describing: error))
        }
    }
}
```

> `copyCGImage(at:actualTime:)` is deprecated in favor of the async `image(at:)`, but the synchronous form keeps the test deterministic and compiles with only a deprecation warning. Acceptable for Phase 3.

- [ ] **Step 5: Run tests — expect pass**

The grabber test passes (or `XCTSkip`s if the simulator can't encode). Total ≥ 59. Existing tests green.

- [ ] **Step 6: Commit**

```bash
git add IronGavel/Video/VideoFrameGrabber.swift IronGavelTests/Support/TestVideoFactory.swift IronGavelTests/Video/VideoFrameFlattenTests.swift
git commit -m "$(cat <<'EOF'
feat(video): add VideoFrameGrabber + runtime test-video factory

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `VideoController`

**Files:**
- Create: `IronGavel/Video/VideoController.swift`
- Create: `IronGavelTests/Video/VideoControllerTests.swift`

The controller owns the shared `AVPlayer`, transport state, the clip range, and an `onFrameChange` hook fired when the integer-second of `currentTime` changes. `seek` updates `currentTime` synchronously (so scrubbing drives UI and the frame hook without waiting for playback), and a periodic time observer drives `currentTime` during playback and pauses at the clip `out` point. Tests assert controller STATE (no reliance on real decode), so they are deterministic.

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/Video/VideoControllerTests.swift`:

```swift
import XCTest
import CoreMedia
@testable import IronGavel

@MainActor
final class VideoControllerTests: XCTestCase {
    private func t(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    func test_load_sets_url_and_resets_state() throws {
        let url: URL
        do { url = try TestVideoFactory.makeShortVideo() }
        catch { throw XCTSkip("video fixture unavailable: \(error)") }
        defer { try? FileManager.default.removeItem(at: url) }

        let c = VideoController()
        c.load(url: url)
        XCTAssertEqual(c.url, url)
        XCTAssertFalse(c.isPlaying)
        XCTAssertEqual(c.currentTime, .zero)
        XCTAssertFalse(c.clip.isValid)
    }

    func test_toggle_flips_isPlaying() {
        let c = VideoController()
        XCTAssertFalse(c.isPlaying)
        c.toggle(); XCTAssertTrue(c.isPlaying)
        c.toggle(); XCTAssertFalse(c.isPlaying)
    }

    func test_set_in_out_builds_valid_clip() {
        let c = VideoController()
        c.seek(to: t(1)); c.setIn()
        c.seek(to: t(3)); c.setOut()
        XCTAssertEqual(c.clip.start, t(1))
        XCTAssertEqual(c.clip.end, t(3))
        XCTAssertTrue(c.clip.isValid)
    }

    func test_clear_clip_resets_markers() {
        let c = VideoController()
        c.seek(to: t(1)); c.setIn()
        c.seek(to: t(3)); c.setOut()
        c.clearClip()
        XCTAssertFalse(c.clip.isValid)
        XCTAssertNil(c.clip.start)
        XCTAssertNil(c.clip.end)
    }

    func test_play_clip_with_no_valid_range_is_noop() {
        let c = VideoController()
        c.playClip()
        XCTAssertFalse(c.isPlaying)
    }

    func test_play_clip_seeks_to_start_and_plays() {
        let c = VideoController()
        c.seek(to: t(1)); c.setIn()
        c.seek(to: t(3)); c.setOut()
        c.seek(to: t(5))
        c.playClip()
        XCTAssertEqual(c.currentTime, t(1))
        XCTAssertTrue(c.isPlaying)
    }

    func test_seek_clamps_negative_to_zero() {
        let c = VideoController()
        c.seek(to: t(-2))
        XCTAssertEqual(c.currentTime, .zero)
    }

    func test_on_frame_change_fires_on_second_boundary_only() {
        let c = VideoController()
        var seconds: [Int] = []
        c.onFrameChange = { seconds.append($0) }
        c.seek(to: t(0.2))   // second 0 -> already -1 baseline, fires 0
        c.seek(to: t(0.7))   // still second 0, no fire
        c.seek(to: t(1.3))   // second 1, fires 1
        c.seek(to: t(2.0))   // second 2, fires 2
        XCTAssertEqual(seconds, [0, 1, 2])
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Expected: `Cannot find 'VideoController' in scope`.

- [ ] **Step 3: Implement `VideoController.swift`**

Create `IronGavel/Video/VideoController.swift`:

```swift
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

    @ObservationIgnored let player = AVPlayer()
    /// Fired when the integer-second of `currentTime` changes. Wiring uses this
    /// to mirror the frame-markup page to the jury.
    @ObservationIgnored var onFrameChange: ((Int) -> Void)?

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var lastSecond = -1

    init() {
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
```

> If the compiler flags the periodic-observer closure under strict concurrency, the `MainActor.assumeIsolated` wrapper already resolves it (the observer queue is `.main`). Project is Swift 5.9 mode, so this compiles.

- [ ] **Step 4: Run tests — expect pass**

Total ≥ 67 (8 new). Existing tests green.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/Video/VideoController.swift IronGavelTests/Video/VideoControllerTests.swift
git commit -m "$(cat <<'EOF'
feat(video): add VideoController (shared AVPlayer, transport, clip, frame hook)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `VideoPresenterView` + `VideoJuryView` (AVPlayerLayer)

**Files:**
- Create: `IronGavel/Video/VideoPresenterView.swift`
- Create: `IronGavel/Video/VideoJuryView.swift`

No unit test (pure UIKit view wrapping; covered by the UI test in Task 10). Build must stay green.

- [ ] **Step 1: Implement `VideoPresenterView.swift`**

Create `IronGavel/Video/VideoPresenterView.swift`:

```swift
import AVFoundation
import SwiftUI
import UIKit

/// A UIView backed by an AVPlayerLayer.
final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct VideoPresenterView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let v = PlayerLayerView()
        v.backgroundColor = .black
        v.playerLayer.videoGravity = .resizeAspect
        v.playerLayer.player = player
        v.accessibilityIdentifier = "video.presenter"
        return v
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}
```

- [ ] **Step 2: Implement `VideoJuryView.swift`**

Create `IronGavel/Video/VideoJuryView.swift`:

```swift
import AVFoundation
import SwiftUI
import UIKit

/// Display-only jury mirror of the shared AVPlayer. Reuses PlayerLayerView.
struct VideoJuryView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let v = PlayerLayerView()
        v.backgroundColor = .black
        v.playerLayer.videoGravity = .resizeAspect
        v.playerLayer.player = player
        v.accessibilityIdentifier = "video.jury"
        return v
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}
```

- [ ] **Step 3: Build — expect success**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add IronGavel/Video/VideoPresenterView.swift IronGavel/Video/VideoJuryView.swift
git commit -m "$(cat <<'EOF'
feat(video): add presenter + jury AVPlayerLayer views (shared player)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `VideoTransportControls`

**Files:**
- Create: `IronGavel/Video/VideoTransportControls.swift`

Presenter controls bound to `state.videoController`. Covered by the Task 10 UI test. Depends on `AppState.videoController`, which does not exist yet — so this file will not compile until Task 7. To keep each task independently buildable, **do Task 7 before building**; commit both together is acceptable, but the steps below build after Task 7. (If executing strictly task-by-task, build at the end of Task 7.)

- [ ] **Step 1: Implement `VideoTransportControls.swift`**

Create `IronGavel/Video/VideoTransportControls.swift`:

```swift
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
```

- [ ] **Step 2: (Build happens at the end of Task 7.)**

- [ ] **Step 3: Commit**

```bash
git add IronGavel/Video/VideoTransportControls.swift
git commit -m "$(cat <<'EOF'
feat(video): add presenter transport controls (play/scrub/clip)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Wire `VideoController` into `AppState`

**Files:**
- Modify: `IronGavel/State/AppState.swift`
- Modify: `IronGavelTests/AppStateTests.swift` (append one assertion)

- [ ] **Step 1: Append the failing test**

Append this method to the existing `AppStateTests` class in `IronGavelTests/AppStateTests.swift` (just before the closing brace of the class):

```swift
    func test_appstate_exposes_video_controller() {
        let state = AppState()
        XCTAssertFalse(state.videoController.isPlaying)
        XCTAssertNil(state.videoController.url)
    }
```

- [ ] **Step 2: Run tests — expect failure**

Expected: `value of type 'AppState' has no member 'videoController'`.

- [ ] **Step 3: Add the property to `AppState`**

In `IronGavel/State/AppState.swift`, find the line:

```swift
    let annotationStore = AnnotationStore()
```

and add directly below it:

```swift
    let videoController = VideoController()
```

- [ ] **Step 4: Build + run tests — expect pass**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -40
```

This is the first build that includes Tasks 6 and 7. Expected: `** TEST SUCCEEDED **`, total ≥ 68.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/State/AppState.swift IronGavelTests/AppStateTests.swift
git commit -m "$(cat <<'EOF'
feat(state): AppState owns the shared VideoController

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Wire the presenter `.video` case in `PreviewPane`

**Files:**
- Modify: `IronGavel/Presenter/PreviewPane.swift`

Adds: the video player + transport controls, load-on-select, a paused-only annotation overlay (`page` tracks the current second), and the video Save Copy path (grab frame → image flatten).

- [ ] **Step 1: Replace the `.video, .unknown` content case**

In `PreviewPane.swift`, find:

```swift
        case .video, .unknown:
            Text("Unsupported media type in Phase 1").foregroundStyle(.secondary)
        }
```

Replace with:

```swift
        case .video:
            VideoPresenterView(player: state.videoController.player)
        case .unknown:
            Text("Unsupported media type").foregroundStyle(.secondary)
        }
```

- [ ] **Step 2: Gate the presenter annotation overlay to non-playing video**

In `PreviewPane.swift`, find the `ZStack` in `body`:

```swift
                ZStack {
                    content(exhibit: exhibit, fileURL: fileURL)
                    PageAnnotationLayer(
                        exhibitId: exhibit.id,
                        exhibitFileURL: fileURL,
                        page: page
                    )
                }
```

Replace with:

```swift
                ZStack {
                    content(exhibit: exhibit, fileURL: fileURL)
                    if !(exhibit.mediaType == .video && state.videoController.isPlaying) {
                        PageAnnotationLayer(
                            exhibitId: exhibit.id,
                            exhibitFileURL: fileURL,
                            page: page
                        )
                    }
                }
```

- [ ] **Step 3: Show transport controls for video**

In `PreviewPane.swift`, find:

```swift
                if exhibit.mediaType == .pdf {
                    pageControls()
                }
```

Add directly below it:

```swift
                if exhibit.mediaType == .video {
                    VideoTransportControls()
                }
```

- [ ] **Step 4: Load-on-select and second-tracking**

In `PreviewPane.swift`, find the `.onChange(of: state.selectedExhibit?.id)` modifier:

```swift
        .onChange(of: state.selectedExhibit?.id) { _, _ in
            page = 0
        }
```

Replace with:

```swift
        .onChange(of: state.selectedExhibit?.id) { _, _ in
            page = 0
            loadVideoIfNeeded()
        }
        .onAppear { loadVideoIfNeeded() }
        .onChange(of: videoSecond) { _, sec in
            if state.selectedExhibit?.mediaType == .video { page = sec }
        }
```

- [ ] **Step 5: Add helpers + video-aware export**

In `PreviewPane.swift`, add these computed/helper members inside the struct (place next to `resolvedURL`):

```swift
    private var videoSecond: Int {
        let s = state.videoController.currentTime.seconds
        return s.isFinite ? Int(s) : 0
    }

    private func loadVideoIfNeeded() {
        guard let exhibit = state.selectedExhibit,
              exhibit.mediaType == .video,
              let url = resolvedURL(for: exhibit) else { return }
        state.videoController.load(url: url)
    }
```

Then replace the entire existing `exportFlattened(exhibit:fileURL:)` method with:

```swift
    private func exportFlattened(exhibit: Exhibit, fileURL: URL) {
        guard let folder = state.caseFolderURL else { return }
        let outDir = folder.appendingPathComponent("Trial/Annotated")
        do {
            if exhibit.mediaType == .video {
                let time = state.videoController.currentTime
                let second = time.seconds.isFinite ? Int(time.seconds) : 0
                let frame = try VideoFrameGrabber().image(at: time, url: fileURL)
                let outURL = outDir.appendingPathComponent("\(exhibit.id)-t\(second).pdf")
                let annotations = state.annotationStore.annotations(exhibitId: exhibit.id, page: second)
                try flattener.flatten(image: frame, annotations: annotations, outputURL: outURL)
                exportToast = "Saved to \(outURL.path)"
            } else {
                let outURL = outDir.appendingPathComponent("\(exhibit.id)-p\(page).pdf")
                let annotations = state.annotationStore.annotations(exhibitId: exhibit.id, page: page)
                try flattener.flatten(
                    exhibitFileURL: fileURL,
                    pageIndex: page,
                    annotations: annotations,
                    outputURL: outURL
                )
                exportToast = "Saved to \(outURL.path)"
            }
        } catch {
            exportToast = "Could not save annotated copy: \(error)"
        }
    }
```

- [ ] **Step 6: Build — expect success**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add IronGavel/Presenter/PreviewPane.swift
git commit -m "$(cat <<'EOF'
feat(presenter): wire video player, transport, frame markup into PreviewPane

Loads the shared player on select, shows transport controls for video,
tracks the current second as the annotation page, gates the overlay to the
paused state, and routes Save Copy through the frame-grab + image flatten.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Wire the jury `.video` case in `JuryView`

**Files:**
- Modify: `IronGavel/Jury/JuryView.swift`

Jury mirrors the shared player; the jury annotation overlay shows only when paused (matching the presenter), keyed by the published `page` (the current second).

- [ ] **Step 1: Gate the jury annotation overlay**

In `JuryView.swift`, find the `.exhibit` branch of `content`:

```swift
        case let .exhibit(exhibit, page, _):
            if let fileURL = resolvedURL(for: exhibit) {
                ZStack {
                    mediaContent(exhibit: exhibit, fileURL: fileURL, page: page)
                    PageAnnotationLayerJury(
                        exhibitId: exhibit.id,
                        exhibitFileURL: fileURL,
                        page: page
                    )
                }
            } else {
                BlankView()
            }
```

Replace with:

```swift
        case let .exhibit(exhibit, page, _):
            if let fileURL = resolvedURL(for: exhibit) {
                ZStack {
                    mediaContent(exhibit: exhibit, fileURL: fileURL, page: page)
                    if !(exhibit.mediaType == .video && state.videoController.isPlaying) {
                        PageAnnotationLayerJury(
                            exhibitId: exhibit.id,
                            exhibitFileURL: fileURL,
                            page: page
                        )
                    }
                }
            } else {
                BlankView()
            }
```

- [ ] **Step 2: Render the jury video player**

In `JuryView.swift`, find:

```swift
        case .video, .unknown:
            BlankView()
        }
```

Replace with:

```swift
        case .video:
            VideoJuryView(player: state.videoController.player)
        case .unknown:
            BlankView()
        }
```

- [ ] **Step 3: Build — expect success**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add IronGavel/Jury/JuryView.swift
git commit -m "$(cat <<'EOF'
feat(jury): mirror shared video player; paused-only annotation overlay

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: UI smoke test + video fixture exhibit

**Files:**
- Modify: `IronGavel/Resources/ui-test-exhibits.json`
- Create: `IronGavelUITests/VideoFlowUITest.swift`

The fixture is applied with the app bundle as the case folder; referenced media files need not exist for control-level assertions (the existing tests publish `D-001` whose PDF is not bundled). The test drives `VideoController` state through the transport controls and confirms publish reaches the jury — no assertion on decoded pixels.

- [ ] **Step 1: Add a video exhibit to the fixture**

In `IronGavel/Resources/ui-test-exhibits.json`, the `exhibits` array currently ends after the `S-014` object. Add a third exhibit. Change the end of the `S-014` object from:

```json
      "notes": ""
    }
  ]
```

to:

```json
      "notes": ""
    },
    {
      "id": "D-009",
      "party": "Defense",
      "description": "Dashcam clip",
      "file": "Exhibits_Admitted/d009-clip.mov",
      "status": "admitted",
      "media_type": "video",
      "witness": "Off. Smith",
      "bates": "DEF0009",
      "objection": "",
      "ruling": "Overruled",
      "notes": ""
    }
  ]
```

- [ ] **Step 2: Write the UI test**

Create `IronGavelUITests/VideoFlowUITest.swift`:

```swift
import XCTest

final class VideoFlowUITest: XCTestCase {
    func test_video_transport_and_publish() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let videoRow = app.staticTexts["D-009"]
        XCTAssertTrue(videoRow.waitForExistence(timeout: 5))
        videoRow.tap()

        // Presenter video surface + transport controls exist.
        let presenter = app.otherElements["video.presenter"]
        XCTAssertTrue(presenter.waitForExistence(timeout: 5))

        let playPause = app.buttons["video.playpause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertEqual(playPause.value as? String, "paused")
        playPause.tap()
        XCTAssertEqual(playPause.value as? String, "playing")
        playPause.tap()
        XCTAssertEqual(playPause.value as? String, "paused")

        // Clip controls are addressable and don't crash the app.
        app.buttons["video.setin"].tap()
        app.buttons["video.setout"].tap()
        app.buttons["video.playclip"].tap()
        app.buttons["video.clearclip"].tap()
        XCTAssertTrue(playPause.isHittable)

        // Publishing an admitted video lights the jury video surface.
        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.isEnabled)
        publish.tap()
        XCTAssertTrue(app.otherElements["jury.view"].waitForExistence(timeout: 5))
    }
}
```

> The jury view renders in the presenter window during tests (no external display in the simulator); `jury.view` is reachable because `JuryView` is hosted by the app. If the jury surface is not present in the single-window test host, assert on `presenter` remaining hittable after publish instead — the publish-gate behavior is already covered by `AppStateTests`.

- [ ] **Step 3: Run the full suite — expect pass**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -60
```

Expected: `** TEST SUCCEEDED **`. New UI test passes; all prior tests green.

- [ ] **Step 4: Commit**

```bash
git add IronGavel/Resources/ui-test-exhibits.json IronGavelUITests/VideoFlowUITest.swift
git commit -m "$(cat <<'EOF'
test(video): UI smoke — transport controls toggle + publish reaches jury

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Append Phase 3 items to the trial-readiness checklist

**Files:**
- Modify: `docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md`

- [ ] **Step 1: Append the Phase 3 section**

Add to the end of `docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md`:

```markdown

## Phase 3 — Video

- [ ] Open a case containing a `video` exhibit; select it; confirm the presenter shows the video with transport controls.
- [ ] Tap Play; confirm playback on the presenter and a frame-synced mirror on the jury display.
- [ ] Scrub the timeline; confirm the jury display follows.
- [ ] Tap Set In at one point, Set Out at a later point, then Play Clip; confirm only that segment plays and stops at the out point. Tap Play Clip again; confirm it replays the segment.
- [ ] Tap Clear; confirm the clip markers reset and full playback resumes.
- [ ] Pause on a frame; pick Highlight/Redact/Freehand and mark the frame; confirm the markup appears on both presenter and jury display.
- [ ] Tap Play; confirm the frame markup hides during playback and the jury shows clean video.
- [ ] Pause again at the same second; confirm the markup re-appears.
- [ ] Tap Save Copy while paused; open `<CASE_ROOT>/Trial/Annotated/<id>-t<seconds>.pdf` in Files; confirm the frame plus markup is baked into the PDF.
- [ ] Blank Screen during video; confirm the jury blacks out and restore resumes the same frame/position.
```

- [ ] **Step 2: Commit**

```bash
git add docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md
git commit -m "$(cat <<'EOF'
docs: extend trial-readiness checklist with Phase 3 video items

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Done criteria

- All 11 tasks committed on `iron-gavel-phase-3`.
- Full suite green on `iPad (A16)` (≥ 68 tests: 49 baseline + ClipRange 7 + frame-flatten 3 + VideoController 8 + AppState 1, plus the video UI test).
- `video` exhibits play on the presenter and mirror to the jury; clip in/out segment playback works; paused-frame markup mirrors and flattens to PDF.
- Then run **superpowers:finishing-a-development-branch** to verify and merge.
```
