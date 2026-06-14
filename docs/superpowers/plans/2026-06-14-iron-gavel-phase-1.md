# Iron Gavel — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iPad trial-presentation app that loads a case from iCloud Drive via the `exhibits.json` v1.0 sidecar, lets the attorney browse exhibits, preview PDFs and images, publish admitted exhibits to a USB-C-attached jury display, and toggle Blank Screen.

**Architecture:** Single SwiftUI app with two `WindowGroup` scenes (presenter + external jury). Shared `@Observable AppState` drives both. PDF rendering via `PDFKit` wrapped in `UIViewRepresentable`. Case files read from an iCloud-Drive folder picked once and stored as a security-scoped bookmark. The app is read-only; the `dw-exhibit-manager-crim` skill regenerates the sidecar on the Mac and iCloud sync delivers updates.

**Tech Stack:** Swift 5.9+, SwiftUI, PDFKit, UIKit (`UIWindowScene`, `UIDocumentPickerViewController`, `NSFileCoordinator`, `NSFilePresenter`), XCTest, XCUITest. iPadOS 17+. Personal-team dev signing in Xcode.

**Reference:** `docs/superpowers/specs/2026-06-14-iron-gavel-phase-1-design.md` and `exhibits.schema.json` (frozen v1.0).

---

## File Structure

All paths are relative to repo root.

**Xcode project (created in Task 1):**
- `IronGavel.xcodeproj/` — Xcode project
- `IronGavel/Resources/Info.plist` — scene manifest

**Model layer:**
- `IronGavel/Model/ContractVersion.swift` — supported sidecar version
- `IronGavel/Model/Party.swift` — `Defense | State | Joint | Court`
- `IronGavel/Model/ExhibitStatus.swift` — `pending | offered | objected | admitted | excluded`
- `IronGavel/Model/MediaType.swift` — `pdf | image | video | unknown`
- `IronGavel/Model/Exhibit.swift` — value type matching schema
- `IronGavel/Model/Case.swift` — `contract_version`, `case` block, `generated`, `path_base`, `exhibits`

**Loader layer:**
- `IronGavel/Loader/CaseLoadError.swift`
- `IronGavel/Loader/CaseLoader.swift`
- `IronGavel/Loader/BookmarkStore.swift`
- `IronGavel/Loader/CaseWatcher.swift`

**State layer:**
- `IronGavel/State/JuryDisplay.swift` — enum `.empty | .blank | .exhibit(Exhibit, page: Int)`
- `IronGavel/State/AppState.swift` — `@Observable`

**App shell:**
- `IronGavel/App/IronGavelApp.swift` — `@main`
- `IronGavel/App/AppDelegate.swift` — `UIApplicationDelegate`, scene configuration
- `IronGavel/App/JurySceneDelegate.swift` — owns external `UIWindowScene`

**Presenter UI:**
- `IronGavel/Presenter/PresenterScene.swift`
- `IronGavel/Presenter/ExhibitSidebar.swift`
- `IronGavel/Presenter/PreviewPane.swift`
- `IronGavel/Presenter/PresenterToolbar.swift`
- `IronGavel/Presenter/StatusBadge.swift`

**Jury UI:**
- `IronGavel/Jury/JuryView.swift`
- `IronGavel/Jury/BlankView.swift`

**Rendering:**
- `IronGavel/Rendering/ExhibitRenderer.swift` (protocol)
- `IronGavel/Rendering/PDFDocumentCache.swift`
- `IronGavel/Rendering/PDFPreview.swift`
- `IronGavel/Rendering/PDFJuryView.swift`
- `IronGavel/Rendering/ImagePreview.swift`
- `IronGavel/Rendering/ImageJuryView.swift`

**Tests:**
- `IronGavelTests/CaseLoaderTests.swift`
- `IronGavelTests/ContractVersionTests.swift`
- `IronGavelTests/AppStateTests.swift`
- `IronGavelTests/JuryDisplayTests.swift`
- `IronGavelTests/BookmarkStoreTests.swift`
- `IronGavelUITests/PublishFlowUITest.swift`
- `IronGavelTests/Fixtures/Trial/exhibits.json`
- `IronGavelTests/Fixtures/Trial/Exhibits_Admitted/sample-admitted.pdf`
- `IronGavelTests/Fixtures/Trial/Exhibits_Pending/sample-pending.pdf`

---

## Task 1: Create Xcode project skeleton

**Files:**
- Create: `IronGavel.xcodeproj/` (via Xcode)
- Create: `IronGavel/App/IronGavelApp.swift`
- Create: `IronGavel/Resources/Info.plist`
- Create: `.gitignore`

- [ ] **Step 1: Create the Xcode project**

In Xcode → File → New → Project → iOS → App.
- Product Name: `IronGavel`
- Team: Personal Team (your Apple ID)
- Organization Identifier: `com.danielswashington.irongavel`
- Interface: SwiftUI
- Language: Swift
- Include Tests: YES (creates `IronGavelTests` and `IronGavelUITests` targets)
- Save under the repo root (next to `docs/`, `exhibits.schema.json`).

After creation, set Deployment Target to **iPadOS 17.0**. In project settings → Targets → IronGavel → General → Supported Destinations: keep iPad, remove iPhone and Mac.

- [ ] **Step 2: Replace the generated `IronGavelApp.swift` with a stub**

Replace `IronGavel/IronGavelApp.swift` with:

```swift
import SwiftUI

@main
struct IronGavelApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Iron Gavel")
        }
    }
}
```

- [ ] **Step 3: Add `.gitignore`**

Create `.gitignore` in the repo root:

```
# macOS
.DS_Store

# Xcode
build/
DerivedData/
*.xcuserstate
*.xcuserdatad/
xcuserdata/
*.xcscmblueprint
*.xccheckout

# Swift Package Manager
.swiftpm/
Packages/
Package.resolved
.build/

# CocoaPods (not used, but defensive)
Pods/

# Carthage (not used, but defensive)
Carthage/Build/
```

- [ ] **Step 4: Build to confirm the project compiles**

Run: in Xcode, ⌘B.
Expected: **Build Succeeded**.

- [ ] **Step 5: Commit**

```bash
git add IronGavel.xcodeproj IronGavel .gitignore
git commit -m "chore: scaffold IronGavel iPad SwiftUI app"
```

---

## Task 2: Model — ContractVersion, Party, ExhibitStatus, MediaType

