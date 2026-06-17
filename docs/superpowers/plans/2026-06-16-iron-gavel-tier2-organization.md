# Iron Gavel — Tier 2 Organization & Speed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Background subagents cannot run Bash/builds — a human or foreground session runs `xcodegen generate` + `xcodebuild ... test` at each "Run" step.

**Goal:** Add three presenter-side organization/speed features, modeled on TrialPad, without touching jury mirroring or the publish gate:
1. **Hot Docs / Key Flags** — star exhibits; a ★ Key section/filter in the sidebar.
2. **Folders / Groups** — organize exhibits into named folders; Party/Folder grouping toggle.
3. **Search within documents** — full-text PDF search (`PDFDocument.findString`), list hits, jump to page.

**Architecture:** Two additive optional fields on `Exhibit` (`isKey`, `folder`) persisted via the existing `CaseManifestWriter`/`CaseLoader` round-trip. Pure helpers `ExhibitMutator`, `ExhibitGrouping`, `DocumentSearch`. A `CaseController` extracting the existing persist-and-reload dance. New UI: sidebar ★ Key section + grouping toggle, editor folder field, preview key star, `DocumentSearchView` sheet. One small presenter-only `AppState.requestedPreviewPage`. **No `JuryDisplay`/`JuryViewport`/`JuryView`/publish-gate changes.**

**Tech Stack:** Swift 5.9, SwiftUI, Foundation, PDFKit, XCTest/XCUITest, XcodeGen.

**Reference:** `docs/superpowers/specs/2026-06-16-iron-gavel-tier2-organization-design.md`.

---

## Conventions

- Repo root: `/Volumes/WD_4TB/Code/Iron-Gavel-Presentation`. Branch: `iron-gavel-tier2-organization` (create off `main`).
- After adding files: `xcodegen generate`. Build/test on `iPad (A16)`:
  ```
  xcodebuild -project IronGavel.xcodeproj -scheme IronGavel -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -40
  ```
- Baseline at branch start: **124 tests passing; keep green.**
- The `Case` model property `case` is a keyword — access as `` kase.`case` ``.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## File Structure

```
IronGavel/Library/
  ExhibitMutator.swift        # pure: toggleKey / setFolder / replacing (NEW)
  DocumentSearch.swift        # PDF full-text search engine (NEW)
IronGavel/Presenter/
  CaseController.swift        # @MainActor persist-and-reload wrapper (NEW)
  ExhibitGrouping.swift       # pure: party/folder sections (NEW)
  DocumentSearchView.swift    # search sheet (NEW)
IronGavelTests/Library/
  ExhibitOrganizationTests.swift   # Codable + Mutator + Grouping + DocumentSearch (NEW)
IronGavelUITests/
  OrganizationUITest.swift    # key / folder / docsearch smoke (NEW)
```
Modified (SHARED): `IronGavel/Model/Exhibit.swift`, `exhibits.schema.json`, `IronGavel/State/AppState.swift`, `IronGavel/Presenter/ExhibitSidebar.swift`, `IronGavel/Presenter/ExhibitEditorSheet.swift`, `IronGavel/Presenter/PreviewPane.swift`, `IronGavel/Presenter/PresenterToolbar.swift`, `IronGavel/Presenter/PresenterScene.swift`.

---

## Task 1: Exhibit gains `isKey` + `folder` (back-compatible)

**Files:** Modify `IronGavel/Model/Exhibit.swift`; add tests to new `IronGavelTests/Library/ExhibitOrganizationTests.swift`.

- [ ] **Step 1: Failing test** — create `IronGavelTests/Library/ExhibitOrganizationTests.swift`:

```swift
import XCTest
@testable import IronGavel

// MARK: - shared helpers

private func orgTempDir() throws -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("igorg-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

private func makeExhibit(id: String, party: Party = .defense, status: ExhibitStatus = .admitted,
                         mediaType: MediaType = .pdf, file: String = "Exhibits/x.pdf",
                         isKey: Bool = false, folder: String? = nil) -> Exhibit {
    Exhibit(id: id, party: party, description: "desc-\(id)", file: file, witness: nil, bates: nil,
            status: status, mediaType: mediaType, objection: nil, ruling: nil, notes: nil,
            exhibitNumber: nil, isKey: isKey, folder: folder)
}

// MARK: - Codable / back-compat

final class ExhibitCodableKeyFolderTests: XCTestCase {
    func test_decodes_manifest_without_key_or_folder_as_defaults() throws {
        // A legacy / dw-exhibit-manager manifest omits is_key and folder entirely.
        let json = """
        {"id":"D-001","party":"Defense","description":"Photo","file":"Exhibits/p.pdf",
         "status":"admitted","media_type":"pdf"}
        """.data(using: .utf8)!
        let ex = try JSONDecoder().decode(Exhibit.self, from: json)
        XCTAssertFalse(ex.isKey)
        XCTAssertNil(ex.folder)
    }

    func test_round_trips_key_and_folder() throws {
        let ex = makeExhibit(id: "D-002", isKey: true, folder: "Witness A")
        let data = try JSONEncoder().encode(ex)
        let back = try JSONDecoder().decode(Exhibit.self, from: data)
        XCTAssertEqual(back, ex)
        // Verify snake_case keys on the wire.
        let str = String(data: data, encoding: .utf8)!
        XCTAssertTrue(str.contains("\"is_key\""))
        XCTAssertTrue(str.contains("\"folder\""))
    }

    func test_full_case_round_trips_through_writer_and_loader() throws {
        let tmp = try orgTempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let kase = Case(contractVersion: ContractVersion.supported,
                        case: .init(caption: "State v. Doe", docket: "D", court: "C"),
                        generated: "2026-06-16T00:00:00Z", pathBase: "sidecar_dir",
                        exhibits: [makeExhibit(id: "D-001", isKey: true, folder: "Topic 1"),
                                   makeExhibit(id: "D-002")])
        try CaseManifestWriter().write(kase, to: tmp)
        XCTAssertEqual(try CaseLoader().load(folderURL: tmp), kase)
    }
}
```

