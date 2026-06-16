# Iron Gavel — Self-Contained Cases Implementation Plan (Phase A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (background subagents cannot run Bash/builds in this environment). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make Iron Gavel self-contained — create cases in-app, import files that become exhibits, edit exhibit metadata/status, all persisted to `exhibits.json` written by the app.

**Architecture:** Keep `exhibits.json` as the on-disk format; the app now writes it. New `IronGavel/Library/` module: `CaseStore` (on-device cases under `Documents/Cases/`), `MediaTypeDetector`, `ExhibitIDAllocator`, `CaseManifestWriter`, `ExhibitImporter`, `CaseBackup`. New UI: `CaseLibraryView` (launch surface), `.fileImporter` import, `ExhibitEditorSheet`. `CaseLoader` gains `Trial/exhibits.json` fallback.

**Tech Stack:** Swift 5.9, SwiftUI (`.fileImporter`, `Form`), Foundation (FileManager, JSONEncoder), UniformTypeIdentifiers, XCTest. XcodeGen.

**Reference:** `docs/superpowers/specs/2026-06-16-iron-gavel-self-contained-cases-design.md`.

---

## Conventions

- Repo root: `/Volumes/WD_4TB/Code/Iron-Gavel-Presentation`. Branch: `iron-gavel-self-contained` (create off `main`).
- After adding files: `xcodegen generate`. Build/test on `iPad (A16)`:
  ```
  xcodebuild -project IronGavel.xcodeproj -scheme IronGavel -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -40
  ```
- Baseline at branch start: 112 tests passing; keep green.
- The `Case` model property `case` is a keyword — access as `` kase.`case` ``.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## File Structure

```
IronGavel/Library/
  MediaTypeDetector.swift     # extension -> MediaType (pure)
  ExhibitIDAllocator.swift    # next id per party (pure)
  CaseManifestWriter.swift    # write Case -> exhibits.json (atomic)
  CaseStore.swift             # on-device case CRUD under Documents/Cases
  ExhibitImporter.swift       # copy files in, create exhibits, update manifest
  CaseBackup.swift            # copy case folder to/from a backup root
IronGavel/Presenter/
  CaseLibraryView.swift       # launch surface: list/create/open cases
  ExhibitEditorSheet.swift    # edit one exhibit's metadata/status
```
Modified: `IronGavel/Loader/CaseLoader.swift`, `IronGavel/Presenter/PresenterScene.swift`, `IronGavel/Presenter/PresenterToolbar.swift`, `IronGavel/Presenter/PreviewPane.swift`.

---

## Task 1: MediaTypeDetector

**Files:** Create `IronGavel/Library/MediaTypeDetector.swift`, `IronGavelTests/Library/MediaTypeDetectorTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

final class MediaTypeDetectorTests: XCTestCase {
    func test_detects_each_class() {
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "PDF"), .pdf)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "jpg"), .image)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "heic"), .image)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "mov"), .video)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "m4a"), .audio)
        XCTAssertEqual(MediaTypeDetector.detect(fileExtension: "xyz"), .unknown)
    }
    func test_detects_from_url() {
        XCTAssertEqual(MediaTypeDetector.detect(url: URL(fileURLWithPath: "/a/b.MP4")), .video)
    }
}
```

- [ ] **Step 2: Run — expect `Cannot find 'MediaTypeDetector'`.**

- [ ] **Step 3: Implement**

```swift
import Foundation

enum MediaTypeDetector {
    static func detect(fileExtension ext: String) -> MediaType {
        switch ext.lowercased() {
        case "pdf": return .pdf
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp": return .image
        case "mov", "mp4", "m4v": return .video
        case "m4a", "mp3", "wav", "caf", "aac": return .audio
        default: return .unknown
        }
    }
    static func detect(url: URL) -> MediaType { detect(fileExtension: url.pathExtension) }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(library): MediaTypeDetector`).

---

## Task 2: ExhibitIDAllocator