**Files:**
- Create: `IronGavel/Model/ContractVersion.swift`
- Create: `IronGavel/Model/Party.swift`
- Create: `IronGavel/Model/ExhibitStatus.swift`
- Create: `IronGavel/Model/MediaType.swift`
- Create: `IronGavelTests/ContractVersionTests.swift`

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/ContractVersionTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class ContractVersionTests: XCTestCase {
    func test_supported_version_is_one_point_zero() {
        XCTAssertEqual(ContractVersion.supported, "1.0")
    }

    func test_party_decodes_from_lowercase_json_values() throws {
        let json = #"["Defense","State","Joint","Court"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([Party].self, from: json)
        XCTAssertEqual(decoded, [.defense, .state, .joint, .court])
    }

    func test_exhibit_status_decodes_all_cases() throws {
        let json = #"["pending","offered","objected","admitted","excluded"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([ExhibitStatus].self, from: json)
        XCTAssertEqual(decoded, [.pending, .offered, .objected, .admitted, .excluded])
    }

    func test_media_type_decodes_all_cases() throws {
        let json = #"["pdf","image","video","unknown"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([MediaType].self, from: json)
        XCTAssertEqual(decoded, [.pdf, .image, .video, .unknown])
    }
}
```

In Xcode add the file to the `IronGavelTests` target (File Inspector → Target Membership).

- [ ] **Step 2: Run test — verify it fails**

Run: ⌘U in Xcode (or `xcodebuild test -scheme IronGavel -destination 'platform=iOS Simulator,name=iPad (10th generation)'`).
Expected: FAIL — `Cannot find 'ContractVersion' in scope`.

- [ ] **Step 3: Write `ContractVersion.swift`**

Create `IronGavel/Model/ContractVersion.swift`:

```swift
import Foundation

enum ContractVersion {
    static let supported = "1.0"
}
```

- [ ] **Step 4: Write `Party.swift`**

Create `IronGavel/Model/Party.swift`:

```swift
import Foundation

enum Party: String, Codable, CaseIterable, Hashable {
    case defense = "Defense"
    case state = "State"
    case joint = "Joint"
    case court = "Court"
}
```

- [ ] **Step 5: Write `ExhibitStatus.swift`**

Create `IronGavel/Model/ExhibitStatus.swift`:

```swift
import Foundation

enum ExhibitStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case offered
    case objected
    case admitted
    case excluded
}
```

- [ ] **Step 6: Write `MediaType.swift`**

Create `IronGavel/Model/MediaType.swift`:

```swift
import Foundation

enum MediaType: String, Codable, CaseIterable, Hashable {
    case pdf
    case image
    case video
    case unknown
}
```

In Xcode add all four new files to the `IronGavel` (app) target.

- [ ] **Step 7: Run test — verify it passes**

Run: ⌘U.
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add IronGavel/Model IronGavelTests/ContractVersionTests.swift
git commit -m "feat: add ContractVersion, Party, ExhibitStatus, MediaType enums"
```

---

## Task 3: Model — Exhibit and Case

**Files:**
- Create: `IronGavel/Model/Exhibit.swift`
- Create: `IronGavel/Model/Case.swift`
- Modify: `IronGavelTests/Fixtures/Trial/exhibits.json` (new fixture)
- Create: `IronGavelTests/CaseDecodeTests.swift`

- [ ] **Step 1: Add a fixture sidecar**

Create `IronGavelTests/Fixtures/Trial/exhibits.json`:

```json
{
  "contract_version": "1.0",
  "case": {
    "caption": "State v. Doe",
    "docket": "2026-CR-00042",
    "court": "14th JDC, Calcasieu Parish"
  },
  "generated": "2026-06-14T09:00:00-05:00",
  "path_base": "sidecar_dir",
  "exhibits": [
    {
      "id": "D-001",
      "party": "Defense",
      "description": "Photo of intersection",
      "file": "Exhibits_Admitted/d001-intersection.pdf",
      "status": "admitted",
      "media_type": "pdf",
      "witness": "Off. Smith",
      "bates": "DEF0001",
      "objection": "",
      "ruling": "Overruled",
      "notes": ""
    },
    {
      "id": "S-014",
      "party": "State",
      "description": "Pending body cam clip",
      "file": "Exhibits_Pending/s014-clip.pdf",
      "status": "pending",
      "media_type": "pdf",
      "witness": "",
      "bates": "",
      "objection": "",
      "ruling": "",
      "notes": ""
    }
  ]
}
```

Add the file to `IronGavelTests` target. In Build Phases → Copy Bundle Resources, ensure it's listed.

- [ ] **Step 2: Write the failing test**

Create `IronGavelTests/CaseDecodeTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class CaseDecodeTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(bundle.url(forResource: "exhibits", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func test_decodes_fixture_sidecar() throws {
        let data = try fixtureData()
        let kase = try JSONDecoder().decode(Case.self, from: data)
        XCTAssertEqual(kase.contractVersion, "1.0")
        XCTAssertEqual(kase.case.caption, "State v. Doe")
        XCTAssertEqual(kase.case.docket, "2026-CR-00042")
        XCTAssertEqual(kase.pathBase, "sidecar_dir")
        XCTAssertEqual(kase.exhibits.count, 2)

        let d001 = kase.exhibits[0]
        XCTAssertEqual(d001.id, "D-001")
        XCTAssertEqual(d001.party, .defense)
        XCTAssertEqual(d001.status, .admitted)
        XCTAssertEqual(d001.mediaType, .pdf)
        XCTAssertEqual(d001.file, "Exhibits_Admitted/d001-intersection.pdf")
    }
}
```

- [ ] **Step 3: Run test — verify it fails**

Run: ⌘U. Expected: FAIL — `Cannot find 'Case' in scope`.

- [ ] **Step 4: Implement `Exhibit.swift`**

Create `IronGavel/Model/Exhibit.swift`:

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

    enum CodingKeys: String, CodingKey {
        case id, party, description, file, witness, bates, status
        case mediaType = "media_type"
        case objection, ruling, notes
    }
}
```

- [ ] **Step 5: Implement `Case.swift`**

Create `IronGavel/Model/Case.swift`:

```swift
import Foundation

struct Case: Codable, Hashable {
    let contractVersion: String
    let `case`: CaseIdentity
    let generated: String
    let pathBase: String
    let exhibits: [Exhibit]

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case `case`
        case generated
        case pathBase = "path_base"
        case exhibits
    }
}

struct CaseIdentity: Codable, Hashable {
    let caption: String
    let docket: String
    let court: String
}
```

Add both files to the `IronGavel` target.

- [ ] **Step 6: Run test — verify it passes**

Run: ⌘U. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add IronGavel/Model IronGavelTests/CaseDecodeTests.swift IronGavelTests/Fixtures
git commit -m "feat: add Exhibit and Case Codable types matching schema v1.0"
```