- [ ] **Step 2: Run — expect failure** (`Exhibit` has no `isKey`/`folder`; init args don't compile).

- [ ] **Step 3: Implement** — replace `IronGavel/Model/Exhibit.swift` with:

```swift
import Foundation

struct Exhibit: Codable, Hashable, Identifiable {
    let id: String
    let party: Party
    let description: String
    let file: String
    let witness: String?
    let bates: String?
    let status: ExhibitStatus
    let mediaType: MediaType
    let objection: String?
    let ruling: String?
    let notes: String?
    /// The human-assigned exhibit number / sticker (e.g. "D-1"). Imported documents
    /// start unmarked (nil); the attorney assigns it. Distinct from `id`, the stable
    /// internal key used to track selection, annotations, etc.
    let exhibitNumber: String?
    /// "Hot Doc" star — flags an exhibit for one-tap recall mid-testimony. Defaults false;
    /// absent in legacy/external manifests.
    let isKey: Bool
    /// Folder / group name within the case (by witness or topic). nil = "Unfiled".
    /// Absent in legacy/external manifests.
    let folder: String?

    enum CodingKeys: String, CodingKey {
        case id, party, description, file, witness, bates, status
        case mediaType = "media_type"
        case objection, ruling, notes
        case exhibitNumber = "exhibit_number"
        case isKey = "is_key"
        case folder
    }

    init(id: String, party: Party, description: String, file: String,
         witness: String?, bates: String?, status: ExhibitStatus, mediaType: MediaType,
         objection: String?, ruling: String?, notes: String?, exhibitNumber: String? = nil,
         isKey: Bool = false, folder: String? = nil) {
        self.id = id
        self.party = party
        self.description = description
        self.file = file
        self.witness = witness
        self.bates = bates
        self.status = status
        self.mediaType = mediaType
        self.objection = objection
        self.ruling = ruling
        self.notes = notes
        self.exhibitNumber = exhibitNumber
        self.isKey = isKey
        self.folder = folder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        party = try c.decode(Party.self, forKey: .party)
        description = try c.decode(String.self, forKey: .description)
        file = try c.decode(String.self, forKey: .file)
        witness = try c.decodeIfPresent(String.self, forKey: .witness)
        bates = try c.decodeIfPresent(String.self, forKey: .bates)
        status = try c.decode(ExhibitStatus.self, forKey: .status)
        mediaType = try c.decode(MediaType.self, forKey: .mediaType)
        objection = try c.decodeIfPresent(String.self, forKey: .objection)
        ruling = try c.decodeIfPresent(String.self, forKey: .ruling)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        exhibitNumber = try c.decodeIfPresent(String.self, forKey: .exhibitNumber)
        isKey = try c.decodeIfPresent(Bool.self, forKey: .isKey) ?? false
        folder = try c.decodeIfPresent(String.self, forKey: .folder)
    }

    /// The exhibit number to display, if any. Falls back to `id` for externally-authored
    /// exhibits whose id already is the number (e.g. "D-001"); nil for unmarked imports.
    var displayNumber: String? {
        if let n = exhibitNumber, !n.isEmpty { return n }
        return ExhibitNumbering.looksLikeNumber(id) ? id : nil
    }
}

enum ExhibitNumbering {
    static func looksLikeNumber(_ s: String) -> Bool {
        s.range(of: "^[A-Za-z]{1,4}-?[0-9]{1,5}$", options: .regularExpression) != nil
    }
}
```

> Note: a custom `init(from:)` is added because `decodeIfPresent` for the new fields requires it (synthesized decoding would make `is_key`/`folder` required). `Encodable` stays synthesized — it always emits both keys, which is what we want for app-written manifests. `Hashable`/`Equatable` remain synthesized.

- [ ] **Step 4: Run — pass; all 124 existing tests still pass** (existing `Exhibit(...)` calls use defaulted new args; existing fixtures decode via `decodeIfPresent`). **Step 5: Commit** (`feat(model): add isKey + folder to Exhibit (back-compatible)`).

---

## Task 2: Update exhibits.schema.json

**Files:** Modify `exhibits.schema.json` (repo root).

- [ ] **Step 1: Add the two optional properties** — inside the exhibit `items.properties` object, after `"exhibit_number"`, add:

```json
          "is_key": {
            "type": "boolean",
            "description": "Hot Doc / Key flag — starred for one-tap recall mid-testimony. App-written; absent in legacy manifests (treated as false)."
          },
          "folder": {
            "type": "string",
            "description": "Folder / group name within the case (by witness or topic). App-written; absent = Unfiled."
          }
```

These are optional (not added to `required`), so existing manifests remain valid. `additionalProperties: false` now permits the app's output.

- [ ] **Step 2: Commit** (`docs(schema): document optional is_key + folder exhibit fields`). (No build needed; the Swift loader doesn't validate against the schema.)

---

## Task 3: ExhibitMutator (pure)

**Files:** Create `IronGavel/Library/ExhibitMutator.swift`; add tests to `ExhibitOrganizationTests.swift`.

- [ ] **Step 1: Failing test** — append to `ExhibitOrganizationTests.swift`:

```swift
// MARK: - ExhibitMutator

final class ExhibitMutatorTests: XCTestCase {
    private func kase(_ exhibits: [Exhibit]) -> Case {
        Case(contractVersion: ContractVersion.supported,
             case: .init(caption: "C", docket: "D", court: "Ct"),
             generated: "t", pathBase: "sidecar_dir", exhibits: exhibits)
    }

    func test_toggleKey_flips_only_target() {
        let k = kase([makeExhibit(id: "A"), makeExhibit(id: "B")])
        let out = ExhibitMutator.toggleKey("A", in: k)
        XCTAssertTrue(out.exhibits[0].isKey)
        XCTAssertFalse(out.exhibits[1].isKey)
        let back = ExhibitMutator.toggleKey("A", in: out)
        XCTAssertFalse(back.exhibits[0].isKey)
    }

    func test_setFolder_sets_and_clears_target_only() {
        let k = kase([makeExhibit(id: "A"), makeExhibit(id: "B", folder: "Old")])
        let out = ExhibitMutator.setFolder("Witness A", for: "A", in: k)
        XCTAssertEqual(out.exhibits[0].folder, "Witness A")
        XCTAssertEqual(out.exhibits[1].folder, "Old")
        let cleared = ExhibitMutator.setFolder(nil, for: "B", in: out)
        XCTAssertNil(cleared.exhibits[1].folder)
    }

    func test_unknown_id_is_noop() {
        let k = kase([makeExhibit(id: "A")])
        XCTAssertEqual(ExhibitMutator.toggleKey("Z", in: k), k)
    }
}
```

- [ ] **Step 2: Run — expect `Cannot find 'ExhibitMutator'`.**

- [ ] **Step 3: Implement** `IronGavel/Library/ExhibitMutator.swift`:

```swift
import Foundation

/// Pure transforms over a `Case`'s exhibits. The single place that knows how to
/// produce an updated `Case` from a per-exhibit edit, so views never re-derive it.
enum ExhibitMutator {
    /// Returns a copy of `kase` with the exhibit matching `id` replaced by `transform(exhibit)`.
    /// Non-existent id → unchanged case.
    static func replacing(_ id: String, in kase: Case, with transform: (Exhibit) -> Exhibit) -> Case {
        let exhibits = kase.exhibits.map { $0.id == id ? transform($0) : $0 }
        return Case(contractVersion: kase.contractVersion, case: kase.`case`,
                    generated: kase.generated, pathBase: kase.pathBase, exhibits: exhibits)
    }

    static func toggleKey(_ id: String, in kase: Case) -> Case {
        replacing(id, in: kase) { ex in
            Exhibit(id: ex.id, party: ex.party, description: ex.description, file: ex.file,
                    witness: ex.witness, bates: ex.bates, status: ex.status, mediaType: ex.mediaType,
                    objection: ex.objection, ruling: ex.ruling, notes: ex.notes,
                    exhibitNumber: ex.exhibitNumber, isKey: !ex.isKey, folder: ex.folder)
        }
    }

    static func setFolder(_ folder: String?, for id: String, in kase: Case) -> Case {
        let normalized = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (normalized?.isEmpty ?? true) ? nil : normalized
        return replacing(id, in: kase) { ex in
            Exhibit(id: ex.id, party: ex.party, description: ex.description, file: ex.file,
                    witness: ex.witness, bates: ex.bates, status: ex.status, mediaType: ex.mediaType,
                    objection: ex.objection, ruling: ex.ruling, notes: ex.notes,
                    exhibitNumber: ex.exhibitNumber, isKey: ex.isKey, folder: value)
        }
    }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(library): ExhibitMutator pure key/folder transforms`).

---

## Task 4: ExhibitGrouping (pure)

**Files:** Create `IronGavel/Presenter/ExhibitGrouping.swift`; add tests to `ExhibitOrganizationTests.swift`.

- [ ] **Step 1: Failing test** — append:

```swift
// MARK: - ExhibitGrouping

final class ExhibitGroupingTests: XCTestCase {
    func test_party_mode_orders_by_party_allCases() {
        let exhibits = [makeExhibit(id: "S", party: .state), makeExhibit(id: "D", party: .defense)]
        let sections = ExhibitGrouping.sections(for: exhibits, mode: .party)
        XCTAssertEqual(sections.map(\.title), ["Defense", "State"]) // Party.allCases order, empties dropped
        XCTAssertEqual(sections[0].exhibits.map(\.id), ["D"])
    }

    func test_folder_mode_groups_alphabetically_with_unfiled_last() {
        let exhibits = [makeExhibit(id: "A", folder: "Zeta"),
                        makeExhibit(id: "B", folder: "Alpha"),
                        makeExhibit(id: "C", folder: nil)]
        let sections = ExhibitGrouping.sections(for: exhibits, mode: .folder)
        XCTAssertEqual(sections.map(\.title), ["Alpha", "Zeta", "Unfiled"])
        XCTAssertEqual(sections[2].exhibits.map(\.id), ["C"])
    }

    func test_folder_mode_all_unfiled() {
        let sections = ExhibitGrouping.sections(for: [makeExhibit(id: "A")], mode: .folder)
        XCTAssertEqual(sections.map(\.title), ["Unfiled"])
    }
}
```

- [ ] **Step 2: Run — expect `Cannot find 'ExhibitGrouping'`.**

- [ ] **Step 3: Implement** `IronGavel/Presenter/ExhibitGrouping.swift`:

```swift
import Foundation

enum SidebarGrouping: String, CaseIterable, Hashable {
    case party = "Party"
    case folder = "Folder"
}

/// Pure grouping for the exhibit sidebar. Produces ordered, non-empty sections.
enum ExhibitGrouping {
    static let unfiledTitle = "Unfiled"

    struct Section: Equatable { let title: String; let exhibits: [Exhibit] }

    static func sections(for exhibits: [Exhibit], mode: SidebarGrouping) -> [Section] {
        switch mode {
        case .party:
            return Party.allCases.compactMap { party in
                let items = exhibits.filter { $0.party == party }
                return items.isEmpty ? nil : Section(title: party.rawValue, exhibits: items)
            }
        case .folder:
            let named = Dictionary(grouping: exhibits.filter { $0.folder != nil },
                                   by: { $0.folder! })
            var sections = named.keys.sorted().map { key in
                Section(title: key, exhibits: named[key]!)
            }
            let unfiled = exhibits.filter { $0.folder == nil }
            if !unfiled.isEmpty { sections.append(Section(title: unfiledTitle, exhibits: unfiled)) }
            return sections
        }
    }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(presenter): ExhibitGrouping party/folder sections`).

