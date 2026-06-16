# Iron Gavel — Phase 3 Design Spec (Video)

**Status:** Approved scope (synced play/pause/scrub + clip in/out markers + frame markup). Volume/mute deferred.

**Date:** 2026-06-15

**Builds on:** Phase 1 (viewer + jury publish) and Phase 2 (annotation toolkit), both merged to `main`. Reference: `2026-06-14-iron-gavel-phase-1-design.md`, `2026-06-15-iron-gavel-phase-2-design.md`.

---

## Goal

Make `video` exhibits first-class in Iron Gavel:

1. **Synced playback** — the presenter plays/pauses/scrubs a video; the jury display mirrors it frame-for-frame in real time, respecting the existing publish gate and blank/restore.
2. **Clip in/out markers** — the presenter marks a start and end point and plays just that segment ("play 2:14–2:30"), with replay, without fumbling the scrubber in front of the jury.
3. **Frame markup** — pause the video, draw on the frozen frame with the Phase 2 annotation tools (mirrored to the jury), and "Save Copy" flattens that exact frame plus its annotations to a PDF under `Trial/Annotated/`.

`media_type: "video"` is already valid in `exhibits.schema.json` and `MediaType.swift`; today both `PreviewPane` and `JuryView` fall through their `.video` switch case to "unsupported"/blank. Phase 3 fills those two cases in.

## Non-goals (Phase 3)

- Volume/mute control (audio plays through the device default output).
- Trimming/exporting a video clip to a new video file (clip markers drive playback only; export stays frame-to-PDF).
- Per-frame annotation timelines or scrubbing through saved markups.
- Multiple simultaneous video exhibits / picture-in-picture.
- True frame-accurate seeking guarantees beyond AVPlayer's tolerance (courtroom tolerance ~1 frame is acceptable).

---

## Architecture

### Sync strategy: one shared `AVPlayer`, two layers

The presenter view and the jury view render the **same** `AVPlayer` instance through two separate `AVPlayerLayer`s. Multiple `AVPlayerLayer`s attached to one `AVPlayer` stay frame-synced automatically — there is no clock to reconcile, no position messages to send. The presenter owns transport (play/pause/seek); the jury layer is display-only. This mirrors the Phase 2 decision to share one `AnnotationStore` across both scenes, and it works because `AppState` is already a single instance shared across the presenter and jury `UIWindowScene`s.

### New module: `IronGavel/Video/`

| File | Responsibility |
|------|----------------|
| `ClipRange.swift` | Pure value type: optional `in`/`out` `CMTime`s, validity (`in < out`), `contains(_:)`, `clampingOut(to duration:)`. No AVFoundation playback — fully unit-testable. |
| `VideoController.swift` | `@MainActor @Observable`. Owns the shared `AVPlayer`, current URL, `isPlaying`, `currentTime`, `duration`, and a `ClipRange`. Methods: `load(url:)`, `play()`, `pause()`, `toggle()`, `seek(to:)`, `setIn()`, `setOut()`, `clearClip()`, `playClip()`. A periodic time observer pauses playback at the clip `out` point and clamps `seek`. Holds an `onFrameChange: ((Int) -> Void)?` hook fired when the integer-second of `currentTime` changes (drives jury annotation page). |
| `VideoPresenterView.swift` | `UIViewRepresentable` wrapping an `AVPlayerLayer` bound to `controller.player` (presenter instance). Aspect-fit, black background. |
| `VideoJuryView.swift` | `UIViewRepresentable` wrapping a second `AVPlayerLayer` bound to the **same** `controller.player`. Display-only. |
| `VideoTransportControls.swift` | Presenter SwiftUI controls: play/pause, scrubber (`Slider` bound to `currentTime`), `mm:ss / mm:ss` labels, Set In, Set Out, Clear Clip, Play Clip. Accessibility identifiers (`video.playpause`, `video.scrubber`, `video.setin`, `video.setout`, `video.clearclip`, `video.playclip`) so XCUITest can drive them. |
| `VideoFrameGrabber.swift` | `AVAssetImageGenerator` wrapper: `image(at: CMTime, url: URL) throws -> CGImage`. Used by frame-markup export. |

### Reused from Phase 2 (no new annotation machinery)

- **Drawing live on a paused frame** reuses `PageAnnotationLayer` (presenter) and `PageAnnotationLayerJury` (jury) unchanged, stacked over the `AVPlayerLayer` in the same `ZStack` pattern PDFs use. Annotations are keyed by `exhibitId + page`, where **`page` = `Int(currentTime.seconds)`** — the integer second of the paused frame. Re-pausing at the same second reloads that second's markup. `AnnotationStore`, undo/clear, and debounced disk persistence all work as-is.
- **Export** extends `AnnotationFlattener` with a second entry point `flatten(image: CGImage, annotations:, outputURL:)` that builds a one-page PDF sized to the image and draws annotations with the **existing** private `draw(_:in:cg:)` logic (refactored to be shared by both the PDF-page and image paths). Output path: `Trial/Annotated/<id>-t<seconds>.pdf`.

> Callout's zoomed-source bubble (`CalloutBubble`) reads a PDF region and has no video equivalent; on a video frame the callout records and renders its outline/bubble but the zoom source is empty. Highlight, redact, and freehand are the primary frame-markup tools. Documented, not reconciled.