---

## Task 4: CaseLoadError and CaseLoader (happy path)

**Files:**
- Create: `IronGavel/Loader/CaseLoadError.swift`
- Create: `IronGavel/Loader/CaseLoader.swift`
- Create: `IronGavelTests/CaseLoaderTests.swift`

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/CaseLoaderTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class CaseLoaderTests: XCTestCase {
    private func fixtureFolderURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let jsonURL = try XCTUnwrap(bundle.url(forResource: "exhibits", withExtension: "json"))
        return jsonURL.deletingLastPathComponent()
    }

    func test_loads_fixture_case_successfully() throws {
        let loader = CaseLoader()
        let kase = try loader.load(folderURL: try fixtureFolderURL())
        XCTAssertEqual(kase.contractVersion, "1.0")
        XCTAssertEqual(kase.exhibits.count, 2)
    }

    func test_missing_sidecar_throws() {
        let loader = CaseLoader()
        let bogus = URL(fileURLWithPath: "/tmp/iron-gavel-nonexistent-\(UUID().uuidString)")
        XCTAssertThrowsError(try loader.load(folderURL: bogus)) { err in
            guard case CaseLoadError.missingSidecar = err else {
                return XCTFail("expected .missingSidecar, got \(err)")
            }
        }
    }
}
```

- [ ] **Step 2: Run test — verify it fails**

Run: ⌘U. Expected: FAIL — `Cannot find 'CaseLoader' in scope`.

- [ ] **Step 3: Implement `CaseLoadError.swift`**

Create `IronGavel/Loader/CaseLoadError.swift`:

```swift
import Foundation

enum CaseLoadError: Error, Equatable {
    case missingSidecar(path: String)
    case decodeFailed(message: String)
    case unsupportedContractVersion(found: String, supported: String)
    case fileAccessDenied(path: String)
}
```

- [ ] **Step 4: Implement `CaseLoader.swift` (happy path + missing sidecar)**

Create `IronGavel/Loader/CaseLoader.swift`:

```swift
import Foundation

struct CaseLoader {
    func load(folderURL: URL) throws -> Case {
        let sidecarURL = folderURL.appendingPathComponent("exhibits.json")

        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            throw CaseLoadError.missingSidecar(path: sidecarURL.path)
        }

        let data: Data
        do {
            data = try readCoordinated(url: sidecarURL)
        } catch {
            throw CaseLoadError.fileAccessDenied(path: sidecarURL.path)
        }

        let kase: Case
        do {
            kase = try JSONDecoder().decode(Case.self, from: data)
        } catch {
            throw CaseLoadError.decodeFailed(message: String(describing: error))
        }

        guard kase.contractVersion == ContractVersion.supported else {
            throw CaseLoadError.unsupportedContractVersion(
                found: kase.contractVersion,
                supported: ContractVersion.supported
            )
        }

        return kase
    }

    private func readCoordinated(url: URL) throws -> Data {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        var data: Data?
        var readError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordinatedURL in
            do {
                data = try Data(contentsOf: coordinatedURL)
            } catch {
                readError = error
            }
        }
        if let coordError { throw coordError }
        if let readError { throw readError }
        return data ?? Data()
    }
}
```

Add both files to the `IronGavel` target.

- [ ] **Step 5: Run test — verify it passes**

Run: ⌘U. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add IronGavel/Loader IronGavelTests/CaseLoaderTests.swift
git commit -m "feat: add CaseLoader happy path + missing-sidecar error"
```

---

## Task 5: CaseLoader — contract version and decode errors

**Files:**
- Modify: `IronGavelTests/CaseLoaderTests.swift`
- Create: `IronGavelTests/Fixtures/BadVersion/exhibits.json`
- Create: `IronGavelTests/Fixtures/BadJSON/exhibits.json`

- [ ] **Step 1: Add the bad-version fixture**

Create `IronGavelTests/Fixtures/BadVersion/exhibits.json` (same body as Task 3 fixture but with `"contract_version": "2.0"`):

```json
{
  "contract_version": "2.0",
  "case": { "caption": "X", "docket": "Y", "court": "Z" },
  "generated": "2026-06-14T09:00:00-05:00",
  "path_base": "sidecar_dir",
  "exhibits": []
}
```

- [ ] **Step 2: Add the bad-JSON fixture**

Create `IronGavelTests/Fixtures/BadJSON/exhibits.json`:

```
{ this is not valid json
```

Both files must be added to the test target's Copy Bundle Resources phase. To keep them addressable distinctly, put them in named subdirectories under a single test resource folder (Xcode will preserve the subdirectory if you add the parent as a *folder reference*, blue icon). Drag `Fixtures/BadVersion` and `Fixtures/BadJSON` into Xcode and select "Create folder references".

- [ ] **Step 3: Write the failing tests**

Append to `IronGavelTests/CaseLoaderTests.swift`:

```swift
extension CaseLoaderTests {
    private func resourceFolder(named name: String) throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: nil))
        return url
    }

    func test_unsupported_contract_version_throws() throws {
        let loader = CaseLoader()
        let folder = try resourceFolder(named: "BadVersion")
        XCTAssertThrowsError(try loader.load(folderURL: folder)) { err in
            guard case let CaseLoadError.unsupportedContractVersion(found, supported) = err else {
                return XCTFail("expected .unsupportedContractVersion, got \(err)")
            }
            XCTAssertEqual(found, "2.0")
            XCTAssertEqual(supported, "1.0")
        }
    }

    func test_bad_json_throws_decode_failed() throws {
        let loader = CaseLoader()
        let folder = try resourceFolder(named: "BadJSON")
        XCTAssertThrowsError(try loader.load(folderURL: folder)) { err in
            guard case CaseLoadError.decodeFailed = err else {
                return XCTFail("expected .decodeFailed, got \(err)")
            }
        }
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

The loader from Task 4 already handles both cases. Run: ⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add IronGavelTests
git commit -m "test: cover CaseLoader version and decode errors"
```

---

## Task 6: BookmarkStore

**Files:**
- Create: `IronGavel/Loader/BookmarkStore.swift`
- Create: `IronGavelTests/BookmarkStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/BookmarkStoreTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class BookmarkStoreTests: XCTestCase {
    private let key = "test.bookmark.\(UUID().uuidString)"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "iron-gavel-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description)
        defaults = nil
        super.tearDown()
    }

    func test_stores_and_retrieves_bookmark_data() throws {
        let store = BookmarkStore(defaults: defaults, key: key)
        let bookmark = Data([0x01, 0x02, 0x03])
        store.save(bookmark)
        XCTAssertEqual(store.load(), bookmark)
    }

    func test_returns_nil_when_no_bookmark_stored() {
        let store = BookmarkStore(defaults: defaults, key: key)
        XCTAssertNil(store.load())
    }

    func test_clear_removes_stored_bookmark() {
        let store = BookmarkStore(defaults: defaults, key: key)
        store.save(Data([0xFF]))
        store.clear()
        XCTAssertNil(store.load())
    }
}
```

