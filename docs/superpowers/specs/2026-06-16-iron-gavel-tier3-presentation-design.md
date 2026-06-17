# Iron Gavel — Tier 3 Presentation Power (Design)

**Goal:** Add three TrialPad-class presentation features to Iron Gavel:

1. **Whiteboard / live diagram canvas** — a blank, annotatable page (no underlying exhibit) the attorney draws on for the jury (intersection diagrams, timelines, "draw what you saw").
2. **Multiple simultaneous callouts** — several magnified tear-outs coexisting on one page (presenter + jury), with per-callout management.
3. **AirPlay wireless output** — drive the courtroom display over AirPlay instead of HDMI, with an in-app route picker.

These are independent and can ship in any order. Each reuses an existing, proven Iron Gavel pattern rather than introducing a new mirroring mechanism.

---

## Shared architecture context (verified against the code)

- `AppState` (`IronGavel/State/AppState.swift`) is the single `@MainActor @Observable` source of truth, shared by the presenter `WindowGroup` and the jury `UIWindowScene` via `.environment(state)` (`IronGavelApp.swift` sets `JurySceneDelegate.sharedState = state`; `JurySceneDelegate.scene(_:willConnectTo:…)` hosts `JuryView().environment(state)`). **Anything that must mirror to the jury lives in `AppState` and is read by both `PreviewPane` and `JuryView`.** This is the same lever the existing `juryDisplay` and `juryViewport` use.
- `JuryDisplay` (`IronGavel/State/JuryDisplay.swift`) is an `enum: .empty / .blank / .exhibit(Exhibit, page:, annotationsVersion:)`. The jury re-renders when this value changes; `annotationsVersion` is bumped by `AnnotationStore` so annotation edits propagate without changing the exhibit identity.
- `AnnotationStore` (`IronGavel/Annotation/AnnotationStore.swift`) keys documents by **`exhibitId: String`** and within a document by **`page: String`**, holding a plain `[Annotation]` per page. It already stores and returns *multiple* annotations per page (incl. multiple callouts). `add(_:exhibitId:page:)` special-cases `.freehand`: it removes all prior freehand before appending (single merged `PKDrawing` per page). `onChange` drives both the `annotationsVersion` bump and the debounced sidecar save (`AppState.scheduleSave`).
- Both annotation layers iterate the list: `PageAnnotationLayer` (presenter, `IronGavel/Annotation/Views/PageAnnotationLayer.swift`) and `PageAnnotationLayerJury` (jury, `…/PageAnnotationLayerJury.swift`) each `ForEach` over `annotations(exhibitId:page:)` and render highlight/redact/callout/freehand. **Multiple callouts already render today** via this `ForEach` + `CalloutBubble`.
- `CalloutBubble` (`…/Views/CalloutBubble.swift`) rasterizes one source region (`annotation.calloutSource`) of the PDF page and positions the magnified tear-out at `annotation.bounds`. It is purely a function of one annotation's `calloutSource`/`bounds`, so N of them already compose in a `ZStack`.
- `ViewportContainer` + `JuryViewport` (`IronGavel/Presentation/`) is the normalized-rect mirror used for zoom; both `PreviewPane` and `JuryView` wrap their content in `ViewportContainer(viewport: state.juryViewport)`. The whiteboard reuses this verbatim so zoom-to-region works on the whiteboard too.
- External display: `Info.plist` declares `UIWindowSceneSessionRoleExternalDisplayNonInteractive` → `JurySceneDelegate`; `AppDelegate.application(_:configurationForConnecting:options:)` routes that scene role to `JurySceneDelegate`. `AppState.externalConnected` tracks attach/detach.

---

# Feature 1 — Whiteboard / Live Diagram Canvas

### Decision: a new `JuryDisplay` case `.whiteboard`, backed by a synthetic annotation document

The whiteboard is "an annotatable page with no underlying media." The cleanest fit is a **fourth `JuryDisplay` case** and a **reserved synthetic `exhibitId`** so the entire existing annotation pipeline (store, layers, version bumps, debounced save, gesture surface, color picker, undo/clear) is reused with **zero changes to the annotation system**.

```swift
enum JuryDisplay: Equatable {
    case empty
    case blank
    case exhibit(Exhibit, page: Int, annotationsVersion: Int)
    case whiteboard(annotationsVersion: Int)   // NEW
}
```