---

## Task 5: DocumentSearch engine (pure-injectable)

**Files:** Create `IronGavel/Library/DocumentSearch.swift`; add tests to `ExhibitOrganizationTests.swift`.

- [ ] **Step 1: Failing test** — append (builds a 2-page text PDF with `UIGraphicsPDFRenderer`, the same toolkit the flattener tests use):

```swift
import PDFKit
import UIKit

// MARK: - DocumentSearch

final class DocumentSearchTests: XCTestCase {
    /// Writes a 2-page PDF: page 1 contains "alpha intersection", page 2 contains "bravo collision".
    private func makeTwoPagePDF(at url: URL) throws {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { ctx in
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24)]
            ctx.beginPage()
            ("alpha intersection" as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: attrs)
            ctx.beginPage()
            ("bravo collision" as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: attrs)
        }
        try data.write(to: url)
    }

    func test_finds_term_on_second_page_with_zero_based_index() throws {
        let tmp = try orgTempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let exhibitsDir = tmp.appendingPathComponent("Exhibits")
        try FileManager.default.createDirectory(at: exhibitsDir, withIntermediateDirectories: true)
        try makeTwoPagePDF(at: exhibitsDir.appendingPathComponent("doc.pdf"))

        let exhibit = makeExhibit(id: "D-001", mediaType: .pdf, file: "Exhibits/doc.pdf")
        let hits = DocumentSearch().search(query: "COLLISION", in: [exhibit], caseFolder: tmp) { url in
            PDFDocument(url: url)
        }
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].exhibitId, "D-001")
        XCTAssertEqual(hits[0].page, 1)            // 0-based: page 2
    }

    func test_skips_non_pdf_and_short_query() throws {
        let tmp = try orgTempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let audio = makeExhibit(id: "A-001", mediaType: .audio, file: "Exhibits/c.m4a")
        XCTAssertTrue(DocumentSearch().search(query: "x", in: [audio], caseFolder: tmp) { _ in nil }.isEmpty)
        XCTAssertTrue(DocumentSearch().search(query: "anything", in: [audio], caseFolder: tmp) { _ in nil }.isEmpty)
    }

    func test_missing_document_is_skipped() throws {
        let tmp = try orgTempDir(); defer { try? FileManager.default.removeItem(at: tmp) }
        let exhibit = makeExhibit(id: "D-001", mediaType: .pdf, file: "Exhibits/missing.pdf")
        let hits = DocumentSearch().search(query: "alpha", in: [exhibit], caseFolder: tmp) { url in
            PDFDocument(url: url)   // returns nil for missing file
        }
        XCTAssertTrue(hits.isEmpty)
    }
}
```

