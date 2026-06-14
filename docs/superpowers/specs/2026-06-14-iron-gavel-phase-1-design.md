# Iron Gavel — Phase 1 Design

**Date:** 2026-06-14
**Status:** Approved for planning
**Scope:** Phase 1 (MVP) only. Later phases add annotation, video, polish features, and integrations.
**Target product:** A native iPad trial-presentation app that mirrors LIT SOFTWARE TrialPad's core workflow for Daniels & Washington trials.

---

## Goal

Ship the smallest version of Iron Gavel that an attorney can carry into a courtroom and use productively:

- Open a case from iCloud Drive.
- Browse exhibits read from the `exhibits.json` sidecar emitted by the `dw-exhibit-manager-crim` skill.
- Preview PDFs and images on the iPad (presenter view).
- Publish admitted exhibits to a USB-C-attached external display (jury view).
- Toggle Blank Screen.
- Navigate PDF pages (presenter and jury stay in sync when published).

Out of scope for Phase 1: annotation, callouts, redaction, video, whiteboard, laser pointer, side-by-side comparison, document search, hot-seat queue, transcript integration, AI search.

## Constraints

- **Platform:** iPadOS 17+, Swift / SwiftUI.
- **Distribution:** Personal-team dev signing, installed from Xcode over USB-C. No App Store, no TestFlight in Phase 1.
- **Display:** Presenter on iPad; jury on a TV/projector connected via USB-C → HDMI. No AirPlay path in Phase 1.
- **Source of truth:** `<CASE_ROOT>/Trial/exhibits.json`, contract v1.0 (see `exhibits.schema.json`). The app is read-only. Case truth lives in `Case Tables.xlsx`; the skill regenerates the sidecar.
- **Publish gating:** Only exhibits with `status: "admitted"` may be sent to the jury display. Enforced at button-press AND at runtime when the sidecar is re-emitted.

## Decisions locked

| Decision | Choice |
|---|---|
| Platform | iPad-native, SwiftUI |
| Architecture | Single SwiftUI `App` with two `WindowGroup` scenes (presenter + external jury) |
| State | One `@Observable AppState`, environment-injected |
| Rendering | `PDFKit.PDFView` (PDF), `Image` (raster) via `UIViewRepresentable` / SwiftUI |
| Distribution | Personal dev signing, sideload from Xcode |
| Jury display | External `UIScreen` via USB-C → HDMI; non-interactive `UIWindowScene` |
| File access | `UIDocumentPickerViewController` (folder pick) → security-scoped bookmark in `UserDefaults` |
| Sidecar contract | Frozen v1.0; mismatch is a hard refusal |
| Publish gate | Only `status: "admitted"`; runtime-enforced |
| Persistence (Phase 1) | None beyond bookmark; viewer is read-only |

## Architecture

Single SwiftUI `App`. Two `WindowGroup` scenes:

- **Presenter scene** — primary, always on iPad. Sidebar (exhibits grouped by Party) + preview pane + toolbar (Open Case, Publish, Blank, external indicator).
- **Jury scene** — secondary, activated only when an external `UIScreen` connects. Configured via `UIApplicationSceneManifest` with role `windowExternalDisplayNonInteractive`. Rendered purely as a function of `AppState.juryDisplay`.

A single `@Observable AppState` (Swift 5.9 macro) is environment-injected and shared between scenes. Presenter writes; jury reads. There is no separate "send to jury" event bus — the jury view is a function of state.

Persistence in Phase 1 is limited to:
- Security-scoped folder bookmark (Data, `UserDefaults`).
- Last-opened case path.

No CoreData, SwiftData, or annotation store. Phase 2 introduces persistence.

## Module boundaries