- Reserved id: `AnnotationStore.whiteboardExhibitId = "__whiteboard__"`, page `0`. Because the store keys purely by `String`, the whiteboard is just "an exhibit that happens to have no file."
- The freehand single-drawing rule already in `AnnotationStore.add` is exactly what a whiteboard wants: one continuous PencilKit drawing on page 0, plus optional highlight/callout boxes layered on top. (A callout on a whiteboard has no PDF to rasterize, so the whiteboard intentionally exposes only **freehand + highlight + clear + color**; callout/redact are hidden on the whiteboard toolbar — see Feature 1 toolbar.)

### Rendering: a `WhiteboardCanvas` that wraps the existing annotation layers

The whiteboard background is a neutral board color (white in light, dark slate when the jury background is black) drawn *under* the annotation layer. We do **not** add a new drawing engine — we render `PageAnnotationLayer` / `PageAnnotationLayerJury` over a solid background.

- Presenter: `WhiteboardCanvas(isPresenter: true)` → `ZStack { board background; PageAnnotationLayer(exhibitId: whiteboardExhibitId, exhibitFileURL: nil, page: 0) }`, wrapped in `ViewportContainer`.
- Jury: `JuryView`'s `.whiteboard` case → same board background + `PageAnnotationLayerJury(exhibitId: whiteboardExhibitId, exhibitFileURL: nil, page: 0)`, wrapped in `ViewportContainer`.

Because the gesture surface, freehand canvas, and color picker are reused unchanged, drawing on the presenter mirrors to the jury through the existing `annotationsVersion` bump path. `CalloutBubble` is never instantiated on the whiteboard (callout tool hidden), so its `exhibitFileURL == nil` branch (already renders a gray placeholder) is never hit in practice.

### AppState surface (mirrors like everything else)

```swift
// AppState
static let whiteboardExhibitId = "__whiteboard__"

func showWhiteboard() {
    let v = annotationStore.pageVersion(exhibitId: Self.whiteboardExhibitId, page: 0)
    juryDisplay = .whiteboard(annotationsVersion: v)
    lastStatusBanner = nil
    juryViewport = .full
    // not persisted across relaunch in v1 (see Out of scope)
}

func clearWhiteboard() {
    annotationStore.clear(exhibitId: Self.whiteboardExhibitId, page: 0)
}
```

`handleAnnotationChange(for:)` must also bump the `.whiteboard` case (today it only re-publishes `.exhibit`). Add a branch so whiteboard strokes propagate to the jury:

```swift
private func handleAnnotationChange(for exhibitId: String) {
    if case let .exhibit(published, page, _) = juryDisplay, published.id == exhibitId {
        let v = annotationStore.pageVersion(exhibitId: exhibitId, page: page)
        juryDisplay = .exhibit(published, page: page, annotationsVersion: v)
    } else if case .whiteboard = juryDisplay, exhibitId == Self.whiteboardExhibitId {
        let v = annotationStore.pageVersion(exhibitId: exhibitId, page: 0)
        juryDisplay = .whiteboard(annotationsVersion: v)
    }
    scheduleSave(exhibitId: exhibitId)
}
```