- [ ] **Step 2: Run — expect `Cannot find 'DocumentSearch'`.**

- [ ] **Step 3: Implement** `IronGavel/Library/DocumentSearch.swift`:

```swift
import Foundation
import PDFKit

struct DocumentSearchHit: Hashable, Identifiable {
    let id = UUID()
    let exhibitId: String
    let exhibitDescription: String
    let page: Int       // 0-based, ready for the preview page binding / state.setPage
    let snippet: String

    static func == (l: DocumentSearchHit, r: DocumentSearchHit) -> Bool {
        l.exhibitId == r.exhibitId && l.page == r.page
    }
    func hash(into h: inout Hasher) { h.combine(exhibitId); h.combine(page) }
}

/// Full-text search across a case's PDF exhibits. `documentProvider` is injected so
/// tests can supply fixtures; production passes `PDFDocumentCache.shared.document`.
struct DocumentSearch {
    func search(query rawQuery: String,
                in exhibits: [Exhibit],
                caseFolder: URL,
                documentProvider: (URL) -> PDFDocument?) -> [DocumentSearchHit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }

        var hits: [DocumentSearchHit] = []
        for exhibit in exhibits where exhibit.mediaType == .pdf {
            let url = caseFolder.appendingPathComponent(exhibit.file)
            guard let doc = documentProvider(url) else { continue }
            let selections = doc.findString(query, withOptions: [.caseInsensitive])
            var seenPages = Set<Int>()
            for selection in selections {
                guard let page = selection.pages.first else { continue }
                let pageIndex = doc.index(for: page)
                guard !seenPages.contains(pageIndex) else { continue }
                seenPages.insert(pageIndex)
                hits.append(DocumentSearchHit(
                    exhibitId: exhibit.id,
                    exhibitDescription: exhibit.description,
                    page: pageIndex,
                    snippet: snippet(for: selection, on: page)
                ))
            }
        }
        return hits
    }

    /// A short context string around the match (the matched line, trimmed).
    private func snippet(for selection: PDFSelection, on page: PDFPage) -> String {
        let matched = selection.string ?? ""
        let pageText = page.string ?? ""
        guard !matched.isEmpty, let range = pageText.range(of: matched, options: .caseInsensitive)
        else { return matched }
        let lower = pageText.index(range.lowerBound, offsetBy: -30, limitedBy: pageText.startIndex)
            ?? pageText.startIndex
        let upper = pageText.index(range.upperBound, offsetBy: 30, limitedBy: pageText.endIndex)
            ?? pageText.endIndex
        return "…" + pageText[lower..<upper].trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(library): DocumentSearch full-text PDF search engine`).