```
IronGavel/
  App/
    IronGavelApp.swift           // @main, WindowGroup × 2
    AppDelegate.swift            // UISceneConfiguration for external scene
    JurySceneDelegate.swift      // attaches JuryView to external UIWindowScene
  State/
    AppState.swift               // @Observable; currentCase, selectedExhibit,
                                 //   juryDisplay, lastPublished, externalConnected
    JuryDisplay.swift            // enum: .empty, .blank, .exhibit(Exhibit, page: Int)
  Model/
    Case.swift                   // Codable; mirrors exhibits.schema.json v1.0
    Exhibit.swift                // id, party, description, file, status, mediaType,
                                 //   witness, bates, objection, ruling, notes
    Party.swift                  // enum
    ExhibitStatus.swift          // enum
    MediaType.swift              // enum
    ContractVersion.swift        // static let supported = "1.0"
  Loader/
    CaseLoader.swift             // load(folderURL) -> Case; uses NSFileCoordinator
    CaseLoadError.swift          // missingSidecar, decodeFailed,
                                 //   unsupportedContractVersion, fileNotFound
    BookmarkStore.swift          // save/resolve security-scoped bookmark
    CaseWatcher.swift            // NSFilePresenter on exhibits.json -> AppState.reload()
  Presenter/
    PresenterScene.swift
    ExhibitSidebar.swift
    PreviewPane.swift
    PresenterToolbar.swift
    StatusBadge.swift
  Jury/
    JuryView.swift               // reads AppState.juryDisplay; no controls
    BlankView.swift
  Rendering/
    ExhibitRenderer.swift        // protocol
    PDFPreview.swift             // UIViewRepresentable<PDFView> + page controls
    PDFJuryView.swift            // UIViewRepresentable<PDFView>; no chrome
    ImagePreview.swift
    ImageJuryView.swift
    PDFDocumentCache.swift       // NSCache<URL, PDFDocument>
  Resources/
    Assets.xcassets
    Info.plist                   // UIApplicationSceneManifest entries
```

Each module has one job and an obvious interface. Tests target the boundaries.

## Data flow

### Launch and case load

1. App boots. `AppState` reads `lastCaseBookmark` from `UserDefaults`.
2. If present: resolve bookmark → `startAccessingSecurityScopedResource()` → kick `CaseLoader.load(folderURL)`. If absent or stale: show "Open Case" empty state with a button that triggers `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`.
3. `CaseLoader`:
   - `NSFileCoordinator` reads `<folder>/exhibits.json`.
   - Decodes to `Case` via `Codable`.
   - Validates `contract_version == "1.0"`. Mismatch → throw `CaseLoadError.unsupportedContractVersion`.
   - For each exhibit, resolves `exhibit.file` relative to the sidecar directory (frozen `path_base: "sidecar_dir"`).
   - Returns `Case` to `AppState.currentCase`.
4. Sidebar renders: exhibits grouped by Party (Defense / State / Joint / Court), rows show id, description, status badge, witness.

### Exhibit selection

1. User taps an exhibit row.
2. `AppState.selectedExhibit = exhibit`.
3. Preview pane renders via `ExhibitRenderer`. PDFs go through `PDFDocumentCache`.
4. Selection does **not** publish.

### Publish

1. User taps "Publish to Jury".
2. Guard: `exhibit.status == .admitted`. Otherwise the button is disabled with a "Not admitted" tooltip.
3. `AppState.juryDisplay = .exhibit(exhibit, page: currentPage)` and `lastPublished = (exhibit, currentPage)`.
4. Jury scene re-renders. No animation.

### Page navigation

1. Presenter PDF view exposes prev/next + a page-number field.
2. When the same exhibit is currently published, page changes propagate (state-driven).
3. When not published, page changes affect only the presenter preview.

### Blank Screen

1. Toolbar toggle.
2. `AppState.juryDisplay = .blank`. Jury view renders solid black.
3. Toggling off restores `lastPublished`.

### External display lifecycle

1. `UIScreen.didConnectNotification` → `JurySceneController` requests a new `UISceneSession` with role `.windowExternalDisplayNonInteractive`. `JuryView` renders.
2. `UIScreen.didDisconnectNotification` → scene tears down; `juryDisplay` is preserved.
3. Presenter toolbar always shows an "External: Connected / Not connected" indicator.

### File update mid-trial