**Files:** Create `IronGavel/Library/ExhibitIDAllocator.swift`, `IronGavelTests/Library/ExhibitIDAllocatorTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

final class ExhibitIDAllocatorTests: XCTestCase {
    private func ex(_ id: String, _ party: Party) -> Exhibit {
        Exhibit(id: id, party: party, description: "x", file: "f", witness: nil, bates: nil,
                status: .pending, mediaType: .pdf, objection: nil, ruling: nil, notes: nil)
    }
    func test_first_id_per_party() {
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: [], party: .defense), "D-001")
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: [], party: .state), "S-001")
    }
    func test_next_after_existing() {
        let existing = [ex("D-001", .defense), ex("D-002", .defense), ex("S-005", .state)]
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: existing, party: .defense), "D-003")
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: existing, party: .state), "S-006")
        XCTAssertEqual(ExhibitIDAllocator.nextID(existing: existing, party: .joint), "J-001")
    }
}
```

- [ ] **Step 2: Run — expect failure.**

- [ ] **Step 3: Implement**

```swift
import Foundation

enum ExhibitIDAllocator {
    static func prefix(for party: Party) -> String {
        switch party {
        case .defense: return "D"
        case .state:   return "S"
        case .joint:   return "J"
        case .court:   return "C"
        }
    }

    static func nextID(existing: [Exhibit], party: Party) -> String {
        let p = prefix(for: party)
        let maxN = existing.compactMap { e -> Int? in
            guard e.id.hasPrefix("\(p)-") else { return nil }
            return Int(e.id.dropFirst(p.count + 1))
        }.max() ?? 0
        return String(format: "%@-%03d", p, maxN + 1)
    }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(library): ExhibitIDAllocator`).

---

## Task 3: CaseManifestWriter

**Files:** Create `IronGavel/Library/CaseManifestWriter.swift`, `IronGavelTests/Library/CaseManifestWriterTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

final class CaseManifestWriterTests: XCTestCase {
    private var tmp: URL!
    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("igcase-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    func test_write_then_load_round_trips() throws {
        let exhibit = Exhibit(id: "D-001", party: .defense, description: "Photo", file: "Exhibits/p.pdf",
                              witness: nil, bates: nil, status: .admitted, mediaType: .pdf,
                              objection: nil, ruling: nil, notes: nil)
        let kase = Case(contractVersion: ContractVersion.supported,
                        case: .init(caption: "State v. Doe", docket: "D", court: "C"),
                        generated: "2026-06-16T00:00:00Z", pathBase: "sidecar_dir", exhibits: [exhibit])
        try CaseManifestWriter().write(kase, to: tmp)
        let loaded = try CaseLoader().load(folderURL: tmp)
        XCTAssertEqual(loaded, kase)
    }
}
```

- [ ] **Step 2: Run — expect `Cannot find 'CaseManifestWriter'`.**

- [ ] **Step 3: Implement**

```swift
import Foundation

struct CaseManifestWriter {
    func write(_ kase: Case, to caseFolder: URL) throws {
        try FileManager.default.createDirectory(at: caseFolder, withIntermediateDirectories: true)
        let url = caseFolder.appendingPathComponent("exhibits.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(kase)
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: tmp, to: url)
    }
}
```

