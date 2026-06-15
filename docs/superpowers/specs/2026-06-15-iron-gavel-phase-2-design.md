# Iron Gavel — Phase 2 Design (Annotation)

**Date:** 2026-06-15
**Status:** Approved for planning
**Scope:** Phase 2 only — annotation tools + persistence + flattened export. Builds on Phase 1 (`docs/superpowers/specs/2026-06-14-iron-gavel-phase-1-design.md`).

## Goal

Add the recognizable TrialPad annotation toolkit to the Phase 1 viewer:

- **Four tools:** callout, highlight, freehand (Apple Pencil via PencilKit), redact.
- **Persistence:** annotations save to `<CASE_ROOT>/Trial/Annotations/<exhibit-id>.json`, synced via iCloud Drive.
- **Live mirror:** as you draw on the presenter, the jury display updates in real time.
- **Editing:** stroke-level Undo + "Clear page".
- **Export:** "Save annotated copy" flattens the page + annotations into `<CASE_ROOT>/Trial/Annotated/<exhibit-id>-p<n>.pdf`.

Out of scope for Phase 2: per-stroke selection/move/resize, video clips, whiteboard, laser pointer, side-by-side, transcript integration, AI search, the three Phase 1.1 polish items.

## Constraints (inherited from Phase 1)

- iPadOS 17+, SwiftUI, PencilKit, PDFKit.
- Personal-team dev signing.
- Read-only relationship with the original exhibit files. Annotations are sidecar data; they never modify the source PDF/image.
- `exhibits.json` remains the system of record for exhibit metadata. Annotations are owned by the app (this is new authority — see "Authority split" below).

## Decisions locked

| Decision | Choice |
|---|---|
| Tools | All four: callout, highlight, freehand, redact |
| Persistence | `<CASE_ROOT>/Trial/Annotations/<exhibit-id>.json`, one file per exhibit, iCloud-synced |
| Mirror model | Live — jury sees every stroke as you draw |
| Edit model | Stroke-level Undo + Clear-page (no per-stroke selection in Phase 2) |
| Export | "Save annotated copy" → `<CASE_ROOT>/Trial/Annotated/<exhibit-id>-p<n>.pdf` |
| Coordinate space | Normalized 0–1 of the page; survives zoom and page-size changes |
| Freehand engine | `PKCanvasView` (PencilKit); one annotation per page holding the entire `PKDrawing` |
| Color palette | 5 colors: yellow, orange, red, blue, green. Highlight 40% alpha; redact ignores color (always opaque black) |
| Contract version | Frozen v1.0 in `annotations.schema.json` |
| Sync conflict policy | Last-write-wins via `last_modified` timestamp (Phase 3 may revisit) |

## Authority split

Two sidecar contracts now exist:

- `exhibits.json` (v1.0) — owned by `dw-exhibit-manager-crim` skill. The app reads it; never writes.
- `annotations/<id>.json` (v1.0) — owned by the app. The skill never writes it; if it deletes an exhibit, the orphan annotation file is harmless.

Both are read by the app via `NSFileCoordinator`.

