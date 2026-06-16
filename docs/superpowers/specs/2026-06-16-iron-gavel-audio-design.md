# Iron Gavel — Audio Exhibit Support (Design)

**Goal:** Make `audio` a first-class exhibit type so the firm can present 911 calls, jail calls, wiretaps, and recorded interrogations to the jury — with the same synced play/pause/scrub and clip in/out as video.

## Architecture

Audio plays through the **same shared `AVPlayer`** that video uses (`AppState.videoController`). Only one exhibit presents at a time, so a single AV controller is correct; `AVPlayer` plays audio files (m4a/mp3/wav) via `AVPlayerItem(url:)` with no change. This means **play/pause/scrub and clip in/out are reused for free** from `VideoController` + `VideoTransportControls`.

The only new surface is **visual**: audio has no frames, so the presenter and jury show a **"now playing" card** (title, elapsed/duration, progress bar) instead of an `AVPlayerLayer`.

## Scope

- `MediaType.audio` + `audio` added to `exhibits.schema.json` media_type enum.
- `AudioProgress` — pure `fraction(current:duration:)` for the progress bar (tested).
- `NowPlayingCard` — shared SwiftUI card (icon + title + time + progress), foreground-color parameterized so it reads on both the presenter chrome and the jury background.
- `PreviewPane` `.audio` case → `NowPlayingCard` + the existing `VideoTransportControls`; load-on-select reuses the AV controller; **no annotation overlay, no zoom, no Save Copy** (nothing visual to mark).
- `JuryView` `.audio` case → full-screen `NowPlayingCard` mirroring play state (respects the settings jury background).
- UI-test fixture gains an admitted audio exhibit; UI smoke drives the transport.

## Out of scope (follow-ups)

- Real rendered **waveform** (AVAssetReader sample downsampling) — MVP uses a progress bar.
- **Transcript-synced** audio (scrolling transcript as it plays) — its own phase.

## Tests

- `AudioProgress` fraction math (zero/full/clamp/non-finite duration).
- `MediaType` decodes `audio`.
- UI smoke: select the audio exhibit → now-playing card + transport appear; play/pause toggles; publish reaches the jury.
- All existing tests stay green.