- [ ] **Step 4: Run — pass (requires Task 6's loader unchanged behavior; works as-is). Step 5: Commit** (`feat(library): CaseManifestWriter`).

---

## Task 4: CaseStore

**Files:** Create `IronGavel/Library/CaseStore.swift`, `IronGavelTests/Library/CaseStoreTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

final class CaseStoreTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("igstore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func test_create_lists_and_loads_empty_case() throws {
        let store = CaseStore(root: root)
        XCTAssertTrue(store.list().isEmpty)
        let folder = try store.create(name: "Doe", now: "2026-06-16T00:00:00Z")
        XCTAssertEqual(store.list(), ["Doe"])
        let loaded = try CaseLoader().load(folderURL: folder)
        XCTAssertEqual(loaded.exhibits.count, 0)
        XCTAssertEqual(loaded.case.caption, "Doe")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Exhibits").path))
    }

    func test_delete_and_rename() throws {
        let store = CaseStore(root: root)
        _ = try store.create(name: "A", now: "t")
        try store.rename("A", to: "B")
        XCTAssertEqual(store.list(), ["B"])
        try store.delete(name: "B")
        XCTAssertTrue(store.list().isEmpty)
    }
}
```

- [ ] **Step 2: Run — expect failure.**

- [ ] **Step 3: Implement**

```swift
import Foundation

struct CaseStore {
    let root: URL
    private let writer = CaseManifestWriter()

    init(root: URL) { self.root = root }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.root = docs.appendingPathComponent("Cases")
    }

    func url(for name: String) -> URL { root.appendingPathComponent(name) }

    func list() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.filter {
            FileManager.default.fileExists(atPath: url(for: $0).appendingPathComponent("exhibits.json").path)
        }.sorted()
    }

    @discardableResult
    func create(name: String, now: String) throws -> URL {
        let folder = url(for: name)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Exhibits"),
                                                withIntermediateDirectories: true)
        let kase = Case(contractVersion: ContractVersion.supported,
                        case: .init(caption: name, docket: "", court: ""),
                        generated: now, pathBase: "sidecar_dir", exhibits: [])
        try writer.write(kase, to: folder)
        return folder
    }

    func delete(name: String) throws { try FileManager.default.removeItem(at: url(for: name)) }
    func rename(_ name: String, to newName: String) throws {
        try FileManager.default.moveItem(at: url(for: name), to: url(for: newName))
    }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(library): CaseStore`).

---

## Task 5: ExhibitImporter

**Files:** Create `IronGavel/Library/ExhibitImporter.swift`, `IronGavelTests/Library/ExhibitImporterTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

final class ExhibitImporterTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("igimp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func srcFile(_ name: String, _ bytes: String = "x") throws -> URL {
        let u = root.appendingPathComponent(name)
        try bytes.data(using: .utf8)!.write(to: u)
        return u
    }

    func test_import_copies_files_and_creates_exhibits() throws {
        let store = CaseStore(root: root.appendingPathComponent("Cases"))
        let folder = try store.create(name: "Doe", now: "t")
        let pdf = try srcFile("photo.pdf")
        let audio = try srcFile("call.m4a")

        let updated = try ExhibitImporter().importFiles([pdf, audio], into: folder)

        XCTAssertEqual(updated.exhibits.count, 2)
        XCTAssertEqual(updated.exhibits[0].id, "D-001")
        XCTAssertEqual(updated.exhibits[0].mediaType, .pdf)
        XCTAssertEqual(updated.exhibits[0].file, "Exhibits/photo.pdf")
        XCTAssertEqual(updated.exhibits[1].id, "D-002")
        XCTAssertEqual(updated.exhibits[1].mediaType, .audio)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Exhibits/photo.pdf").path))
        // Manifest on disk reflects the import.
        XCTAssertEqual(try CaseLoader().load(folderURL: folder).exhibits.count, 2)
    }

    func test_import_dedupes_duplicate_filenames() throws {
        let store = CaseStore(root: root.appendingPathComponent("Cases"))
        let folder = try store.create(name: "Doe", now: "t")
        let a = try srcFile("dup.pdf", "a")
        _ = try ExhibitImporter().importFiles([a], into: folder)
        let b = try srcFile("dup.pdf", "b")
        let updated = try ExhibitImporter().importFiles([b], into: folder)
        XCTAssertEqual(updated.exhibits.count, 2)
        XCTAssertEqual(updated.exhibits[1].file, "Exhibits/dup 2.pdf")
    }
}
```

- [ ] **Step 2: Run — expect failure.**

- [ ] **Step 3: Implement**

