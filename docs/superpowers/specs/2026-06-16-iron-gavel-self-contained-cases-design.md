# Iron Gavel — Self-Contained Cases (Design)

**Goal:** Make Iron Gavel a self-contained trial-presentation app (like TrialPad): open the app, create a case, import files, and they become exhibits you organize, edit, and present — **no externally-generated manifest required.** The firm's `dw-exhibit-manager` workflow keeps working as an optional import path.

**Approach (chosen):** Keep `exhibits.json` as the on-disk format, but the **app now writes and edits it** (previously read-only). Every existing feature — publish gate, annotation, video, audio, zoom, redaction, confidence monitor, record/export — runs on `exhibits.json` unchanged, so this adds a creation/editing surface without disturbing the presentation core, and preserves interop.

**Storage model (chosen):** On-device primary + iCloud backup.

---

## Storage layout

Cases live in the app's Documents directory (visible in Files under *On My iPad › Iron Gavel*):

```
Documents/Cases/<CaseName>/
  exhibits.json        # app-written manifest (existing schema, contract 1.0)
  Exhibits/            # imported source files, copied in
  Trial/               # existing outputs: Annotations/, Annotated/, exhibit-list.csv,
                       #   audit-log.jsonl, dispositions.json
```

This matches the existing loader's assumptions exactly: the **case folder is the root**, `exhibits.json` sits at its root, exhibit `file` paths are relative to it (`Exhibits/<name>`), and `Trial/` outputs are written beneath it. Fully offline to present.

**iCloud backup** (Phase B UI; the copy logic lands in Phase A as a tested helper): `CaseBackup` copies a case folder to/from the app's iCloud container (`iCloud Drive/Iron Gavel/Backups/<CaseName>/`). A deliberate snapshot, not live sync — so iCloud eviction can never break a case mid-trial.

---

## Components

1. **`CaseStore`** (`IronGavel/Library/CaseStore.swift`) — manages on-device cases under `Documents/Cases/`. `list()`, `create(name:)` (creates the folder + an empty `exhibits.json` + `Exhibits/`), `delete(name:)`, `rename(_:to:)`, `url(for:)`. Injectable root for tests. Pure file ops; testable.

2. **`MediaTypeDetector`** (`IronGavel/Library/MediaTypeDetector.swift`) — `detect(fileExtension:) -> MediaType`. pdf→`.pdf`; png/jpg/jpeg/heic/heif→`.image`; mov/mp4/m4v→`.video`; m4a/mp3/wav/caf/aac→`.audio`; else `.unknown`. Pure; testable.

3. **`ExhibitImporter`** (`IronGavel/Library/ExhibitImporter.swift`) — given source file URLs and a target case folder: copies each into `Exhibits/` (de-duping names), detects media type, and creates an `Exhibit` with an auto-assigned id (next available per party), `status = .pending`, party defaulting to `.defense`, description = filename stem. Appends to the case's `exhibits.json` via the writer. Returns the updated `Case`. Testable with temp files.

4. **`CaseManifestWriter`** (`IronGavel/Library/CaseManifestWriter.swift`) — encodes a `Case` to `exhibits.json` atomically (temp + rename, mirroring `AnnotationWriter`). The app's write path for all manifest mutations.

5. **`ExhibitIDAllocator`** (pure helper, in `ExhibitImporter` or standalone) — given existing exhibits + a party, returns the next id (`D-001`, `D-002`, …). Tested.

6. **Case Library UI** (`CaseLibraryView`) — the new launch surface, replacing the bare empty state: a list of cases with **New Case**, open (tap), rename, delete (swipe). Selecting a case loads it into the existing presenter.

7. **Import UI** — a "+ Import" button in the loaded case using SwiftUI `.fileImporter` (multi-select), security-scoped copy into the case. After import, the manifest reloads and the new exhibits appear in the sidebar.

8. **Exhibit editor** (`ExhibitEditorSheet`) — edit a selected exhibit's id, party, status, description, witness, Bates; delete; reorder within party. Writes back through `CaseManifestWriter`, then reloads the case. The **status field here is the in-app live-status control** the publish gate already honors.

9. **Loader robustness** — `CaseLoader` also checks `Trial/exhibits.json` when `exhibits.json` is absent at the selected folder root (fixes the "not found" confusion and keeps `dw-exhibit-manager`'s `Trial/`-nested layout working). Existing external-folder open is retained.

---

## Data flow

The app owns `exhibits.json`. Create / import / edit mutate it via `CaseManifestWriter`; the presenter consumes it via the existing `CaseLoader` (+ `CaseWatcher` live-reload). After any mutation the case is reloaded and `AppState.apply(case:folder:)` refreshes the UI — so edits appear immediately and the existing auto-blank-on-status-downgrade logic still fires when a published exhibit's status changes.

`AppState` gains nothing structural; it already holds `currentCase`/`caseFolderURL`. A thin `CaseController` (or PresenterScene methods) coordinates import/edit → write → reload.

---

## Error handling

- **Name collisions** (case or exhibit file): de-dupe by suffixing (` 2`, `-1`); surface a clear message on hard failures.
- **Import copy failure / unreadable source / unsupported type**: per-file error, continue with the rest; `.unknown` types import but show "Unsupported".
- **Empty/new case**: presents the import call-to-action instead of "Select an exhibit".
- **Missing exhibit file at present time**: existing "File missing" handling.

---

## Testing

Pure/file-level (XCTest):
- `CaseStore` create/list/rename/delete round-trip (temp root).
- `MediaTypeDetector` mapping for each extension class (+ case-insensitivity).
- `ExhibitIDAllocator` next-id per party (empty, gaps, mixed parties).
- `ExhibitImporter` import a temp file → file copied into `Exhibits/`, manifest updated, media type detected, id assigned.
- `CaseManifestWriter` round-trips through `CaseLoader` (write → load equals).
- `CaseLoader` auto-detect of `Trial/exhibits.json`.

UI smoke (XCUITest):
- Launch → Case Library visible → create a case → case opens → import call-to-action present → exhibit editor opens and saves.

All existing tests stay green.

---

## Scope / phasing

**Phase A (this build) — self-contained MVP:**
Case library (create/open/delete), import files → exhibits, exhibit editor (metadata + status + delete), app-written `exhibits.json`, `Trial/exhibits.json` auto-detect, retain external-open, `CaseBackup` helper (tested, no UI yet).

**Phase B (later):**
iCloud backup/restore UI, rename/reorder UI polish, folders/groups within a case, exhibit "stickers", AirDrop/share, Photos-library import.

## Out of scope

Per-stroke annotation editing, transcript sync, real waveform (separate phases). No change to the presentation/annotation/video/audio engines.