- [ ] **Step 2: Run test — verify it fails**

Run: ⌘U. Expected: FAIL — `Cannot find 'BookmarkStore' in scope`.

- [ ] **Step 3: Implement `BookmarkStore.swift`**

Create `IronGavel/Loader/BookmarkStore.swift`:

```swift
import Foundation

struct BookmarkStore {
    static let defaultKey = "iron-gavel.lastCaseBookmark"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = BookmarkStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func save(_ data: Data) {
        defaults.set(data, forKey: key)
    }

    func load() -> Data? {
        defaults.data(forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
```

Add to the `IronGavel` target.

- [ ] **Step 4: Run test — verify it passes**

Run: ⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/Loader/BookmarkStore.swift IronGavelTests/BookmarkStoreTests.swift
git commit -m "feat: add BookmarkStore for security-scoped folder bookmarks"
```

---

## Task 7: JuryDisplay enum

**Files:**
- Create: `IronGavel/State/JuryDisplay.swift`
- Create: `IronGavelTests/JuryDisplayTests.swift`

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/JuryDisplayTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class JuryDisplayTests: XCTestCase {
    private func makeExhibit(id: String = "D-001", status: ExhibitStatus = .admitted) -> Exhibit {
        Exhibit(
            id: id,
            party: .defense,
            description: "x",
            file: "f.pdf",
            witness: nil,
            bates: nil,
            status: status,
            mediaType: .pdf,
            objection: nil,
            ruling: nil,
            notes: nil
        )
    }

    func test_equality_distinguishes_states() {
        let e = makeExhibit()
        XCTAssertEqual(JuryDisplay.empty, .empty)
        XCTAssertEqual(JuryDisplay.blank, .blank)
        XCTAssertEqual(JuryDisplay.exhibit(e, page: 0), .exhibit(e, page: 0))
        XCTAssertNotEqual(JuryDisplay.exhibit(e, page: 0), .exhibit(e, page: 1))
    }

    func test_currentExhibit_returns_exhibit_only_when_displayed() {
        let e = makeExhibit()
        XCTAssertNil(JuryDisplay.empty.currentExhibit)
        XCTAssertNil(JuryDisplay.blank.currentExhibit)
        XCTAssertEqual(JuryDisplay.exhibit(e, page: 2).currentExhibit?.id, "D-001")
    }
}
```

- [ ] **Step 2: Run test — verify it fails**

Run: ⌘U. Expected: FAIL — `Cannot find 'JuryDisplay' in scope`.

- [ ] **Step 3: Implement `JuryDisplay.swift`**

Create `IronGavel/State/JuryDisplay.swift`:

```swift
import Foundation

enum JuryDisplay: Equatable {
    case empty
    case blank
    case exhibit(Exhibit, page: Int)

    var currentExhibit: Exhibit? {
        if case let .exhibit(e, _) = self { return e }
        return nil
    }

    var currentPage: Int? {
        if case let .exhibit(_, page) = self { return page }
        return nil
    }
}
```

Add to the `IronGavel` target.

- [ ] **Step 4: Run test — verify it passes**

Run: ⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/State/JuryDisplay.swift IronGavelTests/JuryDisplayTests.swift
git commit -m "feat: add JuryDisplay enum"
```

---

## Task 8: AppState — publish gate, blank, restore, auto-blank

**Files:**
- Create: `IronGavel/State/AppState.swift`
- Create: `IronGavelTests/AppStateTests.swift`

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/AppStateTests.swift`:

```swift
import XCTest
@testable import IronGavel

@MainActor
final class AppStateTests: XCTestCase {
    private func exhibit(_ id: String, status: ExhibitStatus, file: String = "f.pdf") -> Exhibit {
        Exhibit(
            id: id, party: .defense, description: id,
            file: file, witness: nil, bates: nil,
            status: status, mediaType: .pdf,
            objection: nil, ruling: nil, notes: nil
        )
    }

    private func makeCase(_ exhibits: [Exhibit]) -> Case {
        Case(
            contractVersion: "1.0",
            case: .init(caption: "X", docket: "Y", court: "Z"),
            generated: "2026-06-14T00:00:00-05:00",
            pathBase: "sidecar_dir",
            exhibits: exhibits
        )
    }

    func test_publish_admitted_exhibit_sets_jury_display() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()
        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 0))
    }

    func test_publish_non_admitted_exhibit_is_no_op() {
        let pending = exhibit("S-014", status: .pending)
        let state = AppState()
        state.apply(case: makeCase([pending]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(pending)
        state.publishSelected()
        XCTAssertEqual(state.juryDisplay, .empty)
    }

    func test_blank_then_restore_returns_to_last_published() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()
        state.setPage(3)
        state.blank()
        XCTAssertEqual(state.juryDisplay, .blank)
        state.restore()
        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 3))
    }

    func test_status_downgrade_on_published_exhibit_auto_blanks() {
        let admitted = exhibit("D-001", status: .admitted)
        let downgraded = exhibit("D-001", status: .objected)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        state.apply(case: makeCase([downgraded]), folder: URL(fileURLWithPath: "/tmp"))

        XCTAssertEqual(state.juryDisplay, .blank)
        XCTAssertNotNil(state.lastStatusBanner)
        XCTAssertTrue(state.lastStatusBanner?.contains("D-001") ?? false)
    }

    func test_status_change_on_non_published_exhibit_does_not_blank() {
        let admitted = exhibit("D-001", status: .admitted)
        let other = exhibit("S-014", status: .pending)
        let otherChanged = exhibit("S-014", status: .objected)
        let state = AppState()
        state.apply(case: makeCase([admitted, other]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        state.apply(case: makeCase([admitted, otherChanged]), folder: URL(fileURLWithPath: "/tmp"))

        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 0))
        XCTAssertNil(state.lastStatusBanner)
    }
}
```

- [ ] **Step 2: Run test — verify it fails**

Run: ⌘U. Expected: FAIL — `Cannot find 'AppState' in scope`.

- [ ] **Step 3: Implement `AppState.swift`**