### State / publish flow

- `AppState` gains `let videoController = VideoController()` and exposes it via `Environment`, exactly like `annotationStore`.
- **Load on select** happens in the view layer: `PreviewPane`, on `selectedExhibit` change where `mediaType == .video`, calls `videoController.load(url:)`. This keeps `AppState`'s unit-tested logic free of `AVPlayer` file decode. The attorney can cue/scrub privately before publishing.
- **Publish** is unchanged: `publishSelected()` sets `juryDisplay = .exhibit(video, page: 0, annotationsVersion: v)`. `JuryView`'s `.video` case renders `VideoJuryView` (same shared player) plus `PageAnnotationLayerJury`. Because the player is shared, the jury picks up wherever playback is.
- **Frame-markup mirroring:** when paused, the presenter sets the jury annotation page to the current second. `VideoController.onFrameChange` is wired (in `PreviewPane`/`AppState`) to call `state.setPage(second)` so the jury's annotation overlay matches the presenter's. The video frame itself is already synced by the shared player.
- **Blank/restore** works through the existing `JuryDisplay` enum with no change; blanking hides `VideoJuryView`, restore shows it again with the player still at position.

### Files modified

- `IronGavel/Presenter/PreviewPane.swift` — `.video` case → `VideoPresenterView` + `VideoTransportControls` + annotation overlay; wire load-on-select and `onFrameChange`; "Save Copy" for video grabs the frame and calls the image flatten path.
- `IronGavel/Jury/JuryView.swift` — `.video` case → `VideoJuryView` + `PageAnnotationLayerJury`.
- `IronGavel/State/AppState.swift` — own `VideoController`.
- `IronGavel/Annotation/Export/AnnotationFlattener.swift` — extract shared draw; add image entry point.
- `project.yml` — only if a new test fixture folder needs a folder reference (video fixture is generated at runtime, so likely no change).

---

## Testing

Playback decode is flaky to assert in CI, so the test weight sits on **pure logic** and **deterministic file output**, with thin UI smoke coverage.

**Unit (XCTest):**
- `ClipRangeTests` — validity (`in < out`), `contains`, `clampingOut(to:)`, nil-in/nil-out behavior, equality.
- `VideoControllerTests` — `@MainActor`. Load sets URL; `toggle` flips `isPlaying`; `setIn`/`setOut` populate the range; `playClip` with no valid range is a no-op; `seek` clamps to `[0, duration]` and to clip bounds; `onFrameChange` fires only on integer-second change. Uses a runtime-generated 2-second test asset (see fixtures); assertions target controller state, not pixel output.
- `VideoFrameFlattenTests` — `flatten(image:annotations:outputURL:)` writes a non-empty PDF whose single page matches the image size; round-trips through `PDFDocument`; atomic (no `.tmp` left).

**UI (XCUITest), minimal and resilient:**
- `VideoFlowUITest` — open the test case, select the video exhibit, assert `VideoPresenterView` + transport controls exist; tap `video.playpause` and assert the button's state label toggles; tap `video.setin`, scrub, `video.setout`, `video.playclip` and assert no crash and controls remain addressable; publish and assert `jury.view` shows the video identifier. No assertion on actual pixel motion.

**Fixtures:**
- `TestVideoFactory` (test support): generates a short solid-color H.264 `.mov` at runtime via `AVAssetWriter` into the temp dir — mirrors Phase 2's runtime-generated PDF fixture, so no binary blob in git.
- Add one `video` exhibit (pointing at a runtime-staged file) to the UI-test case fixture.

**Regression:** all existing 49 tests stay green.

---

## Risks / mitigations

- **AVAssetWriter fixture flakiness in CI/sim** → keep the generated asset tiny (2 s, solid frames, 30 fps) and guard tests with `XCTSkipUnless` on writer success rather than hard-failing the suite on a simulator codec hiccup.
- **Shared-player lifecycle across two scenes** → the player lives in `VideoController` (owned by the single shared `AppState`); views attach/detach layers in `makeUIView`/`dismantleUIView`. Blanking detaches the jury layer but does not tear down the player, so restore is instant.
- **Frame-markup page key collisions** (two annotations a fraction of a second apart) → integer-second bucketing is intentional and documented; courtroom use marks up a held frame, not rapid scrubbing.

---

## Phase 3 task outline (for the plan)

1. `ClipRange` + tests.
2. `VideoFrameGrabber` + (folded into) frame-flatten tests.
3. `AnnotationFlattener` image entry point + `VideoFrameFlattenTests`.
4. `VideoController` + `VideoControllerTests` (+ `TestVideoFactory`).
5. `VideoPresenterView` / `VideoJuryView` (`AVPlayerLayer` representables).
6. `VideoTransportControls`.
7. Wire `AppState.videoController`.
8. Wire `PreviewPane` `.video` case (player + transport + overlay + load-on-select + onFrameChange + video Save Copy).
9. Wire `JuryView` `.video` case (jury player + jury annotation layer).
10. `VideoFlowUITest` + video exhibit fixture.
11. Append Phase 3 items to the trial-readiness checklist.