```swift
import Foundation

struct ExhibitImporter {
    enum ImportError: Error { case cannotLoadCase, copyFailed(String) }

    private let writer = CaseManifestWriter()
    private let loader = CaseLoader()

    @discardableResult
    func importFiles(_ sources: [URL], into caseFolder: URL, defaultParty: Party = .defense) throws -> Case {
        let existingCase: Case
        do { existingCase = try loader.load(folderURL: caseFolder) }
        catch { throw ImportError.cannotLoadCase }

        var exhibits = existingCase.exhibits
        let exhibitsDir = caseFolder.appendingPathComponent("Exhibits")
        try FileManager.default.createDirectory(at: exhibitsDir, withIntermediateDirectories: true)

        for src in sources {
            let destName = uniqueName(for: src.lastPathComponent, in: exhibitsDir)
            let dest = exhibitsDir.appendingPathComponent(destName)
            do { try FileManager.default.copyItem(at: src, to: dest) }
            catch { throw ImportError.copyFailed(src.lastPathComponent) }

            let exhibit = Exhibit(
                id: ExhibitIDAllocator.nextID(existing: exhibits, party: defaultParty),
                party: defaultParty,
                description: (destName as NSString).deletingPathExtension,
                file: "Exhibits/\(destName)",
                witness: nil, bates: nil,
                status: .pending,
                mediaType: MediaTypeDetector.detect(url: dest),
                objection: nil, ruling: nil, notes: nil
            )
            exhibits.append(exhibit)
        }

        let updated = Case(contractVersion: existingCase.contractVersion,
                           case: existingCase.case,
                           generated: existingCase.generated,
                           pathBase: existingCase.pathBase,
                           exhibits: exhibits)
        try writer.write(updated, to: caseFolder)
        return updated
    }

    private func uniqueName(for name: String, in dir: URL) -> String {
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path) else { return name }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var i = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)"
            if !FileManager.default.fileExists(atPath: dir.appendingPathComponent(candidate).path) { return candidate }
            i += 1
        }
    }
}
```

> Note: `existingCase.case` accesses the keyword property; if the compiler objects, use `` existingCase.`case` ``.

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(library): ExhibitImporter`).

---

## Task 6: CaseLoader — Trial/exhibits.json fallback

**Files:** Modify `IronGavel/Loader/CaseLoader.swift`, add test to `IronGavelTests/CaseLoaderTests.swift`

- [ ] **Step 1: Failing test** — append to `CaseLoaderTests`:

```swift
    func test_loads_from_trial_subfolder_when_root_absent() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("igtrial-\(UUID().uuidString)")
        let trial = tmp.appendingPathComponent("Trial")
        try FileManager.default.createDirectory(at: trial, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let json = #"{"contract_version":"1.0","case":{"caption":"X","docket":"Y","court":"Z"},"generated":"t","path_base":"p","exhibits":[]}"#
        try json.data(using: .utf8)!.write(to: trial.appendingPathComponent("exhibits.json"))

        let kase = try CaseLoader().load(folderURL: tmp)
        XCTAssertEqual(kase.exhibits.count, 0)
    }
```

- [ ] **Step 2: Run — expect `missingSidecar` thrown (FAIL).**

- [ ] **Step 3: Implement** — replace the top of `CaseLoader.load(folderURL:)`:

Find:
```swift
        let sidecarURL = folderURL.appendingPathComponent("exhibits.json")

        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            throw CaseLoadError.missingSidecar(path: sidecarURL.path)
        }
```
Replace with:
```swift
        let rootSidecar = folderURL.appendingPathComponent("exhibits.json")
        let trialSidecar = folderURL.appendingPathComponent("Trial/exhibits.json")
        let sidecarURL: URL
        if FileManager.default.fileExists(atPath: rootSidecar.path) {
            sidecarURL = rootSidecar
        } else if FileManager.default.fileExists(atPath: trialSidecar.path) {
            sidecarURL = trialSidecar
        } else {
            throw CaseLoadError.missingSidecar(path: rootSidecar.path)
        }
```

- [ ] **Step 4: Run — pass; existing CaseLoader tests still pass. Step 5: Commit** (`fix(loader): fall back to Trial/exhibits.json`).

---

## Task 7: CaseBackup helper

**Files:** Create `IronGavel/Library/CaseBackup.swift`, `IronGavelTests/Library/CaseBackupTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

