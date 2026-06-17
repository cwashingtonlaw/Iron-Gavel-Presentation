# Iron Gavel — Tier 2 Organization & Speed (Design)

**Goal:** Give the trial attorney three TrialPad-style organization/speed tools, all presenter-side, layered on the existing self-contained-case engine without touching the presentation/mirroring core:

1. **Hot Docs / Key Flags** — star an exhibit so it is one tap away mid-testimony; a "Key" section/filter in the sidebar.
2. **Folders / Groups within a case** — organize exhibits into named folders (by witness/topic) and render them as collapsible groups in the sidebar.
3. **Search within documents** — full-text search across exhibit PDFs (PDFKit `PDFDocument.findString`), list matching exhibits + pages, and jump straight to a hit's page.

**Guiding principle (verified against the code):** these are **presenter organization/navigation features only**. None of them change what is *published* to the jury. `JuryDisplay`, `JuryViewport`, `ViewportContainer`, `JuryView`, the publish gate (`status == .admitted`), and all mirroring stay **untouched**. This is the single biggest risk-reducer and is a hard scope boundary.

**Reference architecture (read):** `@MainActor @Observable AppState` is the single source of truth; the app owns `exhibits.json` and writes every mutation through `CaseManifestWriter` (atomic temp+rename), then calls `state.apply(case:folder:)` to refresh. The sidebar (`ExhibitSidebar`) is a `List` grouped by `Party`, filtered by the pure `ExhibitFilter`, with `.searchable`. PDFs are vended by `PDFDocumentCache.shared.document(for:)`.

---

## Persistence decisions

The app already owns `exhibits.json` and round-trips a `Case` through `CaseManifestWriter` → `CaseLoader`. Both Key and Folder are **per-exhibit attributes**, so the cleanest, lowest-risk persistence is **two new optional fields on `Exhibit`**, written by the existing manifest writer. No new write path, no second file to keep in sync, no migration script.

### Exhibit model — additive fields (SHARED-FILE EDIT)

`IronGavel/Model/Exhibit.swift` gains:

```swift
let isKey: Bool          // default false — "Hot Doc" star
let folder: String?      // default nil   — folder/group name, nil = "Unfiled"
```

with CodingKeys `is_key` and `folder`, and **defaulted decoding** so existing/external `exhibits.json` (which omit both) still decode. Critically:

- The memberwise `init` adds `isKey: Bool = false` and `folder: String? = nil` **with defaults at the end**, so the ~15 existing call sites (ExhibitImporter, ExhibitEditorSheet, PreviewPane.persist, every test helper) compile unchanged.
- `Decodable` uses `decodeIfPresent` for both, defaulting `isKey` to `false` and `folder` to `nil`. This keeps `dw-exhibit-manager`-authored manifests (no `is_key`/`folder` keys) loading exactly as before — **back-compatible**.
- `Encodable` always emits both keys (the writer uses `.sortedKeys`/`.prettyPrinted` already). Round-trip equality (`Hashable`/`Equatable` is synthesized) holds.

**Why not a sidecar?** A `keys.json` / `folders.json` sidecar would need its own writer, loader, live-reload hook in `CaseWatcher`, and reconciliation when exhibits are deleted/renamed. The manifest already carries per-exhibit metadata (witness, bates, exhibitNumber, status); Key and Folder belong with them. Interop is preserved because the fields are optional.

### Folder names

Folders are **just strings stored on exhibits** — there is no separate "folder entity," no ordering table, no nesting. "Unfiled" is the synthetic bucket for `folder == nil`. This means:
- Creating a folder = typing a name in the editor (or a "move to…" menu) and saving.
- Renaming a folder later (Phase 2) = a bulk update of all exhibits with that `folder` value.
- An empty folder simply ceases to exist (nothing references the name). Acceptable for v1.

### Search index

Search is **computed on demand, not persisted.** `PDFDocument.findString(_:withOptions:)` runs against the cached documents at query time. No index file. (A persisted index is out of scope; see phasing.)

---

## Components

### Feature 1 — Hot Docs / Key Flags

1. **`Exhibit.isKey`** (model field, above).