Create `IronGavel/State/AppState.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private(set) var currentCase: Case?
    private(set) var caseFolderURL: URL?
    var selectedExhibit: Exhibit?
    private(set) var juryDisplay: JuryDisplay = .empty
    private(set) var lastPublished: (exhibit: Exhibit, page: Int)?
    var externalConnected: Bool = false
    var lastStatusBanner: String?

    func apply(case kase: Case, folder: URL) {
        let previousCase = self.currentCase
        self.currentCase = kase
        self.caseFolderURL = folder

        if let previousCase, case let .exhibit(published, _) = juryDisplay {
            let updated = kase.exhibits.first(where: { $0.id == published.id })
            if let updated, updated.status != .admitted, published.status == .admitted {
                juryDisplay = .blank
                lastStatusBanner = "Exhibit \(published.id) status changed to \(updated.status.rawValue). Jury display blanked."
            }
            _ = previousCase
        }
    }

    func select(_ exhibit: Exhibit) {
        selectedExhibit = exhibit
    }

    func publishSelected() {
        guard let exhibit = selectedExhibit, exhibit.status == .admitted else { return }
        let display: JuryDisplay = .exhibit(exhibit, page: 0)
        juryDisplay = display
        lastPublished = (exhibit, 0)
        lastStatusBanner = nil
    }

    func setPage(_ page: Int) {
        if case let .exhibit(exhibit, _) = juryDisplay {
            juryDisplay = .exhibit(exhibit, page: page)
            lastPublished = (exhibit, page)
        }
    }

    func blank() {
        juryDisplay = .blank
    }

    func restore() {
        if let last = lastPublished {
            juryDisplay = .exhibit(last.exhibit, page: last.page)
        }
    }

    func dismissBanner() {
        lastStatusBanner = nil
    }
}
```

Add to the `IronGavel` target.

- [ ] **Step 4: Run test — verify it passes**

Run: ⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/State/AppState.swift IronGavelTests/AppStateTests.swift
git commit -m "feat: add AppState with publish gate, blank, restore, auto-blank"
```

---

## Task 9: PDFDocumentCache and rendering protocol

**Files:**
- Create: `IronGavel/Rendering/ExhibitRenderer.swift`
- Create: `IronGavel/Rendering/PDFDocumentCache.swift`

- [ ] **Step 1: Implement `ExhibitRenderer.swift`**

Create `IronGavel/Rendering/ExhibitRenderer.swift`:

```swift
import Foundation
import SwiftUI

protocol ExhibitRenderer {
    associatedtype Body: View
    func makeView(fileURL: URL, isPresenter: Bool, page: Binding<Int>) -> Body
}
```

- [ ] **Step 2: Implement `PDFDocumentCache.swift`**

Create `IronGavel/Rendering/PDFDocumentCache.swift`:

```swift
import Foundation
import PDFKit

final class PDFDocumentCache {
    static let shared = PDFDocumentCache()

    private let cache = NSCache<NSURL, PDFDocument>()

    func document(for url: URL) -> PDFDocument? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let doc = PDFDocument(url: url) else { return nil }
        cache.setObject(doc, forKey: url as NSURL)
        return doc
    }

    func evict(_ url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}
```

Add both to the `IronGavel` target. Build with ⌘B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add IronGavel/Rendering
git commit -m "feat: add ExhibitRenderer protocol and PDFDocumentCache"
```

---

## Task 10: PDF preview and jury PDF view

**Files:**
- Create: `IronGavel/Rendering/PDFPreview.swift`
- Create: `IronGavel/Rendering/PDFJuryView.swift`

- [ ] **Step 1: Implement `PDFPreview.swift`**

Create `IronGavel/Rendering/PDFPreview.swift`:

```swift
import SwiftUI
import PDFKit

struct PDFPreview: UIViewRepresentable {
    let fileURL: URL
    @Binding var pageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.document = PDFDocumentCache.shared.document(for: fileURL)
        goToPage(in: view, index: pageIndex)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != fileURL {
            view.document = PDFDocumentCache.shared.document(for: fileURL)
        }
        goToPage(in: view, index: pageIndex)
    }

    private func goToPage(in view: PDFView, index: Int) {
        guard let doc = view.document, index >= 0, index < doc.pageCount,
              let page = doc.page(at: index) else { return }
        if view.currentPage != page {
            view.go(to: page)
        }
    }
}
```

- [ ] **Step 2: Implement `PDFJuryView.swift`**

Create `IronGavel/Rendering/PDFJuryView.swift`:

```swift
import SwiftUI
import PDFKit

struct PDFJuryView: UIViewRepresentable {
    let fileURL: URL
    let pageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.backgroundColor = .black
        view.document = PDFDocumentCache.shared.document(for: fileURL)
        goToPage(in: view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != fileURL {
            view.document = PDFDocumentCache.shared.document(for: fileURL)
        }
        goToPage(in: view)
    }

    private func goToPage(in view: PDFView) {
        guard let doc = view.document, pageIndex >= 0, pageIndex < doc.pageCount,
              let page = doc.page(at: pageIndex) else { return }
        view.go(to: page)
    }
}
```

Add both files to the `IronGavel` target. Build with ⌘B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add IronGavel/Rendering/PDFPreview.swift IronGavel/Rendering/PDFJuryView.swift
git commit -m "feat: add PDFPreview and PDFJuryView SwiftUI wrappers"
```

---

## Task 11: Image preview and jury image view

**Files:**
- Create: `IronGavel/Rendering/ImagePreview.swift`
- Create: `IronGavel/Rendering/ImageJuryView.swift`

- [ ] **Step 1: Implement `ImagePreview.swift`**

Create `IronGavel/Rendering/ImagePreview.swift`:

```swift
import SwiftUI

struct ImagePreview: View {
    let fileURL: URL