---

## Task 6: AppState.requestedPreviewPage (presenter-only jump target)

**Files:** Modify `IronGavel/State/AppState.swift`; add a test to `IronGavelTests/AppStateTests.swift`.

- [ ] **Step 1: Failing test** — append to `AppStateTests`:

```swift
    @MainActor
    func test_requestedPreviewPage_is_settable_and_independent_of_juryDisplay() {
        let state = AppState()
        XCTAssertNil(state.requestedPreviewPage)
        state.requestedPreviewPage = 3
        XCTAssertEqual(state.requestedPreviewPage, 3)
        // It must NOT have touched the jury.
        XCTAssertEqual(state.juryDisplay, .empty)
    }
```

- [ ] **Step 2: Run — expect failure** (`requestedPreviewPage` missing).

- [ ] **Step 3: Implement** — in `AppState`, add one stored property near the other presenter-only vars (after `var lastStatusBanner: String?`):

```swift
    /// Presenter-only: a page the doc-search wants the preview to jump to after selecting
    /// an exhibit. NOT mirrored to the jury. PreviewPane consumes and clears it.
    var requestedPreviewPage: Int?
```

(No other logic changes; `juryDisplay` and the publish path are untouched.)

- [ ] **Step 4: Run — pass; 124+ green. Step 5: Commit** (`feat(state): presenter-only requestedPreviewPage for search jump`).

---

## Task 7: CaseController (extract persist-and-reload)

**Files:** Create `IronGavel/Presenter/CaseController.swift`; refactor `IronGavel/Presenter/PreviewPane.swift` to use it.

- [ ] **Step 1: Implement** `IronGavel/Presenter/CaseController.swift`:

```swift
import Foundation

/// Coordinates a `Case` mutation → atomic manifest write → AppState refresh → re-select.
/// One place for the persist-and-reload dance that key/folder toggles and the editor share.
@MainActor
struct CaseController {
    let state: AppState
    private let writer = CaseManifestWriter()

    /// Apply a pure transform to the current case, persist it, and refresh state,
    /// keeping `selectId` selected (nil to clear). Returns false if there is no open case
    /// or the write fails (state is left untouched on failure).
    @discardableResult
    func apply(_ transform: (Case) -> Case, selectId: String?) -> Bool {
        guard let folder = state.caseFolderURL, let kase = state.currentCase else { return false }
        let updated = transform(kase)
        do { try writer.write(updated, to: folder) } catch { return false }
        state.apply(case: updated, folder: folder)
        state.selectedExhibit = selectId.flatMap { id in updated.exhibits.first { $0.id == id } }
        return true
    }

    func toggleKey(_ id: String) {
        apply({ ExhibitMutator.toggleKey(id, in: $0) }, selectId: state.selectedExhibit?.id)
    }

    func setFolder(_ folder: String?, for id: String) {
        apply({ ExhibitMutator.setFolder(folder, for: id, in: $0) }, selectId: state.selectedExhibit?.id)
    }

    /// Replace an exhibit wholesale (used by the editor), keyed by its stable `id`.
    func replace(_ edited: Exhibit) {
        apply({ ExhibitMutator.replacing(edited.id, in: $0) { _ in edited } }, selectId: edited.id)
    }

    func delete(_ exhibit: Exhibit) {
        apply({ kase in
            Case(contractVersion: kase.contractVersion, case: kase.`case`,
                 generated: kase.generated, pathBase: kase.pathBase,
                 exhibits: kase.exhibits.filter { $0.id != exhibit.id })
        }, selectId: nil)
    }
}
```