2. **`ExhibitMutator`** (`IronGavel/Library/ExhibitMutator.swift`) — a small pure helper that, given a `Case` + an exhibit `id` + a transform, returns an updated `Case`. Used by toggle-key, set-folder, and (later) bulk ops so the persist logic lives in one tested place instead of being re-derived in each view. Signature:
   ```swift
   enum ExhibitMutator {
       static func replacing(_ id: String, in kase: Case, with transform: (Exhibit) -> Exhibit) -> Case
       static func toggleKey(_ id: String, in kase: Case) -> Case
       static func setFolder(_ folder: String?, for id: String, in kase: Case) -> Case
   }
   ```
   Pure, fully testable, no I/O.

3. **`CaseController`** (`IronGavel/Presenter/CaseController.swift`) — a `@MainActor` struct that wraps "mutate `Case` → `CaseManifestWriter.write` → `state.apply` → re-select". Today this persist-and-reload dance is duplicated inline in `PreviewPane.persist`. We extract it so Key/Folder toggles, the editor, and import all share one path. (Refactor of existing inline logic; `PreviewPane` is updated to call it. SHARED-FILE EDIT, additive.)

4. **Key toggle UI** — a star button in the `PreviewPane` header (`exhibit.key`) and a swipe action / context-menu "Mark Key" in the sidebar row. Toggling calls `CaseController.toggleKey`.

5. **Sidebar "Key" section** — when any exhibit `isKey`, the sidebar shows a pinned top **★ Key** section listing keyed exhibits (across parties), above the party groups. A star glyph appears on keyed rows everywhere. (SHARED-FILE EDIT: `ExhibitSidebar`.)

### Feature 2 — Folders / Groups

1. **`Exhibit.folder`** (model field, above).