> `scheduleSave` will write a `__whiteboard__.json` annotation sidecar into `Trial/Annotations/`. That is harmless (it's just another annotation doc) and is how the whiteboard could be persisted later; for v1 we do not reload it on launch.

### Entry point & toolbar

- A **"Whiteboard"** button in `PresenterToolbar` (id `toolbar.whiteboard`) calls `state.showWhiteboard()` and selects the whiteboard as the presenter's working surface. Presenter shows the whiteboard via a small `@State var showingWhiteboard` in `PresenterScene` (or by treating `.whiteboard` juryDisplay as the cue — but the presenter must be able to draw even before publishing, so a presenter-local flag is cleaner). **Decision:** presenter-local `whiteboardActive` flag in `PresenterScene` that swaps `PreviewPane` for `WhiteboardCanvas`; a "Show to Jury / Hide" control publishes `.whiteboard` / `.blank`. This matches how exhibits are previewed before publishing.
- A whiteboard-specific toolbar `WhiteboardToolbar` (a thin wrapper over the existing controls): freehand/highlight tool buttons, the existing `colorPicker`, Undo, Clear (whiteboard), Save to PDF. It reuses `AnnotationToolbar`'s building blocks but hides callout/redact. Accessibility ids: `whiteboard.tool.freehand`, `whiteboard.tool.highlight`, `whiteboard.undo`, `whiteboard.clear`, `whiteboard.export`, `whiteboard.showJury`, `whiteboard.hideJury`.

### Save-to-PDF (optional, in scope as a small step)

Reuse `AnnotationFlattener.flatten(image:annotations:outputURL:)`. Render the board background to a `CGImage` at a fixed canvas size (e.g. 1600×1200, 4:3 like a flip chart), then flatten the whiteboard's annotations over it to `Trial/Annotated/Whiteboard-<timestamp>.pdf`. No new flattener code — only a tiny helper to produce the blank base `CGImage`.

### Error handling

- No file to resolve → no failure modes around missing media; the whiteboard cannot 404.
- If the user publishes the whiteboard then opens an exhibit, `select`/`publishSelected` simply move `juryDisplay` off `.whiteboard`; the drawing persists in the store keyed by `__whiteboard__` and reappears if the whiteboard is shown again in the same session.
- Clear uses the same `ClearPageConfirm` confirmation sheet pattern (respect `settings.confirmationPromptsEnabled`).

---

# Feature 2 — Multiple Simultaneous Callouts

### Finding: the model and rendering already support N callouts

- `AnnotationStore` stores a `[Annotation]` per page; nothing dedupes or limits callouts. `add` only special-cases freehand.
- `PageAnnotationLayer` and `PageAnnotationLayerJury` both `ForEach` over the list and instantiate one `CalloutBubble` per `.callout` annotation. `CalloutBubble` is a pure function of one annotation. **Placing a second callout already works and already mirrors to the jury today.**
- `CalloutGestureModifier` is a two-stage drag (pick source region → pick destination bounds) that calls `onCommit` and resets to `.awaitingSource`, so the attorney can immediately place another. No state prevents a second callout.

**Therefore Feature 2 is not "add multiple callouts" — that exists — it is "make multiple callouts manageable and legible."** The real gaps:

1. **No per-callout delete.** Today the only removals are `undo` (last annotation on the page, any tool) and `clear` (whole page). With several callouts plus highlights, the attorney cannot remove *one specific* callout.
2. **No selection / z-order / reposition.** Overlapping callouts stack in insertion order with no way to nudge or bring-to-front. Acceptable for v1 if delete exists, but reposition materially improves "two tear-outs side by side."
3. **Legibility:** overlapping bubbles need a subtle drop shadow / border contrast so coincident tear-outs read as distinct cards. (Border already exists; add a shadow.)

### Design

**A. Per-callout delete (core, in scope).**
- Add `AnnotationStore.remove(id:exhibitId:page:)`:
  ```swift
  func remove(id: UUID, exhibitId: String, page: Int) {
      guard var doc = documents[exhibitId] else { return }
      let key = String(page)
      guard var list = doc.pages[key] else { return }
      list.removeAll { $0.id == id }
      doc.pages[key] = list
      doc.lastModified = ISO8601DateFormatter().string(from: Date())
      documents[exhibitId] = doc
      bumpVersion(exhibitId: exhibitId, page: page)
      onChange?(exhibitId)
  }
  ```
- On the **presenter** layer, each `CalloutBubble` gets a small delete affordance (an "xmark.circle.fill" badge at the bubble's top-trailing corner) shown only when no drawing tool is active (`state.currentTool == nil`), so the badge does not fight the callout-placement gesture. The badge calls `state.annotationStore.remove(id:exhibitId:page:)`. The jury layer never shows the badge (read-only, `allowsHitTesting(false)`). Accessibility id: `annotation.callout.delete.<uuid>`.

**B. Optional reposition (in scope as a follow-on step; can be deferred).**
- Add `AnnotationStore.updateBounds(id:exhibitId:page:bounds:)` (same shape as `remove`, replaces `bounds`). On the presenter `CalloutBubble`, attach a `DragGesture` (active only when `currentTool == nil`) that updates a local `@GestureState` offset and commits the new normalized `bounds` on end. Jury mirrors via the version bump. This keeps `calloutSource` fixed (the magnified region) and only moves the tear-out card.

**C. Legibility.** Add `.shadow(radius: 4, y: 2)` to the bubble's rounded card and keep the colored stroke. No data change.

### State / mirroring

No new `AppState` or `JuryDisplay` surface. All changes are inside `AnnotationStore` (one new method, optionally two) and the two layer views. Mirroring is automatic: `remove`/`updateBounds` call `onChange` → `annotationsVersion` bump → jury re-renders. This is the lowest-risk feature of the three.

### Edge cases

- Deleting a callout while it is the only annotation: list becomes empty; version bumps; jury shows the bare page. Fine.
- A callout whose `calloutSource` region is off a re-cropped page: `CalloutBubble.rasterizedSource` already returns `nil` → gray placeholder. No crash.
- Z-order: insertion order is the paint order; "bring to front" = delete + re-add is out of scope for v1 (note it).

---

# Feature 3 — AirPlay Wireless Output

### The core technical finding

**iOS exposes a wireless AirPlay display to apps exactly like a wired HDMI/USB-C display — as a second `UIScreen` that drives a `UIWindowScene` with role `windowExternalDisplayNonInteractive`.** Iron Gavel already declares and handles that scene (`Info.plist` + `AppDelegate` + `JurySceneDelegate`). So when the courtroom TV is reached over AirPlay **as a separate display**, `JurySceneDelegate.scene(_:willConnectTo:…)` fires and hosts `JuryView` with no code change. `AppState.externalConnected` flips true. **The presenter→jury split works over AirPlay the same way it works over HDMI.**

The subtlety is **two distinct AirPlay modes**, and they behave very differently:

1. **AirPlay *Mirroring* (Control Center → Screen Mirroring).** This *clones* the iPad's primary screen to the TV. iOS does **not** create a second `UIWindowScene`; the external screen shows a scaled copy of the presenter UI. In this mode the jury would see the attorney's confidence monitor, sidebar, and tools — **the privileged/work-product view**. This is the dangerous default and must be detected and warned against.

2. **AirPlay as a *separate* display (the desired mode).** When an app vends content to a *secondary* screen (declares an external-display scene and renders distinct content to it), iOS treats the AirPlay receiver as an independent display and the app's external-display scene is used instead of mirroring. Because Iron Gavel already vends `JuryView` to the external scene, an AirPlay receiver selected as a *second screen* drives `JuryView`, not a clone. Historically this was AirPlay's automatic behavior when an app implemented external-display support; on modern iOS the reliable, user-legible way to get here is an **in-app route picker** targeting the screen route, rather than relying on Control Center mirroring.

### What must change / be added

Nothing structural — the scene plumbing is already correct. The work is **discoverability, a route picker, and a safety guard:**

**A. In-app AirPlay route picker (`AVRoutePickerView`).**
- Add a SwiftUI wrapper `AirPlayRoutePicker: UIViewRepresentable` around `AVRoutePickerView`, surfaced as a `toolbar.airplay` button in `PresenterToolbar`. Tapping it presents the system route chooser so the attorney can pick the courtroom Apple TV / AirPlay receiver without leaving the app or fishing in Control Center.
- `AVRoutePickerView` natively targets audio/video routes; for **screen** output the reliable lever is selecting the external display via the system picker and letting the declared external-display scene take over. We document the limitation (Apple does not offer a public "pick a *screen* route" control as clean as the audio picker) and provide the picker plus clear on-screen guidance: "Connect: Control Center → Screen Mirroring → <Apple TV>. Iron Gavel will show the jury view on the courtroom display automatically."

**B. Mirroring-vs-separate-display detection + guard (the important safety feature).**
- On `externalConnected == true`, inspect `UIScreen.screens`. We can distinguish "we are driving a separate jury scene" (our `JurySceneDelegate` connected → `externalConnected` set in `willConnectTo`) from "the OS is mirroring our primary screen" (an external `UIScreen` exists but **no** external-display scene connected — i.e. a second screen appeared yet `JurySceneDelegate.scene(willConnectTo:)` never fired).
- Concretely: track both signals in `AppState`:
  - `externalConnected` (already set by `JurySceneDelegate`) = "jury scene is live."
  - A new `screenCount` updated from `UIScreen.didConnectNotification` / `didDisconnectNotification` (count of `UIScreen.screens`).
  - If `screenCount > 1` **and** `externalConnected == false`, the external screen is a **mirror** of the presenter UI → show a prominent red banner on the presenter: "Screen Mirroring is showing your private notes to the courtroom. Use Screen Mirroring as a *second display*, not a mirror." (id `airplay.mirroringWarning`). This reuses the existing `lastStatusBanner` channel or a dedicated `airplayWarning` flag.
- This guard is genuinely useful for HDMI dongles too (a misconfigured "mirror displays" setting), so it is not AirPlay-specific in implementation.

**C. Info.plist / entitlements findings.**
- **No new Info.plist keys are required for AirPlay screen output.** The existing `UIApplicationSceneManifest` external-display configuration is sufficient; AirPlay screens arrive through the same scene role.
- If we later add AirPlay **audio/video route** streaming of an actual media item (not screen output) we would set `AVAudioSession` category `.playback` with `.allowAirPlay` — but for *screen* mirroring of `JuryView` that is **not** needed. Document this distinction so a future engineer doesn't add unnecessary audio-session config.
- Note for the video exhibit path: `VideoController` wraps a shared `AVPlayer`; when the jury scene is on an AirPlay screen, the `AVPlayerLayer` in `VideoJuryView` renders on that screen like any other layer — no `allowsExternalPlayback` change needed (that property is for *handoff* AirPlay video, which we explicitly do NOT want, because it would yank the video out of our controlled jury layout). **Decision: keep `player.allowsExternalPlayback = false`** (default) and add a test/assertion documenting why.

### State / mirroring surface

```swift
// AppState additions
var screenCount: Int = 1
var airPlayMirroringSuspected: Bool { screenCount > 1 && !externalConnected }
```

`PresenterScene` observes `UIScreen.didConnect/didDisconnectNotification` (or a small `ScreenMonitor` helper) to keep `screenCount` current and renders the warning banner when `airPlayMirroringSuspected`.

### Why this is low-risk

The jury rendering path is untouched; AirPlay reuses the identical external-display scene. The only new runtime behavior is a route-picker button and a mirroring warning. The biggest risk is **UX/documentation** (teaching the attorney to use "second display," not "mirror") rather than code.

---

## Testing strategy

Baseline: 124 tests passing; keep green. Tests live in `IronGavelTests` (XCTest) and `IronGavelUITests` (XCUITest); UI fixture via `--ui-test-fixture`, fresh launch via `--ui-test-reset`.

**Feature 1 — Whiteboard (unit + UI):**
- `JuryDisplay` equatability for `.whiteboard(annotationsVersion:)`.
- `AppState.showWhiteboard()` sets `juryDisplay == .whiteboard(...)`, resets viewport to `.full`, clears banner.
- `AppState` whiteboard stroke path: add a freehand annotation under `__whiteboard__`/page 0 while `.whiteboard` is published → `juryDisplay`'s `annotationsVersion` increments (mirroring proof), parallel to the existing exhibit test.
- `clearWhiteboard()` empties the page and bumps version.
- Whiteboard save-to-PDF: flatten over a blank base image produces a non-empty PDF at the expected path (mirror the existing flattener tests).
- UI smoke: tap `toolbar.whiteboard` → `whiteboard.tool.freehand` and `whiteboard.clear` exist; tap `whiteboard.showJury` → (fixture jury assertion if available).

**Feature 2 — Multiple callouts (unit + UI):**
- `AnnotationStore.remove(id:…)` removes the targeted annotation only, leaves siblings, bumps version, fires `onChange`.
- Adding two `.callout` annotations to one page yields a 2-element list (guards against any accidental dedupe regression).
- `updateBounds(id:…)` (if implemented) replaces only `bounds`, preserves `calloutSource`.
- UI smoke: with the fixture PDF exhibit, place two callouts (drive `CalloutGestureModifier` twice) and assert two `annotation.callout.*` elements; tap one `annotation.callout.delete.*` → one remains.

**Feature 3 — AirPlay (unit only; route/mirroring need hardware):**
- `AppState.airPlayMirroringSuspected` truth table: `(screenCount:1, externalConnected:false) → false`; `(2, true) → false`; `(2, false) → true`.
- `player.allowsExternalPlayback == false` invariant test on `VideoController` (documents the intentional choice).
- The route picker and real mirroring warning are covered by a manual checklist entry (`docs/manual-checklists/`), since AirPlay requires a physical receiver.

---

## Scope / phasing

**Phase 1 (lowest risk, highest "wow"-per-line): Multiple callouts** — `remove` + per-callout delete badge + bubble shadow. No `AppState`/`JuryDisplay` change. ~1 store method + 2 view edits + tests.

**Phase 2: Whiteboard** — `.whiteboard` JuryDisplay case, `AppState` methods, `WhiteboardCanvas`, `WhiteboardToolbar`, `JuryView` branch, `PresenterScene`/`PresenterToolbar` entry, save-to-PDF. Touches the most shared files but reuses the annotation engine wholesale.

**Phase 3: AirPlay** — `AirPlayRoutePicker`, `ScreenMonitor`, `AppState.screenCount`/`airPlayMirroringSuspected`, presenter warning banner, `toolbar.airplay` button, manual checklist. No jury-render changes.

Optional follow-ons (Phase 2b): callout reposition (`updateBounds` + drag); whiteboard persistence across relaunch (reload `__whiteboard__.json`).

---

## Out of scope (deferred)

- Whiteboard **multi-page** / multiple boards (v1 is one board, page 0). Multiple boards would key by `__whiteboard__-N`.
- Whiteboard **shapes/text/stamps** (straight-line snap, arrows, typed labels). v1 is freehand + highlight only.
- Whiteboard **persistence/restore** across app relaunch and `PublishStateStore` integration.
- Callout **bring-to-front / explicit z-order UI** and callout **resize** (v1 supports delete; reposition is optional).
- AirPlay **handoff video** (`AVPlayer.allowsExternalPlayback = true`) — explicitly rejected to keep video inside the controlled jury layout.
- A bespoke "pick a *screen* route" control beyond `AVRoutePickerView` + guidance (Apple provides no clean public API for it).

---

## Shared-file edits (flag for orchestrator)

| File | Feature | Change |
|---|---|---|
| `IronGavel/State/JuryDisplay.swift` | Whiteboard | **Add** `.whiteboard(annotationsVersion:)` case. Forces `switch` exhaustiveness updates in `JuryView` and `AppState.persistPublishState` (add a `.whiteboard` branch → no-op or clear). |
| `IronGavel/State/AppState.swift` | Whiteboard, AirPlay | Whiteboard: `whiteboardExhibitId`, `showWhiteboard()`, `clearWhiteboard()`, `handleAnnotationChange` branch, `persistPublishState` `.whiteboard` branch. AirPlay: `screenCount`, `airPlayMirroringSuspected`. |
| `IronGavel/Jury/JuryView.swift` | Whiteboard | Add `.whiteboard` case → board background + `PageAnnotationLayerJury(__whiteboard__, page 0)` in a `ViewportContainer`. |
| `IronGavel/Presenter/PresenterScene.swift` | Whiteboard, AirPlay | Whiteboard preview swap + show/hide-to-jury controls. AirPlay screen-monitor wiring + warning banner. |
| `IronGavel/Presenter/PresenterToolbar.swift` | Whiteboard, AirPlay | Add `toolbar.whiteboard` and `toolbar.airplay` buttons + callbacks. |
| `IronGavel/Annotation/AnnotationStore.swift` | Callouts | Add `remove(id:exhibitId:page:)` (and optional `updateBounds`). Pure addition; no existing behavior changes. |
| `IronGavel/Annotation/Views/PageAnnotationLayer.swift` | Callouts | Per-callout delete badge on presenter (guarded by `currentTool == nil`). |
| `IronGavel/Annotation/Views/CalloutBubble.swift` | Callouts | Add shadow; optional drag-to-reposition; optional delete-badge overlay (or keep badge in the layer). |
| `IronGavel/Resources/Info.plist` | AirPlay | **No change required** (documented finding). Listed so reviewers know it was evaluated. |

`PresenterToolbar`'s initializer arity changes (new callbacks) — every construction site (`PresenterScene`) and any UI test that constructs it must be updated; existing UI tests find buttons by id, so only the call site changes.