    var body: some View {
        if let image = UIImage(contentsOfFile: fileURL.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Text("Cannot render this image\n\(fileURL.path)")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}
```

- [ ] **Step 2: Implement `ImageJuryView.swift`**

Create `IronGavel/Rendering/ImageJuryView.swift`:

```swift
import SwiftUI

struct ImageJuryView: View {
    let fileURL: URL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
```

Add both to the `IronGavel` target. Build with ⌘B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add IronGavel/Rendering/ImagePreview.swift IronGavel/Rendering/ImageJuryView.swift
git commit -m "feat: add image preview and jury image view"
```

---

## Task 12: BlankView and JuryView

**Files:**
- Create: `IronGavel/Jury/BlankView.swift`
- Create: `IronGavel/Jury/JuryView.swift`

- [ ] **Step 1: Implement `BlankView.swift`**

Create `IronGavel/Jury/BlankView.swift`:

```swift
import SwiftUI

struct BlankView: View {
    var body: some View {
        Color.black.ignoresSafeArea()
    }
}
```

- [ ] **Step 2: Implement `JuryView.swift`**

Create `IronGavel/Jury/JuryView.swift`:

```swift
import SwiftUI

struct JuryView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .accessibilityIdentifier("jury.view")
    }

    @ViewBuilder
    private var content: some View {
        switch state.juryDisplay {
        case .empty:
            EmptyView()
        case .blank:
            BlankView()
        case let .exhibit(exhibit, page):
            if let fileURL = resolvedURL(for: exhibit) {
                switch exhibit.mediaType {
                case .pdf:
                    PDFJuryView(fileURL: fileURL, pageIndex: page)
                case .image:
                    ImageJuryView(fileURL: fileURL)
                case .video, .unknown:
                    BlankView()
                }
            } else {
                BlankView()
            }
        }
    }

    private func resolvedURL(for exhibit: Exhibit) -> URL? {
        guard let folder = state.caseFolderURL else { return nil }
        return folder.appendingPathComponent(exhibit.file)
    }
}
```

Add both to the `IronGavel` target. Build with ⌘B. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add IronGavel/Jury
git commit -m "feat: add JuryView and BlankView driven by AppState.juryDisplay"
```

---

## Task 13: StatusBadge

**Files:**
- Create: `IronGavel/Presenter/StatusBadge.swift`

- [ ] **Step 1: Implement `StatusBadge.swift`**

Create `IronGavel/Presenter/StatusBadge.swift`:

```swift
import SwiftUI

struct StatusBadge: View {
    let status: ExhibitStatus

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .accessibilityIdentifier("status.badge.\(status.rawValue)")
    }

    private var background: Color {
        switch status {
        case .pending:  return .gray
        case .offered:  return .blue
        case .objected: return .orange
        case .admitted: return .green
        case .excluded: return .red
        }
    }
}
```

Add to the `IronGavel` target. Build. Expected: succeeds.

- [ ] **Step 2: Commit**

```bash
git add IronGavel/Presenter/StatusBadge.swift
git commit -m "feat: add StatusBadge view"
```

---

## Task 14: ExhibitSidebar

**Files:**
- Create: `IronGavel/Presenter/ExhibitSidebar.swift`

- [ ] **Step 1: Implement `ExhibitSidebar.swift`**

Create `IronGavel/Presenter/ExhibitSidebar.swift`:

```swift
import SwiftUI

struct ExhibitSidebar: View {
    @Environment(AppState.self) private var state

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
            ForEach(Party.allCases, id: \.self) { party in
                let items = exhibits(for: party)
                if !items.isEmpty {
                    Section(party.rawValue) {
                        ForEach(items) { exhibit in
                            row(for: exhibit)
                                .tag(exhibit.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("exhibit.sidebar")
    }

    @ViewBuilder
    private func row(for exhibit: Exhibit) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(exhibit.id).font(.system(.body, design: .monospaced))
            VStack(alignment: .leading, spacing: 2) {
                Text(exhibit.description).lineLimit(2)
                if let witness = exhibit.witness, !witness.isEmpty {
                    Text(witness).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusBadge(status: exhibit.status)
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("exhibit.row.\(exhibit.id)")
    }

    private func exhibits(for party: Party) -> [Exhibit] {
        state.currentCase?.exhibits.filter { $0.party == party } ?? []
    }
}
```

Add to the `IronGavel` target. Build. Expected: succeeds.

- [ ] **Step 2: Commit**

```bash
git add IronGavel/Presenter/ExhibitSidebar.swift
git commit -m "feat: add ExhibitSidebar grouped by party"
```

---

## Task 15: PreviewPane

**Files:**
- Create: `IronGavel/Presenter/PreviewPane.swift`

- [ ] **Step 1: Implement `PreviewPane.swift`**

Create `IronGavel/Presenter/PreviewPane.swift`:

```swift
import SwiftUI

struct PreviewPane: View {
    @Environment(AppState.self) private var state
    @State private var page: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            if let exhibit = state.selectedExhibit, let fileURL = resolvedURL(for: exhibit) {
                header(for: exhibit)
                content(exhibit: exhibit, fileURL: fileURL)
                if exhibit.mediaType == .pdf {
                    pageControls()
                }
            } else {
                Text("Select an exhibit").foregroundStyle(.secondary)
            }
        }
        .padding()
        .onChange(of: state.selectedExhibit?.id) { _, _ in
            page = 0
        }
        .onChange(of: page) { _, newValue in
            if let exhibit = state.selectedExhibit,
               case let .exhibit(currentExhibit, _) = state.juryDisplay,
               currentExhibit.id == exhibit.id {
                state.setPage(newValue)
            }
        }
        .accessibilityIdentifier("preview.pane")
    }

    private func header(for exhibit: Exhibit) -> some View {
        HStack {
            Text("\(exhibit.id) — \(exhibit.description)").font(.headline)
            Spacer()
            StatusBadge(status: exhibit.status)
        }
    }

    @ViewBuilder
    private func content(exhibit: Exhibit, fileURL: URL) -> some View {
        switch exhibit.mediaType {
        case .pdf:
            PDFPreview(fileURL: fileURL, pageIndex: $page)
        case .image:
            ImagePreview(fileURL: fileURL)
        case .video, .unknown:
            Text("Unsupported media type in Phase 1").foregroundStyle(.secondary)
        }
    }

    private func pageControls() -> some View {
        HStack {
            Button("◀︎") { page = max(0, page - 1) }
            Text("Page \(page + 1)")
            Button("▶︎") { page += 1 }
        }
        .buttonStyle(.bordered)
    }

    private func resolvedURL(for exhibit: Exhibit) -> URL? {
        guard let folder = state.caseFolderURL else { return nil }
        return folder.appendingPathComponent(exhibit.file)
    }
}
```

Add to the `IronGavel` target. Build. Expected: succeeds.

- [ ] **Step 2: Commit**

```bash
git add IronGavel/Presenter/PreviewPane.swift
git commit -m "feat: add PreviewPane with PDF page controls and jury sync"
```

---

## Task 16: PresenterToolbar

**Files:**
- Create: `IronGavel/Presenter/PresenterToolbar.swift`

- [ ] **Step 1: Implement `PresenterToolbar.swift`**

Create `IronGavel/Presenter/PresenterToolbar.swift`:

```swift
import SwiftUI

struct PresenterToolbar: View {
    @Environment(AppState.self) private var state
    let openCaseAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button("Open Case", action: openCaseAction)
                .accessibilityIdentifier("toolbar.openCase")

            Spacer()

            Button(action: { state.publishSelected() }) {
                Label("Publish", systemImage: "tv")
            }
            .disabled(!canPublish)
            .accessibilityIdentifier("toolbar.publish")

            Button(action: toggleBlank) {
                Label(isBlanked ? "Live" : "Blank", systemImage: isBlanked ? "play.fill" : "eye.slash")
            }
            .accessibilityIdentifier("toolbar.blank")

            externalIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var canPublish: Bool {
        state.selectedExhibit?.status == .admitted
    }

    private var isBlanked: Bool {
        state.juryDisplay == .blank
    }

    private func toggleBlank() {
        if isBlanked { state.restore() } else { state.blank() }
    }

    private var externalIndicator: some View {
        Label(
            state.externalConnected ? "External: Connected" : "External: Not connected",
            systemImage: state.externalConnected ? "rectangle.connected.to.line.below" : "rectangle.dashed"
        )
        .font(.caption)
        .foregroundStyle(state.externalConnected ? .green : .secondary)
        .accessibilityIdentifier("toolbar.external")
    }
}
```

Add to the `IronGavel` target. Build. Expected: succeeds.

- [ ] **Step 2: Commit**

```bash
git add IronGavel/Presenter/PresenterToolbar.swift
git commit -m "feat: add PresenterToolbar with publish gate and blank toggle"
```

---

## Task 17: PresenterScene + open-folder flow

**Files:**
- Create: `IronGavel/Presenter/PresenterScene.swift`
- Create: `IronGavel/Loader/FolderPicker.swift`

- [ ] **Step 1: Implement `FolderPicker.swift`**

Create `IronGavel/Loader/FolderPicker.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct FolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}
```

- [ ] **Step 2: Implement `PresenterScene.swift`**

Create `IronGavel/Presenter/PresenterScene.swift`:

```swift
import SwiftUI

struct PresenterScene: View {
    @Environment(AppState.self) private var state
    @State private var showFolderPicker = false
    @State private var loadError: String?

    private let loader = CaseLoader()
    private let bookmarks = BookmarkStore()

    var body: some View {
        NavigationSplitView {
            ExhibitSidebar()
        } detail: {
            VStack(spacing: 0) {
                PresenterToolbar { showFolderPicker = true }
                Divider()
                if let banner = state.lastStatusBanner {
                    bannerView(text: banner)
                }
                PreviewPane()
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker { url in
                showFolderPicker = false
                openFolder(url, persistBookmark: true)
            }
        }
        .alert("Cannot load case", isPresented: errorBinding, presenting: loadError) { _ in
            Button("OK", role: .cancel) { loadError = nil }
        } message: { message in
            Text(message)
        }
        .onAppear(perform: restoreLastCase)
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })
    }

    private func bannerView(text: String) -> some View {
        HStack {
            Text(text).font(.callout)
            Spacer()
            Button("Dismiss") { state.dismissBanner() }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.25))
    }

    private func openFolder(_ url: URL, persistBookmark: Bool) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { /* hold scope for app lifetime */ } }
        do {
            let kase = try loader.load(folderURL: url)
            state.apply(case: kase, folder: url)
            if persistBookmark {
                let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                bookmarks.save(data)
            }
        } catch CaseLoadError.unsupportedContractVersion(let found, let supported) {
            loadError = "This case uses contract \(found); app supports \(supported). Update the app."
        } catch CaseLoadError.missingSidecar(let path) {
            loadError = "exhibits.json not found at \(path)."
        } catch CaseLoadError.decodeFailed(let message) {
            loadError = "Could not read exhibits.json: \(message)"
        } catch {
            loadError = String(describing: error)
        }
    }