2. **`ExhibitGrouping`** (`IronGavel/Presenter/ExhibitGrouping.swift`) — a pure helper turning `[Exhibit]` + a `SidebarGrouping` mode into ordered sections. Two modes:
   - `.party` (today's behavior — group by `Party.allCases`),
   - `.folder` (group by `folder`, with "Unfiled" last; folder order alphabetical).
   Returns `[(title: String, exhibits: [Exhibit])]`. Fully testable; keeps `ExhibitSidebar` thin.

3. **Grouping toggle** — a segmented control / menu in the sidebar (`sidebar.grouping`) choosing Party vs Folder. Stored in `@State` on the sidebar (ephemeral; not persisted in v1 — a per-case default is Phase 2).

4. **Folder assignment UI** — the `ExhibitEditorSheet` gains a "Folder" picker/field (`editor.folder`): pick an existing folder name or type a new one. Saving routes through `CaseController` (the editor already round-trips the full exhibit; we add the field to its `updated()`).

5. **Sidebar folder rendering** — in `.folder` mode, `ExhibitSidebar` renders one `Section` per folder using `ExhibitGrouping`. Search (`ExhibitFilter`) still applies within each section. Collapsibility uses SwiftUI `DisclosureGroup`-free `Section` headers (the existing `.sidebar` list already collapses sections); v1 keeps plain sections to match current behavior.

### Feature 3 — Search within documents

1. **`DocumentSearch`** (`IronGavel/Library/DocumentSearch.swift`) — the search engine. Pure-ish (takes a `PDFDocument` provider so it is testable with a fixture PDF). API:
   ```swift
   struct DocumentSearchHit: Hashable, Identifiable {
       let id = UUID()
       let exhibitId: String
       let exhibitDescription: String
       let page: Int            // 0-based, ready for state.setPage / page binding
       let snippet: String      // surrounding text for context
   }

   struct DocumentSearch {
       /// Searches the PDF exhibits of a case for `query`, returning hits grouped by exhibit+page.
       /// `documentProvider` lets tests inject fixtures; production passes PDFDocumentCache.shared.document.
       func search(query: String,
                   in exhibits: [Exhibit],
                   caseFolder: URL,
                   documentProvider: (URL) -> PDFDocument?) -> [DocumentSearchHit]
   }
   ```
   Implementation uses `PDFDocument.findString(query, withOptions: [.caseInsensitive])`, maps each `PDFSelection` to its page index via `document.index(for:)`, dedupes to one hit per (exhibit, page) (keeping the first snippet), and extracts a short snippet from the selection's `string` extended to the line. Only `mediaType == .pdf` exhibits are searched (images/video/audio have no text layer). Empty/short queries (< 2 chars) return `[]`.

2. **Async wrapper** — `findString` can be slow on large PDFs, and the cache + `PDFDocument` are not guaranteed main-thread-only for reads but we keep it simple and **off the main actor**: the search view calls `DocumentSearch().search(...)` inside a `Task.detached`/`await` and publishes results back on the main actor. A `searchToken`/`Task` is cancelled when the query changes (debounced ~300ms) so typing doesn't pile up work.

3. **`DocumentSearchView`** (`IronGavel/Presenter/DocumentSearchView.swift`) — a sheet presented from a toolbar magnifier button (`toolbar.docSearch`, disabled when `currentCase == nil`). A search field (`docsearch.field`) at top; a results list grouped by exhibit, each row showing the page number + snippet (`docsearch.hit.<exhibitId>.<page>`). Tapping a hit:
   - selects that exhibit (`state.select`),
   - sets the preview page to the hit page,
   - dismisses the sheet.
   The "set the page" step reuses the existing `PreviewPane` page flow: selecting the exhibit resets `page` to 0 via `onChange`, so we publish the target page through a new lightweight `AppState.requestedPreviewPage: Int?` that `PreviewPane` consumes on appear/selection-change and then clears. (Minimal AppState addition — see State changes.)

---

## State changes (AppState) — minimal, additive

`AppState` gains **one** small piece of presenter-only navigation state for search-jump:

```swift
var requestedPreviewPage: Int?   // set by DocumentSearchView; consumed+cleared by PreviewPane
```

This is **not** mirrored to the jury and does not touch `juryDisplay`. `PreviewPane` reads it after it applies a new selection: if set and the selected exhibit matches the search target, it sets `page` to that value and clears `requestedPreviewPage`. No change to `JuryDisplay`, `publishSelected`, `setPage`'s contract (the existing `page → state.setPage` mirror still fires only when that exhibit is already published).

Key/Folder need **no** AppState additions — they live entirely in `currentCase` (the persisted `Case`), already observable.

---

## Data flow

```
User toggles Key / sets Folder
  → CaseController.apply(ExhibitMutator.toggleKey/​setFolder(...))
  → CaseManifestWriter.write(updatedCase, to: folder)     // atomic
  → state.apply(case: updatedCase, folder: folder)        // re-renders sidebar/preview
  → re-select the same exhibit (CaseController keeps selection stable)

User runs doc search
  → DocumentSearchView debounces → Task { DocumentSearch().search(...) }
  → results published on MainActor → list
  → tap hit → state.select(exhibit); state.requestedPreviewPage = hit.page; dismiss
  → PreviewPane consumes requestedPreviewPage → page = hit.page (presenter only)
```

The publish gate is unchanged: a keyed/foldered exhibit still only publishes if `status == .admitted`. `CaseWatcher` live-reload still works (it reloads the whole `Case`, which now includes `is_key`/`folder`).

---

## Error handling

- **Search on a corrupt/missing PDF:** `documentProvider` returns `nil` → that exhibit is skipped, no crash, search continues.
- **Search query too short / empty:** returns `[]`; the view shows "Type at least 2 characters."
- **No hits:** the view shows "No matches in admitted/marked exhibits."
- **Folder name collisions / whitespace:** folder names are trimmed; empty → `nil` ("Unfiled"). Two exhibits may share a folder name (that's the point).
- **Toggle/persist write failure:** `CaseController` surfaces the existing `loadError`-style toast path; the in-memory `Case` is only applied after a successful write (write-then-apply ordering), so a failed write leaves UI and disk consistent.
- **Key flag on a deleted exhibit:** deletion already rewrites the manifest without that exhibit; its key flag vanishes with it. No dangling state (a benefit of storing on the exhibit, not a sidecar).

---

## Testing strategy

Pure/unit (XCTest, in `IronGavelTests/`):

- **`ExhibitCodableKeyFolderTests`** — decode a manifest *without* `is_key`/`folder` → `isKey == false`, `folder == nil` (back-compat); encode→decode round-trip with both set; full-`Case` round-trip through `CaseManifestWriter` + `CaseLoader`.
- **`ExhibitMutatorTests`** — `toggleKey` flips only the target; `setFolder` sets/clears only the target; non-existent id is a no-op; other exhibits untouched.
- **`ExhibitGroupingTests`** — `.party` reproduces today's order; `.folder` groups correctly, "Unfiled" bucket last, alphabetical folder order, search-filtered input respected.
- **`DocumentSearchTests`** — build a 2-page PDF fixture in a temp dir (via `PDFDocument`/`UIGraphicsPDFRenderer`, mirroring `AnnotationFlattenerTests`/`VideoFrameFlattenTests` patterns), assert: a term on page 2 yields a hit with `page == 1`; case-insensitive; non-PDF exhibits skipped; missing file skipped; one hit per (exhibit,page); short query → `[]`.

UI smoke (XCUITest, reusing `--ui-test-fixture`):

- **`KeyFlagUITest`** — fixture has admitted PDFs; tap a row's "Mark Key" → a **★ Key** section appears with that exhibit (`sidebar.section.key`).
- **`FolderGroupingUITest`** — switch `sidebar.grouping` to Folder → sections render; open editor, set a folder, save → exhibit appears under that folder section.
- **`DocSearchUITest`** — tap `toolbar.docSearch`, type a term present in a fixture PDF, tap the first `docsearch.hit.*`, assert the preview shows that exhibit selected. (Requires the UI-test fixture to point at a real bundled PDF with known text — see Open question below.)

All **existing tests stay green** (baseline 124). The additive defaulted init + defaulted decode is specifically chosen so no existing test's `Exhibit(...)` call or fixture changes.

---

## Scope / phasing

**Phase 1 (this build):**
- `Exhibit.isKey` + `Exhibit.folder` (defaulted, back-compat).
- `ExhibitMutator`, `CaseController` (extract existing persist logic), `ExhibitGrouping`.
- Sidebar: ★ Key section + Party/Folder grouping toggle + key glyph on rows + swipe "Mark Key".
- Editor: Folder field; PreviewPane header: Key star.
- `DocumentSearch` engine + `DocumentSearchView` sheet + toolbar magnifier + `requestedPreviewPage` jump.
- Tests above.

**Phase 2 (later):**
- Persist grouping mode + collapsed/expanded state per case.
- Rename/delete folder (bulk re-tag), reorder folders, drag-to-folder in the sidebar.
- Search: persisted index for large cases; search hit highlighting in the preview; search across image OCR; "search just this exhibit."
- Key-exhibit quick bar across the top of the presenter for one-tap recall during testimony.

## Out of scope

- Any change to jury mirroring, `JuryDisplay`, `JuryViewport`, the publish gate, annotation, video/audio engines.
- Nested folders / multi-folder membership (a folder is a single optional string in v1).
- OCR of image exhibits; search inside video/audio transcripts.
- Cross-case search.

## Open questions / flags for the orchestrator

- **DocSearch UI test needs a text-bearing PDF in the bundle.** The current `ui-test-exhibits.json` points at paths like `Exhibits_Admitted/d001-intersection.pdf` that aren't bundled with real text. The plan adds a tiny bundled fixture PDF (`docsearch-fixture.pdf`) + a fixture exhibit so the UI test has a known string to find; if the orchestrator prefers, downgrade DocSearch to unit-only and skip the UI smoke.
- **`exhibits.schema.json` MUST be updated (SHARED-FILE EDIT).** The repo-root `exhibits.schema.json` declares `"additionalProperties": false` on each exhibit. The app writing `is_key`/`folder` would make app-authored manifests **fail external schema validation** unless the schema adds both optional properties. The plan adds `is_key` (boolean) and `folder` (string) to the schema's exhibit `properties`. The Swift loader does not validate against the schema, so loading is unaffected either way, but keeping the schema honest is required for `dw-exhibit-manager` interop and round-tripping.
- **Shared-file edits** (call out when building): `Exhibit.swift` (new fields + init + Codable), `exhibits.schema.json` (new optional properties), `ExhibitSidebar.swift` (sections + grouping toggle), `ExhibitEditorSheet.swift` (folder field), `PreviewPane.swift` (key star + CaseController refactor), `PresenterToolbar.swift` (doc-search button), `PresenterScene.swift` (search sheet), `AppState.swift` (`requestedPreviewPage`).