## Data contract — `annotations.schema.json` v1.0

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://danielswashington.law/schemas/annotations.schema.json",
  "title": "Iron Gavel Annotation Sidecar",
  "type": "object",
  "required": ["contract_version", "exhibit_id", "last_modified", "pages"],
  "additionalProperties": false,
  "properties": {
    "contract_version": { "type": "string", "const": "1.0" },
    "exhibit_id":        { "type": "string", "pattern": "^[A-Za-z]+-[0-9]{3,}$" },
    "last_modified":     { "type": "string", "format": "date-time" },
    "pages": {
      "type": "object",
      "patternProperties": {
        "^[0-9]+$": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["id", "tool", "color"],
            "additionalProperties": false,
            "properties": {
              "id":    { "type": "string", "format": "uuid" },
              "tool":  { "enum": ["highlight", "redact", "callout", "freehand"] },
              "color": { "type": "string", "pattern": "^#[0-9A-Fa-f]{8}$" },
              "bounds":          { "$ref": "#/$defs/normRect" },
              "callout_source":  { "$ref": "#/$defs/normRect" },
              "ink_data_base64": { "type": "string" }
            }
          }
        }
      }
    }
  },
  "$defs": {
    "normRect": {
      "type": "object",
      "required": ["x", "y", "w", "h"],
      "additionalProperties": false,
      "properties": {
        "x": { "type": "number", "minimum": 0, "maximum": 1 },
        "y": { "type": "number", "minimum": 0, "maximum": 1 },
        "w": { "type": "number", "minimum": 0, "maximum": 1 },
        "h": { "type": "number", "minimum": 0, "maximum": 1 }
      }
    }
  }
}
```

**Field requirements by tool:**
- `highlight` and `redact`: require `bounds`.
- `callout`: requires `bounds` (where the bubble floats) AND `callout_source` (the region pulled).
- `freehand`: requires `ink_data_base64` (the `PKDrawing.dataRepresentation()` Base64 string). Exactly one freehand annotation per page; subsequent strokes update its `ink_data_base64`.

## Architecture

A new `Annotation/` module under `IronGavel/`. Composition:

- **Model layer:** value types (`AnnotationDocument`, `Annotation`, `AnnotationPage`, `AnnotationTool`, `AnnotationColor`, `NormalizedRect`).
- **Persistence layer:** `AnnotationLoader` (read), `AnnotationWriter` (atomic temp+rename, debounced caller-side), `AnnotationLoadError`.
- **State:** `AnnotationStore` (`@Observable`), keyed by `exhibitId`. Owns the in-memory map, the per-exhibit undo stack, version counters, and the debounced save schedule. Injected into the SwiftUI environment alongside `AppState`.
- **Tool layer:** one Swift file per tool (`HighlightGesture`, `RedactGesture`, `CalloutGesture`, `FreehandCanvas`). Each owns one tool's interaction. All write through `AnnotationStore.add(_:to:page:)`.
- **View layer:** `PageAnnotationLayer` (presenter overlay — gesture dispatch + render), `PageAnnotationLayerJury` (jury overlay — render only), `CalloutBubble`, `AnnotationToolbar`, `ClearPageConfirm`.
- **Export:** `AnnotationFlattener` (single-purpose: page + annotations → new PDF).

**Phase 1 modifications:**
- `JuryDisplay.exhibit(_, page:)` → `JuryDisplay.exhibit(_, page:, annotationsVersion: Int)`. The version field bumps on every mutation and forces the jury view to re-render.
- `AppState` gains: `currentTool: AnnotationTool?`, `currentColor: AnnotationColor`, the `AnnotationStore` reference, and a `bumpJuryVersion()` helper. The existing publish gate is unchanged.
- `PreviewPane` wraps its existing PDF/image content in a `ZStack` with `PageAnnotationLayer`; gains `AnnotationToolbar` row.
- `JuryView` wraps in a `ZStack` with `PageAnnotationLayerJury`.

No file from Phase 1 is deleted. No public Phase 1 type is removed.

## File layout

See "Components" section in the brainstorming transcript — reproduced succinctly:

```
IronGavel/Annotation/
  AnnotationContractVersion.swift
  AnnotationTool.swift
  AnnotationColor.swift
  NormalizedRect.swift
  Annotation.swift
  AnnotationPage.swift
  AnnotationDocument.swift
  AnnotationLoadError.swift
  AnnotationLoader.swift
  AnnotationWriter.swift
  AnnotationStore.swift
  Tools/
    HighlightGesture.swift
    RedactGesture.swift
    CalloutGesture.swift
    FreehandCanvas.swift
  Views/
    PageAnnotationLayer.swift
    PageAnnotationLayerJury.swift
    CalloutBubble.swift
    AnnotationToolbar.swift
    ClearPageConfirm.swift
  Export/
    AnnotationFlattener.swift

IronGavel/Presenter/PreviewPane.swift        # MODIFIED
IronGavel/Jury/JuryView.swift                # MODIFIED
IronGavel/State/JuryDisplay.swift            # MODIFIED
IronGavel/State/AppState.swift               # MODIFIED