> Note: the editor previously keyed updates off `$0.file == original.file`; we key off the stable `id` instead (cleaner, and `id` is the selection key everywhere else). The editor does not let the user change `id`, so this is safe.

- [ ] **Step 2: Refactor `PreviewPane.swift`** — replace its `updateExhibit`/`deleteExhibit`/`persist` helpers and the editor sheet wiring to use `CaseController`. Specifically:

Replace the `.sheet(isPresented: $showEditor)` body's `onSave`/`onDelete` and the three helper functions:

Find:
```swift
                    onSave: { edited in showEditor = false; updateExhibit(original: exhibit, edited: edited) },
                    onDelete: { showEditor = false; deleteExhibit(exhibit) },
```
Replace with:
```swift
                    onSave: { edited in showEditor = false; CaseController(state: state).replace(edited) },
                    onDelete: { showEditor = false; CaseController(state: state).delete(exhibit) },
```

Then delete the now-unused `updateExhibit`, `deleteExhibit`, `persist`, and the `private let manifestWriter = CaseManifestWriter()` stored property from `PreviewPane` (CaseController owns the writer now).

- [ ] **Step 3: Build + test — 124+ green** (the existing editor flow now routes through CaseController; behavior identical). **Step 4: Commit** (`refactor(presenter): CaseController owns persist-and-reload`).

---

## Task 8: Sidebar — key glyph, ★ Key section, grouping toggle, mark-key swipe

**Files:** Modify `IronGavel/Presenter/ExhibitSidebar.swift`.

- [ ] **Step 1: Implement** — replace `ExhibitSidebar.swift` with:

```swift
import SwiftUI

struct ExhibitSidebar: View {
    @Environment(AppState.self) private var state
    @State private var searchText = ""
    @State private var grouping: SidebarGrouping = .party

    var body: some View {
        @Bindable var state = state

        List(selection: Binding(
            get: { state.selectedExhibit?.id },
            set: { id in
                if let id, let kase = state.currentCase,
                   let exhibit = kase.exhibits.first(where: { $0.id == id }) {
                    state.select(exhibit)
                }
            }
        )) {
            if !keyExhibits.isEmpty {
                Section {
                    ForEach(keyExhibits) { exhibit in
                        row(for: exhibit).tag(exhibit.id)
                    }
                } header: {
                    Label("Key", systemImage: "star.fill")
                        .font(Theme.Typography.sectionLabel)
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.accentDeep)
                }
                .accessibilityIdentifier("sidebar.section.key")
            }

            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.exhibits) { exhibit in
                        row(for: exhibit).tag(exhibit.id)
                    }
                } header: {
                    Text(section.title.uppercased())
                        .font(Theme.Typography.sectionLabel)
                        .tracking(1.0)
                        .foregroundStyle(Theme.Palette.accentDeep)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search id, witness, Bates…")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Group by", selection: $grouping) {
                    ForEach(SidebarGrouping.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("sidebar.grouping")
            }
        }
        .accessibilityIdentifier("exhibit.sidebar")
    }

    @ViewBuilder
    private func row(for exhibit: Exhibit) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
            HStack(spacing: Theme.Spacing.s) {
                ExhibitNumberChip(number: exhibit.displayNumber)
                if exhibit.isKey {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityIdentifier("exhibit.keyglyph.\(exhibit.id)")
                }
                Spacer(minLength: Theme.Spacing.s)
                StatusBadge(status: exhibit.status)
            }
            Text(exhibit.description)
                .font(Theme.Typography.itemTitle)
                .lineLimit(2)
            if let witness = exhibit.witness, !witness.isEmpty {
                Label(witness, systemImage: "person")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.mutedText)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityIdentifier("exhibit.row.\(exhibit.id)")
        .swipeActions(edge: .leading) {
            Button {
                CaseController(state: state).toggleKey(exhibit.id)
            } label: {
                Label(exhibit.isKey ? "Unkey" : "Mark Key", systemImage: "star")
            }
            .tint(Theme.Palette.accent)
            .accessibilityIdentifier("exhibit.markkey.\(exhibit.id)")
        }
    }

    private var filtered: [Exhibit] {
        (state.currentCase?.exhibits ?? []).filter { ExhibitFilter.matches($0, query: searchText) }
    }

    private var keyExhibits: [Exhibit] { filtered.filter { $0.isKey } }

    private var sections: [ExhibitGrouping.Section] {
        ExhibitGrouping.sections(for: filtered, mode: grouping)
    }
}
```

> Note: the ★ Key section lists the *same* exhibits that also appear in their party/folder section (a pinned shortcut, not a move). Tapping either selects the same exhibit (same `.tag(id)`). If a List complains about duplicate selection tags across sections, the duplication is acceptable for SwiftUI `List` selection because each `ForEach` row is a distinct view; if a runtime warning appears, gate the body sections to exclude keyed items — but prefer the shortcut behavior (verify in the UI smoke test).

- [ ] **Step 2: Build + test — 124+ green** (existing `exhibit.sidebar` / `exhibit.row.*` identifiers preserved; `PublishFlowUITest` etc. still find their rows). **Step 3: Commit** (`feat(presenter): sidebar key section + party/folder grouping + mark-key swipe`).