final class CaseBackupTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("igbak-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func test_backup_then_restore_round_trips() throws {
        let store = CaseStore(root: root.appendingPathComponent("Cases"))
        let folder = try store.create(name: "Doe", now: "t")
        let backupRoot = root.appendingPathComponent("Backups")

        let backup = try CaseBackup().backup(caseFolder: folder, to: backupRoot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("exhibits.json").path))

        try store.delete(name: "Doe")
        XCTAssertTrue(store.list().isEmpty)
        _ = try CaseBackup().restore(from: backup, to: store.root)
        XCTAssertEqual(store.list(), ["Doe"])
    }
}
```

- [ ] **Step 2: Run — expect failure.**

- [ ] **Step 3: Implement**

```swift
import Foundation

struct CaseBackup {
    @discardableResult
    func backup(caseFolder: URL, to backupRoot: URL) throws -> URL {
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let dest = backupRoot.appendingPathComponent(caseFolder.lastPathComponent)
        _ = try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: caseFolder, to: dest)
        return dest
    }

    @discardableResult
    func restore(from backupFolder: URL, to casesRoot: URL) throws -> URL {
        try FileManager.default.createDirectory(at: casesRoot, withIntermediateDirectories: true)
        let dest = casesRoot.appendingPathComponent(backupFolder.lastPathComponent)
        _ = try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: backupFolder, to: dest)
        return dest
    }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(library): CaseBackup`).

---

## Task 8: Case Library UI + wire as launch surface

**Files:** Create `IronGavel/Presenter/CaseLibraryView.swift`; Modify `IronGavel/Presenter/PresenterScene.swift`

- [ ] **Step 1: Implement `CaseLibraryView.swift`**

```swift
import SwiftUI

struct CaseLibraryView: View {
    let onOpen: (URL) -> Void
    let onOpenExternal: () -> Void

    @State private var cases: [String] = []
    @State private var showNew = false
    @State private var newName = ""
    private let store = CaseStore()