    private func restoreLastCase() {
        guard let data = bookmarks.load() else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            bookmarks.clear()
            return
        }
        if stale { bookmarks.clear(); return }
        openFolder(url, persistBookmark: false)
    }
}
```

Add both files to the `IronGavel` target. Build. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add IronGavel/Presenter/PresenterScene.swift IronGavel/Loader/FolderPicker.swift
git commit -m "feat: add PresenterScene with folder picker and bookmark restore"
```

---

## Task 18: AppDelegate and external scene configuration

**Files:**
- Create: `IronGavel/App/AppDelegate.swift`
- Create: `IronGavel/App/JurySceneDelegate.swift`
- Modify: `IronGavel/Resources/Info.plist`
- Modify: `IronGavel/App/IronGavelApp.swift`

- [ ] **Step 1: Implement `JurySceneDelegate.swift`**

Create `IronGavel/App/JurySceneDelegate.swift`:

```swift
import UIKit
import SwiftUI

@MainActor
final class JurySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    static var sharedState: AppState?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let root: AnyView
        if let state = JurySceneDelegate.sharedState {
            root = AnyView(JuryView().environment(state))
        } else {
            root = AnyView(BlankView())
        }
        window.rootViewController = UIHostingController(rootView: root)
        window.isHidden = false
        self.window = window
        JurySceneDelegate.sharedState?.externalConnected = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        JurySceneDelegate.sharedState?.externalConnected = false
    }
}
```

- [ ] **Step 2: Implement `AppDelegate.swift`**

Create `IronGavel/App/AppDelegate.swift`:

```swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let config = UISceneConfiguration(name: "Jury", sessionRole: .windowExternalDisplayNonInteractive)
            config.delegateClass = JurySceneDelegate.self
            return config
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
```

- [ ] **Step 3: Update Info.plist for external scene role**