---

## Task 9: Key star in the PreviewPane header + Folder field in the editor

**Files:** Modify `IronGavel/Presenter/PreviewPane.swift`, `IronGavel/Presenter/ExhibitEditorSheet.swift`.

- [ ] **Step 1: Add the Key star to the preview header** — in `PreviewPane.header(for:)`, before the existing pencil (Edit) button, add:

```swift
            Button {
                CaseController(state: state).toggleKey(exhibit.id)
            } label: {
                Image(systemName: exhibit.isKey ? "star.fill" : "star")
            }
            .accessibilityIdentifier("exhibit.key")
```

- [ ] **Step 2: Add a Folder field to the editor** — in `ExhibitEditorSheet.swift`:

Add a state var after `_bates`:
```swift
    @State private var folder: String
```
Initialize it in `init` after `_bates = ...`:
```swift
        _folder = State(initialValue: exhibit.folder ?? "")
```
Add the field inside the `Section("Details")`, after the Bates field:
```swift
                    TextField("Folder (witness or topic)", text: $folder)
                        .accessibilityIdentifier("editor.folder")
```
Update `updated()` to carry the folder (trim → nil if empty):
```swift
    private func updated() -> Exhibit {
        let trimmedFolder = folder.trimmingCharacters(in: .whitespaces)
        return Exhibit(id: exhibit.id, party: party, description: descriptionText, file: exhibit.file,
                witness: witness.isEmpty ? nil : witness,
                bates: bates.isEmpty ? nil : bates,
                status: status, mediaType: exhibit.mediaType,
                objection: exhibit.objection, ruling: exhibit.ruling, notes: exhibit.notes,
                exhibitNumber: number.trimmingCharacters(in: .whitespaces).isEmpty ? nil
                    : number.trimmingCharacters(in: .whitespaces),
                isKey: exhibit.isKey,
                folder: trimmedFolder.isEmpty ? nil : trimmedFolder)
    }
```

> Note: `isKey` is preserved through the editor (toggled separately via the star), so editing metadata never clears the key flag.

- [ ] **Step 3: Build + test — 124+ green. Step 4: Commit** (`feat(presenter): key star in preview header + folder field in editor`).

---

## Task 10: DocumentSearchView + toolbar entry + jump-to-page

**Files:** Create `IronGavel/Presenter/DocumentSearchView.swift`; modify `IronGavel/Presenter/PresenterToolbar.swift`, `IronGavel/Presenter/PresenterScene.swift`, `IronGavel/Presenter/PreviewPane.swift`.

- [ ] **Step 1: Implement** `IronGavel/Presenter/DocumentSearchView.swift`:

```swift
import SwiftUI
import PDFKit

struct DocumentSearchView: View {
    @Environment(AppState.self) private var state
    let onJump: (_ exhibit: Exhibit, _ page: Int) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var hits: [DocumentSearchHit] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                results
            }
            .navigationTitle("Search Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search text in PDF exhibits…", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("docsearch.field")
                .onChange(of: query) { _, _ in scheduleSearch() }
            if isSearching { ProgressView() }
        }
        .padding(12)
    }

    @ViewBuilder
    private var results: some View {
        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            placeholder("Type at least 2 characters.")
        } else if hits.isEmpty && !isSearching {
            placeholder("No matches in this case's PDF exhibits.")
        } else {
            List(hits) { hit in
                Button {
                    if let exhibit = state.currentCase?.exhibits.first(where: { $0.id == hit.exhibitId }) {
                        onJump(exhibit, hit.page)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(hit.exhibitDescription).font(.headline).lineLimit(1)
                            Spacer()
                            Text("p. \(hit.page + 1)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(hit.snippet).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .accessibilityIdentifier("docsearch.hit.\(hit.exhibitId).\(hit.page)")
            }
            .listStyle(.plain)
        }
    }

    private func placeholder(_ text: String) -> some View {
        VStack { Spacer(); Text(text).foregroundStyle(.secondary); Spacer() }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query
        let exhibits = state.currentCase?.exhibits ?? []
        guard let folder = state.caseFolderURL else { hits = []; return }
        guard q.trimmingCharacters(in: .whitespaces).count >= 2 else { hits = []; return }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // debounce
            if Task.isCancelled { return }
            let found = await Task.detached(priority: .userInitiated) {
                DocumentSearch().search(query: q, in: exhibits, caseFolder: folder) { url in
                    PDFDocumentCache.shared.document(for: url)
                }
            }.value
            if Task.isCancelled { return }
            await MainActor.run {
                self.hits = found
                self.isSearching = false
            }
        }
    }
}
```

- [ ] **Step 2: Add the toolbar entry** — in `PresenterToolbar.swift`, add a stored callback and button. Change the header:

Find:
```swift
    let openCaseAction: () -> Void
    let importAction: () -> Void
```
Replace with:
```swift
    let openCaseAction: () -> Void
    let importAction: () -> Void
    let searchDocsAction: () -> Void
```
Add a button after the Import button:
```swift
            Button(action: searchDocsAction) {
                Label("Search Docs", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(state.currentCase == nil)
            .accessibilityIdentifier("toolbar.docSearch")
```