    var body: some View {
        NavigationStack {
            List {
                Section("Cases on this iPad") {
                    if cases.isEmpty {
                        Text("No cases yet. Tap + to create one.").foregroundStyle(.secondary)
                    }
                    ForEach(cases, id: \.self) { name in
                        Button(name) { onOpen(store.url(for: name)) }
                            .accessibilityIdentifier("case.row.\(name)")
                    }
                    .onDelete { offsets in
                        for i in offsets { try? store.delete(name: cases[i]) }
                        reload()
                    }
                }
                Section {
                    Button { onOpenExternal() } label: {
                        Label("Open from Files…", systemImage: "folder")
                    }
                    .accessibilityIdentifier("case.openExternal")
                }
            }
            .navigationTitle("Iron Gavel")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { newName = ""; showNew = true } label: { Image(systemName: "plus") }
                        .accessibilityIdentifier("case.new")
                }
            }
            .alert("New Case", isPresented: $showNew) {
                TextField("Case name", text: $newName).accessibilityIdentifier("case.newName")
                Button("Create", action: create)
                Button("Cancel", role: .cancel) {}
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() { cases = store.list() }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        guard let folder = try? store.create(name: name, now: now) else { return }
        reload()
        onOpen(folder)
    }
}
```

- [ ] **Step 2: Wire into PresenterScene** — replace the empty-state branch:

Find:
```swift
                if state.currentCase == nil {
                    EmptyCaseView { showFolderPicker = true }
                } else {
```
Replace with:
```swift
                if state.currentCase == nil {
                    CaseLibraryView(
                        onOpen: { url in openFolder(url, persistBookmark: true) },
                        onOpenExternal: { showFolderPicker = true }
                    )
                } else {
```

- [ ] **Step 3: Build + test** — `xcodegen generate` then test. Expected: `** TEST SUCCEEDED **`, 112 still pass. **Step 4: Commit** (`feat(presenter): in-app case library launch surface`).

---

## Task 9: Import files into the open case

**Files:** Modify `IronGavel/Presenter/PresenterToolbar.swift`, `IronGavel/Presenter/PresenterScene.swift`

- [ ] **Step 1: Add an Import action to the toolbar** — in `PresenterToolbar`, add a stored callback and button. Change the struct header:

Find:
```swift
struct PresenterToolbar: View {
    @Environment(AppState.self) private var state
    let openCaseAction: () -> Void
```
Replace with:
```swift
struct PresenterToolbar: View {
    @Environment(AppState.self) private var state
    let openCaseAction: () -> Void
    let importAction: () -> Void
```
Then add the button after the Open Case button:
```swift
            Button(action: importAction) {
                Label("Import", systemImage: "square.and.arrow.down.on.square")
            }
            .disabled(state.currentCase == nil)
            .accessibilityIdentifier("toolbar.import")
```

- [ ] **Step 2: Wire `.fileImporter` in PresenterScene** — add at the top of the file:
```swift
import UniformTypeIdentifiers
```
Add state near the other `@State`s:
```swift
    @State private var showImporter = false
```
Pass `importAction` where `PresenterToolbar` is constructed:
```swift
                PresenterToolbar(openCaseAction: { showFolderPicker = true },
                                 importAction: { showImporter = true })
```
Add the `.fileImporter` modifier next to the existing `.sheet`:
```swift
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.pdf, .image, .audiovisualContent, .audio],
                      allowsMultipleSelection: true) { result in
            handleImport(result)
        }
```
Add the handler:
```swift
    private func handleImport(_ result: Result<[URL], Error>) {
        guard let folder = state.caseFolderURL, case let .success(urls) = result else { return }
        var accessed: [URL] = []
        for u in urls where u.startAccessingSecurityScopedResource() { accessed.append(u) }
        defer { accessed.forEach { $0.stopAccessingSecurityScopedResource() } }
        do {
            let updated = try ExhibitImporter().importFiles(urls, into: folder)
            state.apply(case: updated, folder: folder)
        } catch {
            loadError = "Import failed: \(error)"
        }
    }
```

- [ ] **Step 3: Build + test** — 112 still pass (no test asserts the toolbar arity beyond compilation; `PublishFlowUITest` etc. still find their buttons). **Step 4: Commit** (`feat(presenter): import files into the open case`).

---

## Task 10: Exhibit editor

**Files:** Create `IronGavel/Presenter/ExhibitEditorSheet.swift`; Modify `IronGavel/Presenter/PreviewPane.swift`

- [ ] **Step 1: Implement `ExhibitEditorSheet.swift`**

```swift
import SwiftUI

struct ExhibitEditorSheet: View {
    let exhibit: Exhibit
    let onSave: (Exhibit) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var id: String
    @State private var party: Party
    @State private var status: ExhibitStatus
    @State private var descriptionText: String
    @State private var witness: String
    @State private var bates: String

    init(exhibit: Exhibit, onSave: @escaping (Exhibit) -> Void,
         onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.exhibit = exhibit
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _id = State(initialValue: exhibit.id)
        _party = State(initialValue: exhibit.party)
        _status = State(initialValue: exhibit.status)
        _descriptionText = State(initialValue: exhibit.description)
        _witness = State(initialValue: exhibit.witness ?? "")
        _bates = State(initialValue: exhibit.bates ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identification") {
                    TextField("Exhibit ID", text: $id).accessibilityIdentifier("editor.id")
                    Picker("Party", selection: $party) {
                        ForEach(Party.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(ExhibitStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .accessibilityIdentifier("editor.status")
                }
                Section("Details") {
                    TextField("Description", text: $descriptionText)
                    TextField("Witness", text: $witness)
                    TextField("Bates", text: $bates)
                }
                Section {
                    Button("Delete Exhibit", role: .destructive, action: onDelete)
                        .accessibilityIdentifier("editor.delete")
                }
            }
            .navigationTitle("Edit Exhibit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(updated()) }.accessibilityIdentifier("editor.save")
                }
            }
        }
    }

    private func updated() -> Exhibit {
        Exhibit(id: id, party: party, description: descriptionText, file: exhibit.file,
                witness: witness.isEmpty ? nil : witness,
                bates: bates.isEmpty ? nil : bates,
                status: status, mediaType: exhibit.mediaType,
                objection: exhibit.objection, ruling: exhibit.ruling, notes: exhibit.notes)
    }
}
```

- [ ] **Step 2: Wire into PreviewPane** — add state + writer near the top:
```swift
    @State private var showEditor = false
    private let manifestWriter = CaseManifestWriter()
```
Add an edit button in `header(for:)` before the disposition button:
```swift
            Button { showEditor = true } label: {
                Label("Edit Exhibit", systemImage: "pencil").labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("exhibit.edit")
```
Add the sheet next to the disposition `.sheet`:
```swift
        .sheet(isPresented: $showEditor) {
            if let ex = state.selectedExhibit {
                ExhibitEditorSheet(
                    exhibit: ex,
                    onSave: { edited in showEditor = false; updateExhibit(original: ex, edited: edited) },
                    onDelete: { showEditor = false; deleteExhibit(ex) },
                    onCancel: { showEditor = false }
                )
            }
        }
```
Add the persistence helpers:
```swift
    private func updateExhibit(original: Exhibit, edited: Exhibit) {
        guard let folder = state.caseFolderURL, let kase = state.currentCase else { return }
        let exhibits = kase.exhibits.map { $0.file == original.file ? edited : $0 }
        persist(kase: kase, exhibits: exhibits, folder: folder, select: edited)
    }

    private func deleteExhibit(_ ex: Exhibit) {
        guard let folder = state.caseFolderURL, let kase = state.currentCase else { return }
        let exhibits = kase.exhibits.filter { $0.file != ex.file }
        persist(kase: kase, exhibits: exhibits, folder: folder, select: nil)
    }

    private func persist(kase: Case, exhibits: [Exhibit], folder: URL, select: Exhibit?) {
        let updated = Case(contractVersion: kase.contractVersion, case: kase.case,
                           generated: kase.generated, pathBase: kase.pathBase, exhibits: exhibits)
        try? manifestWriter.write(updated, to: folder)
        state.apply(case: updated, folder: folder)
        state.selectedExhibit = select
    }
```

> Note: `kase.case` — use `` kase.`case` `` if the compiler objects.

- [ ] **Step 3: Build + test** — 112 still pass. **Step 4: Commit** (`feat(presenter): in-app exhibit editor (metadata + status + delete)`).

---

## Task 11: Library UI smoke test

**Files:** Modify `IronGavel/App/IronGavelApp.swift`; Create `IronGavelUITests/CaseLibraryUITest.swift`

- [ ] **Step 1: Add a fresh-launch arg** — in `IronGavelApp.swift`, inside `loadUITestFixtureIfRequested()` add at the very top:
```swift
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reset") {
            BookmarkStore().clear()
            return
        }
```
This skips fixture + bookmark restore so the Case Library shows.

- [ ] **Step 2: Write the UI test**

```swift
import XCTest

final class CaseLibraryUITest: XCTestCase {
    func test_create_case_opens_presenter() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset"]
        app.launch()

        let newButton = app.buttons["case.new"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 10))
        newButton.tap()

        let nameField = app.textFields["case.newName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Smoke Case")
        app.buttons["Create"].tap()

        // The case opens into the presenter (toolbar + import button appear).
        XCTAssertTrue(app.buttons["toolbar.import"].waitForExistence(timeout: 10))
    }
}
```

- [ ] **Step 3: Build + test** — `xcodegen generate` then full test. Expected all pass (≥ 113 + new). **Step 4: Commit** (`test(library): UI smoke for create-case flow`).

> The fileImporter and editor are system/sheet-driven and covered by unit tests + manual; the smoke test verifies the new launch flow end-to-end.

---

## Done criteria
- Launch shows the Case Library; create a case → it opens.
- Import files → they appear as exhibits with correct media types and auto IDs.
- Edit an exhibit (incl. status) → persists; publish gate honors the new status.
- External `dw-exhibit-manager` folders still open (and `Trial/exhibits.json` is auto-found).
- All existing tests stay green. Then run **superpowers:finishing-a-development-branch**.
```