In Xcode, open `Info.plist` (or the project's Info settings) and add under `Application Scene Manifest → Scene Configuration`:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <true/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleExternalDisplayNonInteractive</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Jury</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).JurySceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

- [ ] **Step 4: Wire `AppDelegate` and `AppState` into `IronGavelApp.swift`**

Replace `IronGavel/App/IronGavelApp.swift`:

```swift
import SwiftUI

@main
struct IronGavelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            PresenterScene()
                .environment(state)
                .onAppear { JurySceneDelegate.sharedState = state }
        }
    }
}
```

Add `AppDelegate.swift` and `JurySceneDelegate.swift` to the `IronGavel` target. Build. Expected: succeeds.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/App IronGavel/Resources/Info.plist
git commit -m "feat: wire AppDelegate and JurySceneDelegate for external display"
```

---

## Task 19: CaseWatcher — live reload on iCloud updates

**Files:**
- Create: `IronGavel/Loader/CaseWatcher.swift`
- Modify: `IronGavel/Presenter/PresenterScene.swift`

- [ ] **Step 1: Implement `CaseWatcher.swift`**

Create `IronGavel/Loader/CaseWatcher.swift`:

```swift
import Foundation

@MainActor
final class CaseWatcher: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = OperationQueue.main

    private let onChange: () -> Void

    init(folderURL: URL, onChange: @escaping () -> Void) {
        self.presentedItemURL = folderURL.appendingPathComponent("exhibits.json")
        self.onChange = onChange
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    nonisolated func presentedItemDidChange() {
        Task { @MainActor in onChange() }
    }
}
```

- [ ] **Step 2: Add the watcher to `PresenterScene.swift`**

In `IronGavel/Presenter/PresenterScene.swift`, add a `@State` for the watcher and start it after a successful load:

```swift
    @State private var watcher: CaseWatcher?
```

Inside `openFolder(_:persistBookmark:)`, after `state.apply(case: kase, folder: url)`:

```swift
            watcher = CaseWatcher(folderURL: url) {
                if let newCase = try? loader.load(folderURL: url) {
                    state.apply(case: newCase, folder: url)
                }
            }
```

Build. Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add IronGavel/Loader/CaseWatcher.swift IronGavel/Presenter/PresenterScene.swift
git commit -m "feat: live-reload case on exhibits.json change via NSFilePresenter"
```

---

## Task 20: PublishFlowUITest

**Files:**
- Create: `IronGavelUITests/PublishFlowUITest.swift`

This test runs on the iPad simulator. It uses the fixture sidecar from Task 3, which lives inside the unit-test bundle. For the UI test we copy a fixture into the app's documents directory at launch using a `LAUNCH_FIXTURE` argument.

- [ ] **Step 1: Add fixture-loading branch to `IronGavelApp.swift`**

Modify `IronGavel/App/IronGavelApp.swift`:

```swift
import SwiftUI

@main
struct IronGavelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            PresenterScene()
                .environment(state)
                .onAppear {
                    JurySceneDelegate.sharedState = state
                    loadUITestFixtureIfRequested()
                }
        }
    }

    private func loadUITestFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--ui-test-fixture") else { return }
        guard let url = Bundle.main.url(forResource: "ui-test-exhibits", withExtension: "json"),
              let kase = try? JSONDecoder().decode(Case.self, from: Data(contentsOf: url)) else {
            return
        }
        state.apply(case: kase, folder: url.deletingLastPathComponent())
    }
}
```

- [ ] **Step 2: Add the UI-test fixture to the app bundle**

Copy `IronGavelTests/Fixtures/Trial/exhibits.json` into `IronGavel/Resources/ui-test-exhibits.json`. Add it to the **app target's** Copy Bundle Resources.

- [ ] **Step 3: Write the UI test**

Create `IronGavelUITests/PublishFlowUITest.swift`:

```swift
import XCTest

final class PublishFlowUITest: XCTestCase {
    func test_publish_admitted_then_blank() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let sidebar = app.collectionViews["exhibit.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        let admittedRow = app.staticTexts["D-001"]
        XCTAssertTrue(admittedRow.waitForExistence(timeout: 5))
        admittedRow.tap()

        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        XCTAssertTrue(publish.isEnabled)
        publish.tap()

        let blank = app.buttons["toolbar.blank"]
        XCTAssertEqual(blank.label, "Blank")
        blank.tap()
        XCTAssertEqual(blank.label, "Live")

        let pending = app.staticTexts["S-014"]
        XCTAssertTrue(pending.exists)
        pending.tap()
        XCTAssertFalse(publish.isEnabled)
    }
}
```

- [ ] **Step 4: Run UI tests**

Run: ⌘U with the `IronGavelUITests` scheme. Expected: PASS on an iPad simulator (e.g. "iPad (10th generation)").

- [ ] **Step 5: Commit**

```bash
git add IronGavel/App/IronGavelApp.swift IronGavel/Resources/ui-test-exhibits.json IronGavelUITests
git commit -m "test: add publish-flow UI test"
```

---

## Task 21: Manual trial-readiness checklist

**Files:**
- Create: `docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md`

- [ ] **Step 1: Write the checklist**

Create `docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md`:

```markdown
# Iron Gavel — Phase 1 Trial-Readiness Checklist

Run this before any courtroom use.

- [ ] Mac connected to project iPad via USB-C.
- [ ] External HDMI display connected to iPad via USB-C-to-HDMI adapter.
- [ ] Iron Gavel built and installed via Xcode (Run → ⌘R) on the iPad.
- [ ] Case folder for the target case is fully downloaded in iCloud Drive on the iPad (open Files app → long-press the folder → Download Now).
- [ ] Inside the case folder, `Trial/exhibits.json` exists and was regenerated by `dw-exhibit-manager-crim` within the last 24h.
- [ ] In the app, tap Open Case and select the case's `Trial/` folder.
- [ ] Sidebar shows every exhibit grouped by party with correct status badges.
- [ ] Each exhibit's preview renders without "File missing".
- [ ] Publishing an admitted exhibit lights up the jury display with the same content.
- [ ] Page navigation on the presenter mirrors to the jury display.
- [ ] Blank Screen blacks out the jury display; toggling off restores the prior exhibit + page.
- [ ] On the Mac, regenerate `exhibits.json` with one exhibit's status changed; within 60s the iPad reflects the change and (if the published exhibit was downgraded) auto-blanks with a banner.
- [ ] Disconnect HDMI; reconnect; jury display resumes the same content.
```

- [ ] **Step 2: Commit**

```bash
git add docs/manual-checklists
git commit -m "docs: add Phase 1 trial-readiness manual checklist"
```

---

## Self-Review

**Spec coverage check:**
- Open case + iCloud read → Tasks 4, 6, 17
- Contract v1.0 validation → Task 4 (happy) + Task 5 (rejects 2.0)
- Sidebar by Party with status badges → Tasks 13, 14
- PDF + image preview → Tasks 10, 11, 15
- Publish gate (button + runtime) → Tasks 8 (auto-blank), 16 (button disable)
- Blank + restore → Tasks 8, 16
- External display scene → Task 18
- Live reload on sidecar change → Task 19
- Unit tests (CaseLoader, AppState, JuryDisplay, BookmarkStore, ContractVersion/Case decode) → Tasks 2, 3, 4, 5, 6, 7, 8
- UI publish flow → Task 20
- Manual checklist → Task 21
- All gaps closed.

**Placeholder scan:** None.

**Type consistency check:** `AppState.publishSelected`, `setPage`, `blank`, `restore`, `dismissBanner`, `apply(case:folder:)` used consistently across Tasks 8, 12, 14, 15, 16, 17, 18, 19, 20. `JuryDisplay` enum cases `.empty / .blank / .exhibit(_, page:)` consistent across Tasks 7, 8, 12, 16. `Exhibit` initializer args match Codable members.

---