- [ ] **Step 3: Wire the sheet in `PresenterScene.swift`** — add state near the other `@State`s:
```swift
    @State private var showDocSearch = false
```
Pass the action where `PresenterToolbar` is constructed:
```swift
                PresenterToolbar(openCaseAction: { showFolderPicker = true },
                                 importAction: { showImporter = true },
                                 searchDocsAction: { showDocSearch = true })
```
Add the sheet alongside the existing `.fileImporter` / `.sheet` modifiers:
```swift
        .sheet(isPresented: $showDocSearch) {
            DocumentSearchView(
                onJump: { exhibit, page in
                    showDocSearch = false
                    state.select(exhibit)
                    state.requestedPreviewPage = page
                },
                onDismiss: { showDocSearch = false }
            )
            .environment(state)
        }
```

- [ ] **Step 4: Consume `requestedPreviewPage` in `PreviewPane.swift`** — make the preview honor the search jump. Add a consumer that runs when selection or the request changes. Add these modifiers to the outer `VStack` in `PreviewPane.body` (next to the existing `.onChange(of: state.selectedExhibit?.id)`):

```swift
        .onChange(of: state.requestedPreviewPage) { _, requested in
            applyRequestedPageIfNeeded(requested)
        }
        .onChange(of: state.selectedExhibit?.id) { _, _ in
            // selection just changed (search sets selection then page); apply after the
            // existing reset-to-0 handler by re-reading the request.
            applyRequestedPageIfNeeded(state.requestedPreviewPage)
        }
```

Add the helper:
```swift
    private func applyRequestedPageIfNeeded(_ requested: Int?) {
        guard let requested,
              let exhibit = state.selectedExhibit,
              exhibit.mediaType == .pdf else { return }
        page = requested
        state.requestedPreviewPage = nil
    }
```

> Ordering note: the existing `.onChange(of: state.selectedExhibit?.id)` already sets `page = 0`. Because `state.select(exhibit)` is called *before* `state.requestedPreviewPage = page` in the jump closure, the reset-to-0 fires first; the `requestedPreviewPage` `onChange` then sets the real page. Both handlers call `applyRequestedPageIfNeeded`, which is idempotent (clears the request once applied). This is presenter-only — if that exhibit is also the published one, the existing `.onChange(of: page)` will mirror the page through `state.setPage`, which is the same behavior as the attorney tapping the page arrows. That is desired (jury follows the presenter's page only when already published).

- [ ] **Step 5: Build + test — 124+ green. Step 6: Commit** (`feat(presenter): document search sheet with jump-to-page`).

---

## Task 11: UI smoke tests

**Files:** Create `IronGavelUITests/OrganizationUITest.swift`. Optionally add a text-bearing fixture (see note).

- [ ] **Step 1: Key + folder smoke (uses the existing `--ui-test-fixture`)**:

```swift
import XCTest

final class OrganizationUITest: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()
        return app
    }

    func test_mark_key_shows_key_section() {
        let app = launch()
        let row = app.descendants(matching: .any)["exhibit.row.D-001"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.swipeRight()
        let markKey = app.buttons["exhibit.markkey.D-001"]
        if markKey.waitForExistence(timeout: 3) { markKey.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["sidebar.section.key"].waitForExistence(timeout: 5))
    }

    func test_grouping_toggle_switches_to_folder() {
        let app = launch()
        let grouping = app.segmentedControls["sidebar.grouping"]
        XCTAssertTrue(grouping.waitForExistence(timeout: 10))
        grouping.buttons["Folder"].tap()
        // With no folders assigned, the fixture exhibits fall under "Unfiled".
        XCTAssertTrue(app.staticTexts["UNFILED"].waitForExistence(timeout: 5))
    }

    func test_doc_search_sheet_opens() {
        let app = launch()
        let button = app.buttons["toolbar.docSearch"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(app.textFields["docsearch.field"].waitForExistence(timeout: 5))
    }
}
```

> Note: the fixture `ui-test-exhibits.json` references PDF paths that aren't bundled with real text, so a full "type a term → tap a hit → preview jumps" UI assertion is unreliable. The `DocumentSearch` engine itself is covered by `DocumentSearchTests` (Task 5). This smoke test verifies the sheet opens and the field exists. If the orchestrator wants an end-to-end search UI test, add a bundled `docsearch-fixture.pdf` with a known string and a fixture exhibit pointing at it, then assert on `docsearch.hit.*` — but the unit coverage is the authoritative check.

- [ ] **Step 2: `xcodegen generate` then full test — all pass (124 + new unit + new UI). Step 3: Commit** (`test(organization): UI smoke for key/folder/doc-search`).

---

## Done criteria

- ★ Key: starring an exhibit (preview star or sidebar swipe) persists to `exhibits.json` and shows a pinned **Key** section + row glyph; editing metadata never clears it.
- Folders: assign a folder in the editor; the sidebar's Party/Folder toggle groups accordingly with "Unfiled" last.
- Doc search: the magnifier opens a sheet; typing finds text in PDF exhibits; tapping a hit selects that exhibit and the preview jumps to the page (presenter-only; jury unaffected unless that exhibit is already published).
- `dw-exhibit-manager` external folders (no `is_key`/`folder`) still load; app-written manifests validate against the updated schema.
- No change to jury mirroring / publish gate; **all existing tests stay green** (baseline 124). Then run **superpowers:finishing-a-development-branch**.
```
