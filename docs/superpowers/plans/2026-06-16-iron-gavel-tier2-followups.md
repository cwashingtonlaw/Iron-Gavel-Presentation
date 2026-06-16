# Iron Gavel — Tier 2 Follow-ups (deferred presentation features)

Delivered in Tier 2: **zoom-to-region mirrored to the jury** (JuryViewport + ViewportContainer, marquee-drag selection, reset) and **sidebar search/filter** (id/description/witness/Bates).

Deferred — each is sizable enough to be its own phase:

## Laser pointer / spotlight
- Add an optional `jurySpotlight: NormalizedRect?` (or point + radius) to AppState, mirrored to JuryView like the viewport.
- Presenter drag drives the spotlight; JuryView dims everything outside the region (a `Color.black.opacity(0.6)` mask with a clear cut-out).
- Reuse the normalized-coordinate + GeometryReader pattern already established by ViewportContainer / ZoomSelectionView.

## Presentation order ("binders" / playlist)
- A `PresentationPlaylist` model: ordered `[ (exhibitId, page) ]` steps, persisted per case (sidecar JSON, atomic like AnnotationWriter).
- Presenter UI to assemble/reorder steps and step forward/back (advancing publishes the next step).

## Side-by-side compare
- A split presenter+jury layout showing two exhibits/pages at once.
- Requires JuryDisplay to carry two slots (or a dedicated `.compare(...)` case) — a larger, more invasive change; design carefully against the existing single-exhibit publish gate.

## Continuous pinch-zoom + pan (enhancement)
- Current zoom is marquee-to-region (full→region). A natural enhancement is continuous `MagnificationGesture` + `DragGesture` that updates the viewport incrementally, composing transforms. Keep the JuryViewport as the single mirrored source of truth.