IronGavelTests/Annotation/*Tests.swift
IronGavelTests/Fixtures/AnnotationsValid/D-001.json
IronGavelTests/Fixtures/AnnotationsBadVersion/D-001.json
IronGavelTests/Fixtures/AnnotationsBadJSON/D-001.json
IronGavelTests/Fixtures/FlattenSource/sample.pdf
IronGavelUITests/AnnotationFlowUITest.swift
```

## Data flow

### Load on exhibit selection

1. `AppState.select(_:)` (existing) → `AnnotationStore.load(folderURL:exhibitId:)`.
2. `AnnotationLoader` reads `<folder>/Annotations/<exhibitId>.json` via `NSFileCoordinator`.
3. Missing file → empty `AnnotationDocument`. Not an error.
4. Decode/version errors → non-blocking banner; in-memory annotations stay empty for this exhibit; disk file is NOT overwritten on the next save unless the user explicitly clears.
5. Loaded document attaches to `AnnotationStore.entries[exhibitId]`. Subsequent loads of the same exhibit hit the cache.

### Draw a highlight / redact

1. User taps Highlight (or Redact) in `AnnotationToolbar` → `AppState.currentTool = .highlight`.
2. User drags on `PageAnnotationLayer`. `HighlightGesture` captures the drag in view coordinates and converts to `NormalizedRect`.
3. On drag end, store appends `{ id: UUID(), tool: .highlight, color: currentColor, bounds: rect }` to `entries[exhibitId].pages[currentPageKey]`.
4. Store increments `entries[exhibitId].pageVersions[currentPage]`. If the exhibit is currently published, `AppState.juryDisplay` is reassigned with the new `annotationsVersion`.
5. Jury view re-renders. Highlight appears on both displays.
6. `AnnotationWriter` is scheduled to fire 500 ms after the last mutation. Bursts coalesce to a single disk write.

### Draw a freehand stroke

1. Tool = `.freehand`. `PageAnnotationLayer` swaps to `FreehandCanvas` (a `PKCanvasView` wrapped via `UIViewRepresentable`).
2. PencilKit owns the gesture; the canvas's `delegate.canvasViewDrawingDidChange` fires.
3. Store finds (or creates) the SINGLE `.freehand` annotation for this page and updates its `ink_data_base64` with `canvas.drawing.dataRepresentation().base64EncodedString()`.
4. Version bump → jury re-renders (jury view rebuilds its `PKDrawing` from `ink_data_base64`).
5. Debounced write.

### Draw a callout

1. Tool = `.callout`. State machine inside `CalloutGesture`:
   - First drag → defines `callout_source`. Layer shows a dashed rectangle.
   - Second drag → defines `bounds`. Layer shows the floating bubble preview.
2. On second-drag end, store adds `{ tool: .callout, color: currentColor, bounds, callout_source }`.
3. `CalloutBubble` rasterizes the source region from the underlying `PDFPage` (or `UIImage` for image exhibits) and renders inside a bordered rounded rectangle at `bounds`.
4. Version bump + debounced write.

### Undo

1. Toolbar Undo. Store pops the most recent `Annotation` from the current page.
2. Special case: if the popped annotation was `.freehand`, this is equivalent to `PKCanvasView.undoManager.undo()` — but to keep the model simple, Undo on `.freehand` removes the entire freehand annotation. (Stroke-level undo within a single PencilKit drawing remains available via PencilKit's own UI gesture, not via our toolbar.)
3. Version bump + debounced write.

### Clear page

1. Toolbar Clear → `ClearPageConfirm` sheet.
2. On confirm, store sets `entries[exhibitId].pages[currentPageKey] = []`. Version bump + write.

### Live mirror

1. The jury view subscribes to `AnnotationStore` via environment.
2. `PageAnnotationLayerJury` reads the same `[Annotation]` for the published exhibit + page and renders identically (without gesture handlers).
3. There is no "publish annotation" button — annotations are live by design.

### Export flattened PDF

1. Toolbar "Save annotated copy" → `AnnotationFlattener.flatten(exhibitFileURL:page:annotations:outputURL:)` runs on a background queue.
2. Flattener constructs a new `PDFDocument`, copies the source page, and renders each annotation on top:
   - Highlight / redact: solid `CGContext` fill at the annotation's bounds (in PDF point coordinates).
   - Freehand: `PKDrawing(data: ...)` then `drawing.image(from:scale:)` and composite.
   - Callout: rasterize source region, composite at bounds with border.
3. Writes atomically to `<CASE_ROOT>/Trial/Annotated/<exhibit-id>-p<n>.pdf` (creates `Annotated/` if absent).
4. Toolbar shows a "Saved to `<path>`" toast.

## Error handling

| Condition | Behavior |
|---|---|
| Annotation file missing | Empty annotations. Silent. |
| Annotation decode failure | Banner: "Could not read annotations for `<id>`. Starting fresh." Disk file preserved until user explicitly clears or edits. |
| Annotation contract version mismatch | Banner: "Annotation contract `<found>` not supported (need 1.0). Annotations not loaded." Refuse to write to that file. |
| Disk write failure | Toast: "Could not save annotations." In-memory state kept; next mutation re-tries. |
| iCloud conflict | Last-write-wins via `last_modified`. |
| Freehand `PKDrawing` decode failure | Drop the freehand annotation for that page; banner. Other annotations on that page survive. |
| Callout source rect cannot be rasterized | Render empty bordered rectangle at `bounds`. No crash. |
| Export flatten failure | Toast: "Could not save annotated copy: `<reason>`". Temp file removed; no partial output. |
| Exhibit deleted from `exhibits.json` while annotations exist | Annotations file orphaned but preserved. |
| External screen disconnect mid-draw | Stroke completes on presenter; on reconnect, jury re-renders from current store state. |

## Testing

### Unit tests (XCTest)

- `AnnotationDocumentCodableTests` — round-trip; rejects v2.0; rejects missing required fields; encodes `last_modified` as ISO-8601 with offset.
- `NormalizedRectTests` — coord conversions; clamping; symmetric round-trip view↔page.
- `AnnotationLoaderTests` — fixture happy path; missing file returns empty document; bad JSON throws `.decodeFailed`; v2.0 fixture throws `.unsupportedVersion`.
- `AnnotationWriterTests` — atomic temp+rename; creates missing parent dir; identical content writes are no-ops at the disk-touch level.
- `AnnotationStoreTests` — add increments page count + bumps version; undo pops last; clear empties page; second `load(exhibitId:)` of same id hits cache; mutation schedules exactly one save after a burst (using a synchronous test scheduler).
- `AnnotationFlattenerTests` — fixture single-page PDF + one of each annotation → non-zero PDF, one page, page dimensions match input, sampled pixel inside each annotation rect matches expected color (within tolerance).

### UI test (XCUITest)

- `AnnotationFlowUITest.test_highlight_appears_after_drag` — load fixture; publish admitted exhibit; tap Highlight; perform a drag on the preview pane; assert a SwiftUI `accessibilityIdentifier("annotation.highlight.\(uuid)")` shape exists. Validate `juryDisplay.annotationsVersion` incremented via a hidden a11y label on the presenter scene.

### Manual trial-readiness additions

Append to `docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md`:

- [ ] Draw one of each tool on a fixture exhibit; confirm jury display reflects each in real time.
- [ ] Quit the app; re-open the case; confirm annotations re-load identically.
- [ ] Save annotated copy; open the resulting file in Files; confirm visual fidelity.
- [ ] Open the same case on a second iPad via iCloud; edit on one; confirm the change appears on the other within ~30 s.

### Out of scope tests (Phase 2)

- Multi-device conflict scenarios beyond last-write-wins.
- Gesture-recognizer fuzzing.
- Pencil pressure-sensitivity verification.
- Performance benchmarks for large PDFs with many annotations.

## Phase 3 outlook (context only)

Video pipeline (AVKit). Independent of Phase 2's annotation system; the annotation layer pattern (`PageAnnotationLayer` + `Jury` variant) can be reused for video frame markup later if useful.

## Open questions deferred

- Per-stroke selection/move/resize → Phase 3+ if the courtroom workflow demands it.
- True conflict-free merge for cross-device annotation editing → revisit if last-write-wins ever burns the firm.
- Stroke-level Undo for freehand inside PencilKit's own undo stack — currently our toolbar's Undo removes the whole freehand annotation; PencilKit's native gesture (two-finger tap) still handles stroke-level inside the canvas. We document this divergence rather than reconciling.