1. Skill writes a new `exhibits.json` on the Mac. iCloud syncs the file.
2. `CaseWatcher` (`NSFilePresenter` on the sidecar) fires `presentedItemDidChange`.
3. `CaseLoader.reload()` runs off-main, produces a new `Case`.
4. If the currently-published exhibit's status changed away from `.admitted`, `AppState.juryDisplay = .blank` and a banner is shown: "Exhibit `<id>` status changed to `<new>`. Jury display blanked." Banner stays until dismissed.
5. Otherwise the sidebar updates silently.

## Error handling

| Condition | Behavior |
|---|---|
| Contract version mismatch | Full-screen error: "This case was generated with a newer Iron Gavel contract. Update the app." App refuses to load. No partial parse. |
| `exhibits.json` missing | Empty state with "Open a different folder" button. |
| JSON decode failure | Error sheet with decoder message + path. Existing `currentCase` (if any) is preserved. |
| Exhibit file missing on disk | Sidebar row dims, badge shows "File missing", row is unselectable. Other exhibits unaffected. |
| Stale security-scoped bookmark | Bookmark cleared; app returns to "Open Case" empty state. |
| External screen disconnects mid-trial | Indicator flips to "Not connected"; `juryDisplay` untouched. Reconnect resumes. |
| Status downgrade while published | Auto-blank + banner. |
| PDF render failure | Preview shows "Cannot render this PDF" + path. Publish disabled. Jury untouched. |
| iCloud file still downloading | Publish shows a spinner; triggers `startDownloadingUbiquitousItem`; 10s timeout → error toast. |

Boundary rule: validate at the JSON load boundary and at the external-screen boundary. Internal modules trust their inputs.

## Testing

### Unit tests (XCTest)

- `CaseLoaderTests` — load fixture; reject bad `contract_version`; reject malformed JSON; resolve `exhibit.file` relative to sidecar dir.
- `AppStateTests`:
  - Publish gate: publishing a non-admitted exhibit is a no-op.
  - Blank toggle preserves and restores last-published exhibit + page.
  - Auto-blank fires only when the *currently published* exhibit's status moves away from `.admitted`.
- `JuryDisplayTests` — enum equality and restore semantics.
- `BookmarkStoreTests` — round-trip bookmark through `UserDefaults`.

### UI test (XCUITest)

`PublishFlowUITest`: open fixture case → confirm sidebar populated → tap an admitted exhibit → tap Publish → assert "Live on Jury" → tap Blank → assert "Blanked".

### Manual trial-readiness checklist

Run before any courtroom use:

1. Plug Mac into project iPad via USB-C; connect external HDMI display.
2. Open fixture case from iCloud.
3. Walk every exhibit; confirm previews render.
4. Publish an admitted exhibit; confirm jury display.
5. Blank; confirm black on jury.
6. Disconnect HDMI mid-publish; reconnect; confirm restore.
7. On the Mac, re-run the skill's converter with a sample status change; confirm iPad picks it up within 60s and auto-blanks if needed.

### Out of scope (Phase 1 tests)

Performance benchmarks, large-PDF stress tests, multi-case session switching. Belong in Phase 2.

## Phase roadmap (context only)

| Phase | Scope |
|---|---|
| **1 — Viewer + Publish** (this spec) | Load case, browse, PDF/image view, publish, Blank, page nav |
| 2 — Annotation | Callouts, highlight, freehand (PencilKit), redact, annotation persistence |
| 3 — Video | Scrub, in/out clip designation, clip lists, jury playback (AVKit) |
| 4 — Polish | Whiteboard, laser pointer, side-by-side, document search, hot-seat queue |
| 5 — Sync extras | Transcript-linked playback (JusticeText/Rev), AI exhibit search |

Each phase gets its own spec → plan → implementation cycle.

## Open questions deferred to later phases

- Annotation persistence format (Phase 2 — likely `UIDocument` package alongside the sidecar).
- Video clip-list storage (Phase 3).
- Laser-pointer input model (Phase 4).
- Transcript timestamp interchange with `dw-transcript-pipeline-*` (Phase 5).
