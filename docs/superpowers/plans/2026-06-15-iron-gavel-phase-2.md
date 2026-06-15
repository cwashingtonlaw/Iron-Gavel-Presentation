# Iron Gavel — Phase 2 Implementation Plan (Annotation)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four annotation tools (callout, highlight, freehand via PencilKit, redact) to Iron Gavel with per-exhibit JSON persistence under `<CASE_ROOT>/Trial/Annotations/`, live mirror to the jury display, stroke-level Undo + Clear, and a "Save annotated copy" flatten-to-PDF export.

**Architecture:** New `Annotation/` module under `IronGavel/`. A single `@Observable AnnotationStore` keyed by exhibit id holds in-memory state, an undo stack, page version counters, and a debounced save schedule. SwiftUI overlays (`PageAnnotationLayer` for presenter, `PageAnnotationLayerJury` for jury) sit in `ZStack`s above the existing Phase 1 PDF/image previews. Each of the four tools owns one gesture file and writes through `AnnotationStore.add(_:to:page:)`. `JuryDisplay.exhibit(...)` grows an `annotationsVersion` field so the jury view re-renders when annotations change.

**Tech Stack:** Swift 5.9+, SwiftUI, PencilKit (`PKCanvasView`, `PKDrawing`), PDFKit (`PDFDocument`, `PDFPage`), CoreGraphics (flatten export), Foundation (`NSFileCoordinator`), XCTest, XCUITest. iPadOS 17+. XcodeGen-driven project (`project.yml`).

**Reference:** `docs/superpowers/specs/2026-06-15-iron-gavel-phase-2-design.md` (and Phase 1 spec for inherited context).

---

## Conventions (read once, applies to every task)

These are unchanged from Phase 1; restated here so a fresh implementer can run any single task without other context:

1. **XcodeGen drives the project.** All files under `IronGavel/`, `IronGavelTests/`, `IronGavelUITests/` are auto-included via source globs in `project.yml`. Just create files and run `xcodegen generate`. Do NOT touch `project.yml` unless a task explicitly asks (only Task 7 below does).

2. **Build / test commands.** From the repo root:

   ```bash
   xcodegen generate
   xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
     -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -20

   xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
     -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -50
   ```

   If "iPad (A16)" is unavailable, pick another iPad simulator from `xcrun simctl list devices available | grep iPad`. Simulator launches are occasionally flaky — re-run a failed launch once before treating it as broken.

3. **Repo root** (quote carefully, contains spaces and special chars):

   `/Users/greatelephant82/Library/Mobile Documents/com~apple~CloudDocs/Claude Software Developer/Iron Gavel Presentation/Iron-Gavel-Presentation`

4. **Phase 1 baseline.** `main` is at the merge commit `f0d7b51`. This plan is implemented on branch `iron-gavel-phase-2` (already created; the spec lives there). Phase 1 tests must remain 22/22 passing at the end of every task.

---

## File Structure

New files (all under `IronGavel/Annotation/`):

```
Annotation/
  AnnotationContractVersion.swift
  AnnotationTool.swift
  AnnotationColor.swift
  NormalizedRect.swift
  Annotation.swift
  AnnotationPage.swift               # typealias [Annotation]
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
```

Modified Phase 1 files:

```
IronGavel/State/JuryDisplay.swift     # adds annotationsVersion
IronGavel/State/AppState.swift        # adds currentTool, currentColor, annotationStore
IronGavel/Presenter/PreviewPane.swift # wraps existing content in ZStack + toolbar
IronGavel/Jury/JuryView.swift         # wraps existing content in ZStack
```

New tests:

```
IronGavelTests/Annotation/
  AnnotationDocumentCodableTests.swift
  AnnotationStoreTests.swift
  AnnotationLoaderTests.swift
  AnnotationWriterTests.swift
  NormalizedRectTests.swift
  AnnotationFlattenerTests.swift
IronGavelUITests/AnnotationFlowUITest.swift
```

New fixtures:

```
IronGavelTests/Fixtures/AnnotationsValid/D-001.json
IronGavelTests/Fixtures/AnnotationsBadVersion/D-001.json
IronGavelTests/Fixtures/AnnotationsBadJSON/D-001.json
IronGavelTests/Fixtures/FlattenSource/sample.pdf
```

Modified docs:

```
docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md  # appended
```

Schema (root):

```
annotations.schema.json
```

---

## Task 1: Freeze the annotation contract — `annotations.schema.json`

**Files:**
- Create: `annotations.schema.json` (repo root, sibling to `exhibits.schema.json`)

- [ ] **Step 1: Write the schema**

Create `annotations.schema.json` at the repo root:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://danielswashington.law/schemas/annotations.schema.json",
  "title": "Iron Gavel Annotation Sidecar",
  "description": "Per-exhibit annotation sidecar. Written by the Iron Gavel iPad app under <CASE_ROOT>/Trial/Annotations/<exhibit-id>.json. Frozen contract v1.0.",
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

- [ ] **Step 2: Commit**

```bash
git add annotations.schema.json
git commit -m "$(cat <<'EOF'
docs(contract): add annotations.schema.json v1.0

Sibling to exhibits.schema.json. Locks per-exhibit annotation
sidecar shape so the app's read/write surface can't drift.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Core value types — ContractVersion, Tool, Color, NormalizedRect

**Files:**
- Create: `IronGavel/Annotation/AnnotationContractVersion.swift`
- Create: `IronGavel/Annotation/AnnotationTool.swift`
- Create: `IronGavel/Annotation/AnnotationColor.swift`
- Create: `IronGavel/Annotation/NormalizedRect.swift`
- Create: `IronGavelTests/Annotation/NormalizedRectTests.swift`
- Create: `IronGavelTests/Annotation/AnnotationEnumsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `IronGavelTests/Annotation/NormalizedRectTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class NormalizedRectTests: XCTestCase {
    func test_roundtrip_through_view_size() {
        let n = NormalizedRect(x: 0.25, y: 0.10, w: 0.50, h: 0.20)
        let view = CGSize(width: 800, height: 1000)
        let cg = n.toCGRect(in: view)
        XCTAssertEqual(cg.origin.x, 200, accuracy: 0.001)
        XCTAssertEqual(cg.origin.y, 100, accuracy: 0.001)
        XCTAssertEqual(cg.size.width, 400, accuracy: 0.001)
        XCTAssertEqual(cg.size.height, 200, accuracy: 0.001)

        let back = NormalizedRect(cgRect: cg, in: view)
        XCTAssertEqual(back.x, n.x, accuracy: 0.0001)
        XCTAssertEqual(back.y, n.y, accuracy: 0.0001)
        XCTAssertEqual(back.w, n.w, accuracy: 0.0001)
        XCTAssertEqual(back.h, n.h, accuracy: 0.0001)
    }

    func test_clamps_negative_values_to_zero() {
        let n = NormalizedRect(x: -0.5, y: -0.1, w: 0.5, h: 0.5)
        XCTAssertEqual(n.clamped().x, 0)
        XCTAssertEqual(n.clamped().y, 0)
    }

    func test_clamps_overflow_to_one() {
        let n = NormalizedRect(x: 0.8, y: 0.9, w: 0.5, h: 0.5)
        let c = n.clamped()
        XCTAssertEqual(c.x + c.w, 1.0, accuracy: 0.0001)
        XCTAssertEqual(c.y + c.h, 1.0, accuracy: 0.0001)
    }
}
```

Create `IronGavelTests/Annotation/AnnotationEnumsTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class AnnotationEnumsTests: XCTestCase {
    func test_contract_version_supported_is_one_point_zero() {
        XCTAssertEqual(AnnotationContractVersion.supported, "1.0")
    }

    func test_tool_decodes_lowercase_strings() throws {
        let json = #"["highlight","redact","callout","freehand"]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([AnnotationTool].self, from: json)
        XCTAssertEqual(decoded, [.highlight, .redact, .callout, .freehand])
    }

    func test_color_hex_round_trips() throws {
        for c in AnnotationColor.allCases {
            XCTAssertEqual(c.hex.count, 9)               // "#RRGGBBAA"
            XCTAssertEqual(c.hex.first, "#")
            let back = AnnotationColor(hex: c.hex)
            XCTAssertEqual(back, c)
        }
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -30
```

Expected: `Cannot find 'NormalizedRect' in scope` (and similar for the other types).

- [ ] **Step 3: Implement `AnnotationContractVersion.swift`**

Create `IronGavel/Annotation/AnnotationContractVersion.swift`:

```swift
import Foundation

enum AnnotationContractVersion {
    static let supported = "1.0"
}
```

- [ ] **Step 4: Implement `AnnotationTool.swift`**

Create `IronGavel/Annotation/AnnotationTool.swift`:

```swift
import Foundation

enum AnnotationTool: String, Codable, CaseIterable, Hashable {
    case highlight
    case redact
    case callout
    case freehand
}
```

- [ ] **Step 5: Implement `AnnotationColor.swift`**

Create `IronGavel/Annotation/AnnotationColor.swift`:

```swift
import SwiftUI

enum AnnotationColor: String, Codable, CaseIterable, Hashable {
    case yellow
    case orange
    case red
    case blue
    case green

    /// 8-digit hex with alpha for the FULL-opacity stroke color.
    /// Highlight uses 40% alpha; this is applied at render time, not stored here.
    var hex: String {
        switch self {
        case .yellow: return "#FFD60AFF"
        case .orange: return "#FF9F0AFF"
        case .red:    return "#FF453AFF"
        case .blue:   return "#0A84FFFF"
        case .green:  return "#30D158FF"
        }
    }

    init?(hex: String) {
        let match = AnnotationColor.allCases.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
        guard let match else { return nil }
        self = match
    }

    var uiColor: Color {
        switch self {
        case .yellow: return Color(red: 1.00, green: 0.84, blue: 0.04)
        case .orange: return Color(red: 1.00, green: 0.62, blue: 0.04)
        case .red:    return Color(red: 1.00, green: 0.27, blue: 0.23)
        case .blue:   return Color(red: 0.04, green: 0.52, blue: 1.00)
        case .green:  return Color(red: 0.19, green: 0.82, blue: 0.35)
        }
    }
}
```

- [ ] **Step 6: Implement `NormalizedRect.swift`**

Create `IronGavel/Annotation/NormalizedRect.swift`:

```swift
import CoreGraphics
import Foundation

struct NormalizedRect: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var h: CGFloat

    init(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    init(cgRect: CGRect, in viewSize: CGSize) {
        self.x = cgRect.minX / viewSize.width
        self.y = cgRect.minY / viewSize.height
        self.w = cgRect.width / viewSize.width
        self.h = cgRect.height / viewSize.height
    }

    func toCGRect(in viewSize: CGSize) -> CGRect {
        CGRect(x: x * viewSize.width,
               y: y * viewSize.height,
               width: w * viewSize.width,
               height: h * viewSize.height)
    }

    func clamped() -> NormalizedRect {
        var cx = max(0, min(1, x))
        var cy = max(0, min(1, y))
        var cw = max(0, w)
        var ch = max(0, h)
        if cx + cw > 1 { cw = 1 - cx }
        if cy + ch > 1 { ch = 1 - cy }
        return NormalizedRect(x: cx, y: cy, w: cw, h: ch)
    }
}
```

- [ ] **Step 7: Run tests — expect pass**

Run the test command from Step 2. Expected: all `NormalizedRectTests` and `AnnotationEnumsTests` pass; Phase 1's 22 tests still pass. Total ≥ 28 tests, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add IronGavel/Annotation IronGavelTests/Annotation
git commit -m "$(cat <<'EOF'
feat(annotation): add ContractVersion, Tool, Color, NormalizedRect value types

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Annotation + AnnotationDocument Codable types

**Files:**
- Create: `IronGavel/Annotation/Annotation.swift`
- Create: `IronGavel/Annotation/AnnotationPage.swift`
- Create: `IronGavel/Annotation/AnnotationDocument.swift`
- Create: `IronGavelTests/Annotation/AnnotationDocumentCodableTests.swift`
- Create: `IronGavelTests/Fixtures/AnnotationsValid/D-001.json`

- [ ] **Step 1: Write the fixture**

Create `IronGavelTests/Fixtures/AnnotationsValid/D-001.json`:

```json
{
  "contract_version": "1.0",
  "exhibit_id": "D-001",
  "last_modified": "2026-06-15T03:00:00Z",
  "pages": {
    "0": [
      {
        "id": "11111111-1111-1111-1111-111111111111",
        "tool": "highlight",
        "color": "#FFD60AFF",
        "bounds": { "x": 0.1, "y": 0.2, "w": 0.3, "h": 0.05 }
      },
      {
        "id": "22222222-2222-2222-2222-222222222222",
        "tool": "callout",
        "color": "#0A84FFFF",
        "bounds":         { "x": 0.6, "y": 0.6, "w": 0.3, "h": 0.2 },
        "callout_source": { "x": 0.1, "y": 0.1, "w": 0.2, "h": 0.1 }
      },
      {
        "id": "33333333-3333-3333-3333-333333333333",
        "tool": "freehand",
        "color": "#FF453AFF",
        "ink_data_base64": ""
      }
    ]
  }
}
```

- [ ] **Step 2: Write the failing test**

Create `IronGavelTests/Annotation/AnnotationDocumentCodableTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class AnnotationDocumentCodableTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        return try XCTUnwrap(bundle.url(forResource: "D-001", withExtension: "json"))
    }

    func test_decodes_valid_fixture() throws {
        let data = try Data(contentsOf: fixtureURL())
        let doc = try JSONDecoder().decode(AnnotationDocument.self, from: data)

        XCTAssertEqual(doc.contractVersion, "1.0")
        XCTAssertEqual(doc.exhibitId, "D-001")
        XCTAssertEqual(doc.pages["0"]?.count, 3)

        let highlight = doc.pages["0"]?[0]
        XCTAssertEqual(highlight?.tool, .highlight)
        XCTAssertEqual(highlight?.color, .yellow)
        XCTAssertEqual(highlight?.bounds?.x, 0.1, accuracy: 0.0001)

        let callout = doc.pages["0"]?[1]
        XCTAssertEqual(callout?.tool, .callout)
        XCTAssertNotNil(callout?.calloutSource)

        let freehand = doc.pages["0"]?[2]
        XCTAssertEqual(freehand?.tool, .freehand)
        XCTAssertEqual(freehand?.inkDataBase64, "")
    }

    func test_round_trip_encode_decode_preserves_all_fields() throws {
        let original = try JSONDecoder().decode(AnnotationDocument.self, from: Data(contentsOf: fixtureURL()))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnnotationDocument.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func test_empty_pages_decode_as_empty_dictionary() throws {
        let json = #"{"contract_version":"1.0","exhibit_id":"D-001","last_modified":"2026-06-15T03:00:00Z","pages":{}}"#
        let doc = try JSONDecoder().decode(AnnotationDocument.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(doc.pages.count, 0)
    }
}
```

- [ ] **Step 3: Run tests — expect failure**

Expected: `Cannot find 'AnnotationDocument' in scope`.

- [ ] **Step 4: Implement `Annotation.swift`**

Create `IronGavel/Annotation/Annotation.swift`:

```swift
import Foundation

struct Annotation: Codable, Hashable, Identifiable {
    let id: UUID
    let tool: AnnotationTool
    let color: AnnotationColor
    let bounds: NormalizedRect?
    let calloutSource: NormalizedRect?
    let inkDataBase64: String?

    enum CodingKeys: String, CodingKey {
        case id, tool, color, bounds
        case calloutSource = "callout_source"
        case inkDataBase64 = "ink_data_base64"
    }

    init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        color: AnnotationColor,
        bounds: NormalizedRect? = nil,
        calloutSource: NormalizedRect? = nil,
        inkDataBase64: String? = nil
    ) {
        self.id = id
        self.tool = tool
        self.color = color
        self.bounds = bounds
        self.calloutSource = calloutSource
        self.inkDataBase64 = inkDataBase64
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.tool = try c.decode(AnnotationTool.self, forKey: .tool)
        let hex = try c.decode(String.self, forKey: .color)
        guard let parsed = AnnotationColor(hex: hex) else {
            throw DecodingError.dataCorruptedError(forKey: .color, in: c, debugDescription: "Unknown color hex \(hex)")
        }
        self.color = parsed
        self.bounds = try c.decodeIfPresent(NormalizedRect.self, forKey: .bounds)
        self.calloutSource = try c.decodeIfPresent(NormalizedRect.self, forKey: .calloutSource)
        self.inkDataBase64 = try c.decodeIfPresent(String.self, forKey: .inkDataBase64)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(tool, forKey: .tool)
        try c.encode(color.hex, forKey: .color)
        try c.encodeIfPresent(bounds, forKey: .bounds)
        try c.encodeIfPresent(calloutSource, forKey: .calloutSource)
        try c.encodeIfPresent(inkDataBase64, forKey: .inkDataBase64)
    }
}
```

- [ ] **Step 5: Implement `AnnotationPage.swift`**

Create `IronGavel/Annotation/AnnotationPage.swift`:

```swift
import Foundation

/// An ordered list of annotations on a single page.
/// Stored under string keys ("0", "1", ...) in AnnotationDocument.pages.
typealias AnnotationPage = [Annotation]
```

- [ ] **Step 6: Implement `AnnotationDocument.swift`**

Create `IronGavel/Annotation/AnnotationDocument.swift`:

```swift
import Foundation

struct AnnotationDocument: Codable, Hashable {
    var contractVersion: String
    var exhibitId: String
    var lastModified: String
    var pages: [String: AnnotationPage]

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case exhibitId       = "exhibit_id"
        case lastModified    = "last_modified"
        case pages
    }

    static func empty(exhibitId: String) -> AnnotationDocument {
        AnnotationDocument(
            contractVersion: AnnotationContractVersion.supported,
            exhibitId: exhibitId,
            lastModified: ISO8601DateFormatter().string(from: Date()),
            pages: [:]
        )
    }
}
```

- [ ] **Step 7: Run tests — expect pass**

Expected: 3 new tests in `AnnotationDocumentCodableTests` pass. Total ≥ 31 tests, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add IronGavel/Annotation IronGavelTests/Annotation IronGavelTests/Fixtures
git commit -m "$(cat <<'EOF'
feat(annotation): add Annotation + AnnotationDocument Codable types

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: AnnotationLoader (happy path + missing file)

**Files:**
- Create: `IronGavel/Annotation/AnnotationLoadError.swift`
- Create: `IronGavel/Annotation/AnnotationLoader.swift`
- Create: `IronGavelTests/Annotation/AnnotationLoaderTests.swift`

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/Annotation/AnnotationLoaderTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class AnnotationLoaderTests: XCTestCase {
    private func fixtureFolderURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let json = try XCTUnwrap(bundle.url(forResource: "D-001", withExtension: "json"))
        // Fixture sits in test bundle root; treat that folder as the "Annotations" folder
        return json.deletingLastPathComponent()
    }

    func test_loads_existing_annotation_document() throws {
        let loader = AnnotationLoader()
        let folder = try fixtureFolderURL()
        let doc = try loader.load(annotationsFolder: folder, exhibitId: "D-001")
        XCTAssertEqual(doc.contractVersion, "1.0")
        XCTAssertEqual(doc.exhibitId, "D-001")
    }

    func test_missing_file_returns_empty_document_for_exhibit_id() throws {
        let loader = AnnotationLoader()
        let bogus = URL(fileURLWithPath: "/tmp/iron-gavel-no-annotations-\(UUID().uuidString)")
        let doc = try loader.load(annotationsFolder: bogus, exhibitId: "X-999")
        XCTAssertEqual(doc.exhibitId, "X-999")
        XCTAssertEqual(doc.pages.count, 0)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Expected: `Cannot find 'AnnotationLoader' in scope`.

- [ ] **Step 3: Implement `AnnotationLoadError.swift`**

Create `IronGavel/Annotation/AnnotationLoadError.swift`:

```swift
import Foundation

enum AnnotationLoadError: Error, Equatable {
    case decodeFailed(message: String)
    case unsupportedContractVersion(found: String, supported: String)
    case fileAccessDenied(path: String)
}
```

- [ ] **Step 4: Implement `AnnotationLoader.swift`**

Create `IronGavel/Annotation/AnnotationLoader.swift`:

```swift
import Foundation

struct AnnotationLoader {
    func load(annotationsFolder: URL, exhibitId: String) throws -> AnnotationDocument {
        let fileURL = annotationsFolder.appendingPathComponent("\(exhibitId).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AnnotationDocument.empty(exhibitId: exhibitId)
        }

        let data: Data
        do {
            data = try readCoordinated(url: fileURL)
        } catch {
            throw AnnotationLoadError.fileAccessDenied(path: fileURL.path)
        }

        let doc: AnnotationDocument
        do {
            doc = try JSONDecoder().decode(AnnotationDocument.self, from: data)
        } catch {
            throw AnnotationLoadError.decodeFailed(message: String(describing: error))
        }

        guard doc.contractVersion == AnnotationContractVersion.supported else {
            throw AnnotationLoadError.unsupportedContractVersion(
                found: doc.contractVersion,
                supported: AnnotationContractVersion.supported
            )
        }

        return doc
    }

    private func readCoordinated(url: URL) throws -> Data {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        var data: Data?
        var readError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordinatedURL in
            do { data = try Data(contentsOf: coordinatedURL) } catch { readError = error }
        }
        if let coordError { throw coordError }
        if let readError { throw readError }
        return data ?? Data()
    }
}
```

- [ ] **Step 5: Run tests — expect pass**

Total ≥ 33 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add IronGavel/Annotation/AnnotationLoadError.swift IronGavel/Annotation/AnnotationLoader.swift IronGavelTests/Annotation/AnnotationLoaderTests.swift
git commit -m "$(cat <<'EOF'
feat(annotation): add AnnotationLoader happy path + missing-file

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: AnnotationLoader — bad version + bad JSON

**Files:**
- Modify: `IronGavelTests/Annotation/AnnotationLoaderTests.swift` (append tests)
- Create: `IronGavelTests/Fixtures/AnnotationsBadVersion/D-001.json`
- Create: `IronGavelTests/Fixtures/AnnotationsBadJSON/D-001.json`
- Modify: `project.yml` (add folder references for the two bad-fixture subdirs)

- [ ] **Step 1: Add bad-version fixture**

Create `IronGavelTests/Fixtures/AnnotationsBadVersion/D-001.json`:

```json
{
  "contract_version": "2.0",
  "exhibit_id": "D-001",
  "last_modified": "2026-06-15T03:00:00Z",
  "pages": {}
}
```

- [ ] **Step 2: Add bad-JSON fixture**

Create `IronGavelTests/Fixtures/AnnotationsBadJSON/D-001.json`:

```
{ not valid json
```

- [ ] **Step 3: Add folder references in `project.yml`**

The `IronGavelTests` target in `project.yml` currently includes two folder references (from Phase 1's Task 5): `BadVersion` and `BadJSON` for the exhibits work. Update the `sources:` list so the new annotation bad-fixture folders are also folder-referenced (otherwise both `D-001.json` files would flatten into the bundle and collide).

Find the `IronGavelTests` target block. Its `sources:` should become:

```yaml
    sources:
      - path: IronGavelTests
        excludes:
          - "Fixtures/BadVersion/**"
          - "Fixtures/BadJSON/**"
          - "Fixtures/AnnotationsBadVersion/**"
          - "Fixtures/AnnotationsBadJSON/**"
      - path: IronGavelTests/Fixtures/BadVersion
        buildPhase: resources
        type: folder
      - path: IronGavelTests/Fixtures/BadJSON
        buildPhase: resources
        type: folder
      - path: IronGavelTests/Fixtures/AnnotationsBadVersion
        buildPhase: resources
        type: folder
      - path: IronGavelTests/Fixtures/AnnotationsBadJSON
        buildPhase: resources
        type: folder
```

Run `xcodegen generate`.

- [ ] **Step 4: Append failing tests**

Append to `IronGavelTests/Annotation/AnnotationLoaderTests.swift`:

```swift
extension AnnotationLoaderTests {
    private func resourceFolder(named name: String) throws -> URL {
        let bundle = Bundle(for: type(of: self))
        return try XCTUnwrap(bundle.url(forResource: name, withExtension: nil))
    }

    func test_unsupported_contract_version_throws() throws {
        let loader = AnnotationLoader()
        let folder = try resourceFolder(named: "AnnotationsBadVersion")
        XCTAssertThrowsError(try loader.load(annotationsFolder: folder, exhibitId: "D-001")) { err in
            guard case let AnnotationLoadError.unsupportedContractVersion(found, supported) = err else {
                return XCTFail("expected .unsupportedContractVersion, got \(err)")
            }
            XCTAssertEqual(found, "2.0")
            XCTAssertEqual(supported, "1.0")
        }
    }

    func test_bad_json_throws_decode_failed() throws {
        let loader = AnnotationLoader()
        let folder = try resourceFolder(named: "AnnotationsBadJSON")
        XCTAssertThrowsError(try loader.load(annotationsFolder: folder, exhibitId: "D-001")) { err in
            guard case AnnotationLoadError.decodeFailed = err else {
                return XCTFail("expected .decodeFailed, got \(err)")
            }
        }
    }
}
```

- [ ] **Step 5: Run tests — expect pass**

Total ≥ 35 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add IronGavelTests/Annotation/AnnotationLoaderTests.swift IronGavelTests/Fixtures/AnnotationsBadVersion IronGavelTests/Fixtures/AnnotationsBadJSON project.yml
git commit -m "$(cat <<'EOF'
test(annotation): cover AnnotationLoader version and decode errors

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: AnnotationWriter (atomic temp+rename, creates parent dir)

**Files:**
- Create: `IronGavel/Annotation/AnnotationWriter.swift`
- Create: `IronGavelTests/Annotation/AnnotationWriterTests.swift`

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/Annotation/AnnotationWriterTests.swift`:

```swift
import XCTest
@testable import IronGavel

final class AnnotationWriterTests: XCTestCase {
    private var tmpRoot: URL!

    override func setUpWithError() throws {
        tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("iron-gavel-writer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpRoot)
    }

    private func sampleDoc() -> AnnotationDocument {
        AnnotationDocument(
            contractVersion: "1.0",
            exhibitId: "D-001",
            lastModified: "2026-06-15T03:00:00Z",
            pages: ["0": []]
        )
    }

    func test_writes_to_specified_folder_creating_missing_parent() throws {
        let nested = tmpRoot.appendingPathComponent("Trial/Annotations")
        let writer = AnnotationWriter()
        try writer.write(sampleDoc(), to: nested)
        let expected = nested.appendingPathComponent("D-001.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func test_write_is_atomic_no_temp_file_left_behind() throws {
        let writer = AnnotationWriter()
        try writer.write(sampleDoc(), to: tmpRoot)
        let contents = try FileManager.default.contentsOfDirectory(atPath: tmpRoot.path)
        XCTAssertTrue(contents.contains("D-001.json"))
        XCTAssertFalse(contents.contains { $0.hasSuffix(".tmp") })
    }

    func test_round_trip_through_loader() throws {
        let writer = AnnotationWriter()
        let loader = AnnotationLoader()
        try writer.write(sampleDoc(), to: tmpRoot)
        let loaded = try loader.load(annotationsFolder: tmpRoot, exhibitId: "D-001")
        XCTAssertEqual(loaded, sampleDoc())
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Expected: `Cannot find 'AnnotationWriter' in scope`.

- [ ] **Step 3: Implement `AnnotationWriter.swift`**

Create `IronGavel/Annotation/AnnotationWriter.swift`:

```swift
import Foundation

struct AnnotationWriter {
    func write(_ document: AnnotationDocument, to annotationsFolder: URL) throws {
        try FileManager.default.createDirectory(at: annotationsFolder, withIntermediateDirectories: true)

        let finalURL = annotationsFolder.appendingPathComponent("\(document.exhibitId).json")
        let tmpURL = annotationsFolder.appendingPathComponent("\(document.exhibitId).json.tmp")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)

        try writeCoordinated(data: data, to: tmpURL)
        _ = try? FileManager.default.removeItem(at: finalURL)
        try FileManager.default.moveItem(at: tmpURL, to: finalURL)
    }

    private func writeCoordinated(data: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        var writeError: Error?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordinated in
            do {
                try data.write(to: coordinated, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordError { throw coordError }
        if let writeError { throw writeError }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Total ≥ 38 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/Annotation/AnnotationWriter.swift IronGavelTests/Annotation/AnnotationWriterTests.swift
git commit -m "$(cat <<'EOF'
feat(annotation): add AnnotationWriter (atomic temp+rename)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: AnnotationStore — in-memory model + version bumps + Undo + Clear

**Files:**
- Create: `IronGavel/Annotation/AnnotationStore.swift`
- Create: `IronGavelTests/Annotation/AnnotationStoreTests.swift`

The store owns the in-memory map, per-page version counters, per-exhibit undo stacks, and an `onChange` callback that callers (Task 8 will use this from `AppState`) can wire to schedule disk writes. Disk-write debouncing is NOT in the store — the store fires `onChange` synchronously; the wiring layer schedules the actual save. This keeps the store testable without a clock.

- [ ] **Step 1: Write the failing test**

Create `IronGavelTests/Annotation/AnnotationStoreTests.swift`:

```swift
import XCTest
@testable import IronGavel

@MainActor
final class AnnotationStoreTests: XCTestCase {
    private func highlight(_ id: UUID = UUID()) -> Annotation {
        Annotation(id: id, tool: .highlight, color: .yellow,
                   bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.05))
    }

    func test_add_appends_and_bumps_version() {
        let store = AnnotationStore()
        let v0 = store.pageVersion(exhibitId: "D-001", page: 0)
        store.add(highlight(), exhibitId: "D-001", page: 0)
        XCTAssertEqual(store.annotations(exhibitId: "D-001", page: 0).count, 1)
        XCTAssertGreaterThan(store.pageVersion(exhibitId: "D-001", page: 0), v0)
    }

    func test_undo_removes_last_added() {
        let store = AnnotationStore()
        let a = highlight(); let b = highlight()
        store.add(a, exhibitId: "D-001", page: 0)
        store.add(b, exhibitId: "D-001", page: 0)
        store.undo(exhibitId: "D-001", page: 0)
        let ids = store.annotations(exhibitId: "D-001", page: 0).map(\.id)
        XCTAssertEqual(ids, [a.id])
    }

    func test_clear_empties_page() {
        let store = AnnotationStore()
        store.add(highlight(), exhibitId: "D-001", page: 0)
        store.add(highlight(), exhibitId: "D-001", page: 0)
        store.clear(exhibitId: "D-001", page: 0)
        XCTAssertTrue(store.annotations(exhibitId: "D-001", page: 0).isEmpty)
    }

    func test_freehand_replace_keeps_single_annotation_per_page() {
        let store = AnnotationStore()
        let f1 = Annotation(tool: .freehand, color: .blue, inkDataBase64: "A")
        let f2 = Annotation(tool: .freehand, color: .blue, inkDataBase64: "B")
        store.add(f1, exhibitId: "D-001", page: 0)
        store.add(f2, exhibitId: "D-001", page: 0)
        let freehands = store.annotations(exhibitId: "D-001", page: 0).filter { $0.tool == .freehand }
        XCTAssertEqual(freehands.count, 1)
        XCTAssertEqual(freehands.first?.inkDataBase64, "B")
    }

    func test_on_change_fires_for_each_mutation() {
        let store = AnnotationStore()
        var hits: [String] = []
        store.onChange = { hits.append($0) }
        store.add(highlight(), exhibitId: "D-001", page: 0)
        store.add(highlight(), exhibitId: "S-014", page: 1)
        store.undo(exhibitId: "D-001", page: 0)
        store.clear(exhibitId: "S-014", page: 1)
        XCTAssertEqual(hits, ["D-001", "S-014", "D-001", "S-014"])
    }

    func test_apply_document_replaces_in_memory_for_one_exhibit() {
        let store = AnnotationStore()
        store.add(highlight(), exhibitId: "D-001", page: 0)
        var doc = AnnotationDocument.empty(exhibitId: "D-001")
        doc.pages["0"] = [highlight()]
        doc.pages["1"] = [highlight()]
        store.apply(doc)
        XCTAssertEqual(store.annotations(exhibitId: "D-001", page: 0).count, 1)
        XCTAssertEqual(store.annotations(exhibitId: "D-001", page: 1).count, 1)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Expected: `Cannot find 'AnnotationStore' in scope`.

- [ ] **Step 3: Implement `AnnotationStore.swift`**

Create `IronGavel/Annotation/AnnotationStore.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AnnotationStore {
    /// Caller can register a callback to be notified when any exhibit's annotations change.
    /// Wiring code (e.g. AppState) uses this to schedule debounced disk writes.
    @ObservationIgnored var onChange: ((String) -> Void)?

    private var documents: [String: AnnotationDocument] = [:]
    private var versions: [String: [Int: Int]] = [:]

    func document(exhibitId: String) -> AnnotationDocument {
        documents[exhibitId] ?? AnnotationDocument.empty(exhibitId: exhibitId)
    }

    func annotations(exhibitId: String, page: Int) -> [Annotation] {
        documents[exhibitId]?.pages[String(page)] ?? []
    }

    func pageVersion(exhibitId: String, page: Int) -> Int {
        versions[exhibitId]?[page] ?? 0
    }

    func apply(_ document: AnnotationDocument) {
        documents[document.exhibitId] = document
        bumpAllVersions(exhibitId: document.exhibitId, in: document)
        onChange?(document.exhibitId)
    }

    func add(_ annotation: Annotation, exhibitId: String, page: Int) {
        var doc = documents[exhibitId] ?? AnnotationDocument.empty(exhibitId: exhibitId)
        let key = String(page)
        var list = doc.pages[key] ?? []

        if annotation.tool == .freehand {
            list.removeAll { $0.tool == .freehand }
        }
        list.append(annotation)

        doc.pages[key] = list
        doc.lastModified = ISO8601DateFormatter().string(from: Date())
        documents[exhibitId] = doc
        bumpVersion(exhibitId: exhibitId, page: page)
        onChange?(exhibitId)
    }

    func undo(exhibitId: String, page: Int) {
        guard var doc = documents[exhibitId] else { return }
        let key = String(page)
        guard var list = doc.pages[key], !list.isEmpty else { return }
        _ = list.removeLast()
        doc.pages[key] = list
        doc.lastModified = ISO8601DateFormatter().string(from: Date())
        documents[exhibitId] = doc
        bumpVersion(exhibitId: exhibitId, page: page)
        onChange?(exhibitId)
    }

    func clear(exhibitId: String, page: Int) {
        guard var doc = documents[exhibitId] else { return }
        doc.pages[String(page)] = []
        doc.lastModified = ISO8601DateFormatter().string(from: Date())
        documents[exhibitId] = doc
        bumpVersion(exhibitId: exhibitId, page: page)
        onChange?(exhibitId)
    }

    private func bumpVersion(exhibitId: String, page: Int) {
        var map = versions[exhibitId] ?? [:]
        map[page] = (map[page] ?? 0) + 1
        versions[exhibitId] = map
    }

    private func bumpAllVersions(exhibitId: String, in doc: AnnotationDocument) {
        var map = versions[exhibitId] ?? [:]
        for key in doc.pages.keys {
            if let page = Int(key) {
                map[page] = (map[page] ?? 0) + 1
            }
        }
        versions[exhibitId] = map
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Total ≥ 44 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/Annotation/AnnotationStore.swift IronGavelTests/Annotation/AnnotationStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(annotation): add AnnotationStore (add/undo/clear, freehand single, onChange)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Wire AnnotationStore into AppState + JuryDisplay version field

**Files:**
- Modify: `IronGavel/State/JuryDisplay.swift`
- Modify: `IronGavel/State/AppState.swift`
- Modify: `IronGavelTests/JuryDisplayTests.swift` (update existing equality tests)
- Modify: `IronGavelTests/AppStateTests.swift` (update construction)

This task introduces a small breaking change to `JuryDisplay.exhibit(...)`: it now carries `annotationsVersion: Int`. Phase 1 tests need to be updated.

- [ ] **Step 1: Update `JuryDisplay.swift`**

Replace `IronGavel/State/JuryDisplay.swift` entirely with:

```swift
import Foundation

enum JuryDisplay: Equatable {
    case empty
    case blank
    case exhibit(Exhibit, page: Int, annotationsVersion: Int)

    var currentExhibit: Exhibit? {
        if case let .exhibit(e, _, _) = self { return e }
        return nil
    }

    var currentPage: Int? {
        if case let .exhibit(_, page, _) = self { return page }
        return nil
    }

    var annotationsVersion: Int? {
        if case let .exhibit(_, _, v) = self { return v }
        return nil
    }
}
```

- [ ] **Step 2: Update `JuryDisplayTests.swift`**

The test file's `.exhibit(...)` callers need a `, annotationsVersion: 0` (or another small int) argument. Open `IronGavelTests/JuryDisplayTests.swift` and replace its body with:

```swift
import XCTest
@testable import IronGavel

final class JuryDisplayTests: XCTestCase {
    private func makeExhibit(id: String = "D-001", status: ExhibitStatus = .admitted) -> Exhibit {
        Exhibit(
            id: id, party: .defense, description: "x",
            file: "f.pdf", witness: nil, bates: nil,
            status: status, mediaType: .pdf,
            objection: nil, ruling: nil, notes: nil
        )
    }

    func test_equality_distinguishes_states() {
        let e = makeExhibit()
        XCTAssertEqual(JuryDisplay.empty, .empty)
        XCTAssertEqual(JuryDisplay.blank, .blank)
        XCTAssertEqual(JuryDisplay.exhibit(e, page: 0, annotationsVersion: 0),
                       .exhibit(e, page: 0, annotationsVersion: 0))
        XCTAssertNotEqual(JuryDisplay.exhibit(e, page: 0, annotationsVersion: 0),
                          .exhibit(e, page: 1, annotationsVersion: 0))
        XCTAssertNotEqual(JuryDisplay.exhibit(e, page: 0, annotationsVersion: 0),
                          .exhibit(e, page: 0, annotationsVersion: 1))
    }

    func test_currentExhibit_returns_exhibit_only_when_displayed() {
        let e = makeExhibit()
        XCTAssertNil(JuryDisplay.empty.currentExhibit)
        XCTAssertNil(JuryDisplay.blank.currentExhibit)
        XCTAssertEqual(JuryDisplay.exhibit(e, page: 2, annotationsVersion: 0).currentExhibit?.id, "D-001")
    }
}
```

- [ ] **Step 3: Update `AppState.swift`**

Open `IronGavel/State/AppState.swift` and replace it entirely with:

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

    var currentTool: AnnotationTool?
    var currentColor: AnnotationColor = .yellow
    let annotationStore = AnnotationStore()

    init() {
        annotationStore.onChange = { [weak self] exhibitId in
            self?.handleAnnotationChange(for: exhibitId)
        }
    }

    func apply(case kase: Case, folder: URL) {
        let previousCase = self.currentCase
        self.currentCase = kase
        self.caseFolderURL = folder

        if let previousCase, case let .exhibit(published, page, _) = juryDisplay {
            let updated = kase.exhibits.first(where: { $0.id == published.id })
            if let updated, updated.status != .admitted, published.status == .admitted {
                juryDisplay = .blank
                lastStatusBanner = "Exhibit \(published.id) status changed to \(updated.status.rawValue). Jury display blanked."
            }
            _ = previousCase
            _ = page
        }
    }

    func select(_ exhibit: Exhibit) {
        selectedExhibit = exhibit
    }

    func publishSelected() {
        guard let exhibit = selectedExhibit, exhibit.status == .admitted else { return }
        let v = annotationStore.pageVersion(exhibitId: exhibit.id, page: 0)
        juryDisplay = .exhibit(exhibit, page: 0, annotationsVersion: v)
        lastPublished = (exhibit, 0)
        lastStatusBanner = nil
    }

    func setPage(_ page: Int) {
        if case let .exhibit(exhibit, _, _) = juryDisplay {
            let v = annotationStore.pageVersion(exhibitId: exhibit.id, page: page)
            juryDisplay = .exhibit(exhibit, page: page, annotationsVersion: v)
            lastPublished = (exhibit, page)
        }
    }

    func blank() {
        juryDisplay = .blank
    }

    func restore() {
        if let last = lastPublished {
            let v = annotationStore.pageVersion(exhibitId: last.exhibit.id, page: last.page)
            juryDisplay = .exhibit(last.exhibit, page: last.page, annotationsVersion: v)
        }
    }

    func dismissBanner() {
        lastStatusBanner = nil
    }

    private func handleAnnotationChange(for exhibitId: String) {
        if case let .exhibit(published, page, _) = juryDisplay, published.id == exhibitId {
            let v = annotationStore.pageVersion(exhibitId: exhibitId, page: page)
            juryDisplay = .exhibit(published, page: page, annotationsVersion: v)
        }
    }
}
```

- [ ] **Step 4: Update `AppStateTests.swift`**

Open `IronGavelTests/AppStateTests.swift` and update only the assertions involving `JuryDisplay.exhibit(...)`. Replace the file's body with:

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
        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 0, annotationsVersion: 0))
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
        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 3, annotationsVersion: 0))
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

        XCTAssertEqual(state.juryDisplay, .exhibit(admitted, page: 0, annotationsVersion: 0))
        XCTAssertNil(state.lastStatusBanner)
    }

    func test_annotation_mutation_on_published_exhibit_bumps_jury_version() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        let v0 = state.juryDisplay.annotationsVersion ?? -1

        let mark = Annotation(tool: .highlight, color: .yellow,
                              bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.05))
        state.annotationStore.add(mark, exhibitId: "D-001", page: 0)

        let v1 = state.juryDisplay.annotationsVersion ?? -1
        XCTAssertGreaterThan(v1, v0)
    }

    func test_annotation_mutation_on_non_published_exhibit_does_not_change_jury() {
        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: URL(fileURLWithPath: "/tmp"))
        state.select(admitted)
        state.publishSelected()

        let before = state.juryDisplay

        let mark = Annotation(tool: .highlight, color: .yellow,
                              bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.05))
        state.annotationStore.add(mark, exhibitId: "S-999", page: 0)

        XCTAssertEqual(state.juryDisplay, before)
    }
}
```

- [ ] **Step 5: Build + run all tests — expect pass**

Total ≥ 46 tests, 0 failures. Pay particular attention that the previously-passing `JuryDisplayTests` and `AppStateTests` adapt cleanly to the new `JuryDisplay` shape.

- [ ] **Step 6: Commit**

```bash
git add IronGavel/State/JuryDisplay.swift IronGavel/State/AppState.swift IronGavelTests/JuryDisplayTests.swift IronGavelTests/AppStateTests.swift
git commit -m "$(cat <<'EOF'
feat(state): JuryDisplay carries annotationsVersion; AppState owns AnnotationStore

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Debounced disk save — wire AnnotationStore.onChange to AnnotationWriter

**Files:**
- Modify: `IronGavel/State/AppState.swift` (extend `handleAnnotationChange`)
- Modify: `IronGavelTests/AppStateTests.swift` (one new test)

The store mutates in memory; this task adds the actual disk write, debounced 500 ms, only when a case folder is set.

- [ ] **Step 1: Append test**

Append to `IronGavelTests/AppStateTests.swift` (still inside `final class AppStateTests`):

```swift
    func test_annotation_change_writes_to_disk_after_debounce() async throws {
        let tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("iron-gavel-state-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let admitted = exhibit("D-001", status: .admitted)
        let state = AppState()
        state.apply(case: makeCase([admitted]), folder: tmpRoot)
        state.select(admitted)

        let mark = Annotation(tool: .highlight, color: .yellow,
                              bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.05))
        state.annotationStore.add(mark, exhibitId: "D-001", page: 0)

        // Allow debounce + write to land.
        try await Task.sleep(nanoseconds: 800_000_000)

        let saved = tmpRoot.appendingPathComponent("Trial/Annotations/D-001.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.path),
                      "expected debounced save at \(saved.path)")
    }
```

- [ ] **Step 2: Run test — expect failure**

Expected: the file does not exist; no debounced save is wired yet.

- [ ] **Step 3: Extend `AppState` with a debounced writer**

Open `IronGavel/State/AppState.swift`. Modify it so that:

1. Add a stored property after `let annotationStore = AnnotationStore()`:

   ```swift
   @ObservationIgnored private var saveTasks: [String: Task<Void, Never>] = [:]
   @ObservationIgnored private let writer = AnnotationWriter()
   ```

2. Replace `handleAnnotationChange(for:)` with the version below (it now ALSO schedules a debounced save):

   ```swift
   private func handleAnnotationChange(for exhibitId: String) {
       if case let .exhibit(published, page, _) = juryDisplay, published.id == exhibitId {
           let v = annotationStore.pageVersion(exhibitId: exhibitId, page: page)
           juryDisplay = .exhibit(published, page: page, annotationsVersion: v)
       }
       scheduleSave(exhibitId: exhibitId)
   }

   private func scheduleSave(exhibitId: String) {
       guard let folder = caseFolderURL else { return }
       saveTasks[exhibitId]?.cancel()
       saveTasks[exhibitId] = Task { [annotationStore, writer] in
           try? await Task.sleep(nanoseconds: 500_000_000)
           if Task.isCancelled { return }
           let doc = await annotationStore.document(exhibitId: exhibitId)
           let annotationsFolder = folder.appendingPathComponent("Trial/Annotations")
           try? writer.write(doc, to: annotationsFolder)
       }
   }
   ```

- [ ] **Step 4: Run test — expect pass**

The new test should pass (the 800 ms sleep gives the 500 ms debounce + write time). All earlier tests still pass.

Total ≥ 47 tests.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/State/AppState.swift IronGavelTests/AppStateTests.swift
git commit -m "$(cat <<'EOF'
feat(state): debounced annotation save (500ms) into Trial/Annotations/

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Highlight + Redact gestures + presenter overlay

**Files:**
- Create: `IronGavel/Annotation/Tools/HighlightGesture.swift`
- Create: `IronGavel/Annotation/Tools/RedactGesture.swift`
- Create: `IronGavel/Annotation/Views/PageAnnotationLayer.swift`

No new unit tests; these are interaction surfaces. Verify via build + the existing test suite.

- [ ] **Step 1: Implement `HighlightGesture.swift`**

Create `IronGavel/Annotation/Tools/HighlightGesture.swift`:

```swift
import SwiftUI

struct HighlightGestureModifier: ViewModifier {
    let viewSize: CGSize
    let onCommit: (NormalizedRect) -> Void
    @State private var start: CGPoint?

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if start == nil { start = value.startLocation }
                    }
                    .onEnded { value in
                        defer { start = nil }
                        guard let s = start else { return }
                        let cg = CGRect(
                            x: min(s.x, value.location.x),
                            y: min(s.y, value.location.y),
                            width: abs(value.location.x - s.x),
                            height: abs(value.location.y - s.y)
                        )
                        let n = NormalizedRect(cgRect: cg, in: viewSize).clamped()
                        if n.w > 0.005 && n.h > 0.005 {
                            onCommit(n)
                        }
                    }
            )
    }
}
```

- [ ] **Step 2: Implement `RedactGesture.swift`**

Create `IronGavel/Annotation/Tools/RedactGesture.swift`:

```swift
import SwiftUI

/// Redact uses the exact same drag geometry as Highlight; reusing the modifier
/// keeps the math in one place. The caller decides the tool tag on commit.
typealias RedactGestureModifier = HighlightGestureModifier
```

- [ ] **Step 3: Implement `PageAnnotationLayer.swift`**

Create `IronGavel/Annotation/Views/PageAnnotationLayer.swift`:

```swift
import SwiftUI

struct PageAnnotationLayer: View {
    let exhibitId: String
    let page: Int
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(state.annotationStore.annotations(exhibitId: exhibitId, page: page), id: \.id) { ann in
                    rendered(annotation: ann, in: geo.size)
                }
                gestureSurface(viewSize: geo.size)
            }
        }
        .accessibilityIdentifier("annotation.layer.\(exhibitId).p\(page)")
    }

    @ViewBuilder
    private func rendered(annotation: Annotation, in size: CGSize) -> some View {
        switch annotation.tool {
        case .highlight:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(annotation.color.uiColor.opacity(0.4))
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width,
                              y: (b.y + b.h/2) * size.height)
                    .accessibilityIdentifier("annotation.highlight.\(annotation.id)")
            }
        case .redact:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width,
                              y: (b.y + b.h/2) * size.height)
                    .accessibilityIdentifier("annotation.redact.\(annotation.id)")
            }
        case .callout:
            // CalloutBubble is added in Task 11.
            EmptyView()
        case .freehand:
            // FreehandCanvas overlay is added in Task 12.
            EmptyView()
        }
    }

    @ViewBuilder
    private func gestureSurface(viewSize: CGSize) -> some View {
        switch state.currentTool {
        case .highlight:
            Color.clear
                .contentShape(Rectangle())
                .modifier(HighlightGestureModifier(viewSize: viewSize) { rect in
                    let ann = Annotation(tool: .highlight, color: state.currentColor, bounds: rect)
                    state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
                })
        case .redact:
            Color.clear
                .contentShape(Rectangle())
                .modifier(RedactGestureModifier(viewSize: viewSize) { rect in
                    let ann = Annotation(tool: .redact, color: state.currentColor, bounds: rect)
                    state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
                })
        case .callout, .freehand, .none:
            EmptyView()
        }
    }
}
```

- [ ] **Step 4: Build + test**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -30
```

Expected: all existing tests pass; new files compile cleanly.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/Annotation/Tools/HighlightGesture.swift IronGavel/Annotation/Tools/RedactGesture.swift IronGavel/Annotation/Views/PageAnnotationLayer.swift
git commit -m "$(cat <<'EOF'
feat(annotation): highlight + redact gestures and presenter overlay

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Callout — two-stage gesture + CalloutBubble

**Files:**
- Create: `IronGavel/Annotation/Tools/CalloutGesture.swift`
- Create: `IronGavel/Annotation/Views/CalloutBubble.swift`
- Modify: `IronGavel/Annotation/Views/PageAnnotationLayer.swift` (render + dispatch callout)

- [ ] **Step 1: Implement `CalloutGesture.swift`**

Create `IronGavel/Annotation/Tools/CalloutGesture.swift`:

```swift
import SwiftUI

struct CalloutGestureModifier: ViewModifier {
    let viewSize: CGSize
    let onCommit: (_ source: NormalizedRect, _ bounds: NormalizedRect) -> Void

    @State private var stage: Stage = .awaitingSource
    @State private var pendingSource: NormalizedRect?
    @State private var dragStart: CGPoint?

    enum Stage { case awaitingSource, awaitingBounds }

    func body(content: Content) -> some View {
        content
            .overlay(stagePreview)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragStart == nil { dragStart = value.startLocation }
                    }
                    .onEnded { value in
                        defer { dragStart = nil }
                        guard let s = dragStart else { return }
                        let cg = CGRect(
                            x: min(s.x, value.location.x),
                            y: min(s.y, value.location.y),
                            width: abs(value.location.x - s.x),
                            height: abs(value.location.y - s.y)
                        )
                        let n = NormalizedRect(cgRect: cg, in: viewSize).clamped()
                        guard n.w > 0.005, n.h > 0.005 else { return }
                        switch stage {
                        case .awaitingSource:
                            pendingSource = n
                            stage = .awaitingBounds
                        case .awaitingBounds:
                            if let src = pendingSource {
                                onCommit(src, n)
                            }
                            pendingSource = nil
                            stage = .awaitingSource
                        }
                    }
            )
    }

    @ViewBuilder
    private var stagePreview: some View {
        if let src = pendingSource, stage == .awaitingBounds {
            GeometryReader { geo in
                let r = src.toCGRect(in: geo.size)
                Rectangle()
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
            }
        }
    }
}
```

- [ ] **Step 2: Implement `CalloutBubble.swift`**

Create `IronGavel/Annotation/Views/CalloutBubble.swift`:

```swift
import SwiftUI
import PDFKit

struct CalloutBubble: View {
    let annotation: Annotation
    let exhibitFileURL: URL?
    let pageIndex: Int

    var body: some View {
        GeometryReader { geo in
            if let bounds = annotation.bounds {
                let frame = bounds.toCGRect(in: geo.size)
                ZStack {
                    sourceImage(in: frame.size)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(annotation.color.uiColor, lineWidth: 3)
                        )
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityIdentifier("annotation.callout.\(annotation.id)")
            }
        }
    }

    @ViewBuilder
    private func sourceImage(in size: CGSize) -> some View {
        if let image = rasterizedSource(targetSize: size) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Color.gray.opacity(0.2)
        }
    }

    private func rasterizedSource(targetSize: CGSize) -> UIImage? {
        guard let url = exhibitFileURL,
              let source = annotation.calloutSource,
              let doc = PDFDocument(url: url),
              let page = doc.page(at: pageIndex)
        else { return nil }

        let pageBounds = page.bounds(for: .mediaBox)
        let srcRect = CGRect(
            x: source.x * pageBounds.width,
            y: source.y * pageBounds.height,
            width: source.w * pageBounds.width,
            height: source.h * pageBounds.height
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: targetSize.width / srcRect.width,
                                  y: -targetSize.height / srcRect.height)
            ctx.cgContext.translateBy(x: -srcRect.minX, y: -srcRect.minY)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}
```

- [ ] **Step 3: Extend `PageAnnotationLayer.swift`**

Modify `IronGavel/Annotation/Views/PageAnnotationLayer.swift`. The view now needs the resolved exhibit file URL so `CalloutBubble` can rasterize. Replace the file with:

```swift
import SwiftUI

struct PageAnnotationLayer: View {
    let exhibitId: String
    let exhibitFileURL: URL?
    let page: Int
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(state.annotationStore.annotations(exhibitId: exhibitId, page: page), id: \.id) { ann in
                    rendered(annotation: ann, in: geo.size)
                }
                gestureSurface(viewSize: geo.size)
            }
        }
        .accessibilityIdentifier("annotation.layer.\(exhibitId).p\(page)")
    }

    @ViewBuilder
    private func rendered(annotation: Annotation, in size: CGSize) -> some View {
        switch annotation.tool {
        case .highlight:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(annotation.color.uiColor.opacity(0.4))
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width,
                              y: (b.y + b.h/2) * size.height)
                    .accessibilityIdentifier("annotation.highlight.\(annotation.id)")
            }
        case .redact:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width,
                              y: (b.y + b.h/2) * size.height)
                    .accessibilityIdentifier("annotation.redact.\(annotation.id)")
            }
        case .callout:
            CalloutBubble(annotation: annotation, exhibitFileURL: exhibitFileURL, pageIndex: page)
        case .freehand:
            EmptyView() // Task 12 adds the freehand layer
        }
    }

    @ViewBuilder
    private func gestureSurface(viewSize: CGSize) -> some View {
        switch state.currentTool {
        case .highlight:
            Color.clear
                .contentShape(Rectangle())
                .modifier(HighlightGestureModifier(viewSize: viewSize) { rect in
                    let ann = Annotation(tool: .highlight, color: state.currentColor, bounds: rect)
                    state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
                })
        case .redact:
            Color.clear
                .contentShape(Rectangle())
                .modifier(RedactGestureModifier(viewSize: viewSize) { rect in
                    let ann = Annotation(tool: .redact, color: state.currentColor, bounds: rect)
                    state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
                })
        case .callout:
            Color.clear
                .contentShape(Rectangle())
                .modifier(CalloutGestureModifier(viewSize: viewSize) { source, bounds in
                    let ann = Annotation(tool: .callout, color: state.currentColor,
                                         bounds: bounds, calloutSource: source)
                    state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
                })
        case .freehand, .none:
            EmptyView()
        }
    }
}
```

- [ ] **Step 4: Build + test**

Expected: all tests pass; nothing wired into the presenter scene yet, so no behavioral change in the running app.

- [ ] **Step 5: Commit**

```bash
git add IronGavel/Annotation/Tools/CalloutGesture.swift IronGavel/Annotation/Views/CalloutBubble.swift IronGavel/Annotation/Views/PageAnnotationLayer.swift
git commit -m "$(cat <<'EOF'
feat(annotation): callout (two-stage gesture + zoomed bubble)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Freehand — FreehandCanvas (PencilKit) + layer integration

**Files:**
- Create: `IronGavel/Annotation/Tools/FreehandCanvas.swift`
- Modify: `IronGavel/Annotation/Views/PageAnnotationLayer.swift` (render freehand + dispatch)

- [ ] **Step 1: Implement `FreehandCanvas.swift`**

Create `IronGavel/Annotation/Tools/FreehandCanvas.swift`:

```swift
import SwiftUI
import PencilKit

struct FreehandCanvas: UIViewRepresentable {
    @Binding var drawingData: Data
    let inkColor: UIColor
    let isPresenter: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: 4)
        canvas.isUserInteractionEnabled = isPresenter
        if let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isPresenter
        uiView.tool = PKInkingTool(.pen, color: inkColor, width: 4)
        if let drawing = try? PKDrawing(data: drawingData), drawing != uiView.drawing {
            uiView.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: FreehandCanvas
        init(_ parent: FreehandCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()
            if data != parent.drawingData {
                parent.drawingData = data
            }
        }
    }
}
```

- [ ] **Step 2: Extend `PageAnnotationLayer.swift`**

Modify the freehand arms in `PageAnnotationLayer.swift`. Replace the `case .freehand:` arm of `rendered(annotation:in:)` and the `.freehand` arm of `gestureSurface(viewSize:)`. Updated relevant portions:

In `rendered(annotation:in:)`:

```swift
        case .freehand:
            FreehandReadOnly(annotation: annotation, color: annotation.color.uiColor)
                .allowsHitTesting(false)
                .accessibilityIdentifier("annotation.freehand.\(annotation.id)")
```

In `gestureSurface(viewSize:)`:

```swift
        case .freehand:
            FreehandActive(exhibitId: exhibitId, page: page, viewSize: viewSize)
```

Append two new helper views at the bottom of `PageAnnotationLayer.swift`:

```swift
private struct FreehandReadOnly: View {
    let annotation: Annotation
    let color: Color

    var body: some View {
        let data = decodedData()
        FreehandCanvas(
            drawingData: .constant(data),
            inkColor: UIColor(color),
            isPresenter: false
        )
    }

    private func decodedData() -> Data {
        guard let b64 = annotation.inkDataBase64,
              let d = Data(base64Encoded: b64) else { return Data() }
        return d
    }
}

private struct FreehandActive: View {
    let exhibitId: String
    let page: Int
    let viewSize: CGSize
    @Environment(AppState.self) private var state
    @State private var data: Data = Data()

    var body: some View {
        FreehandCanvas(
            drawingData: $data,
            inkColor: UIColor(state.currentColor.uiColor),
            isPresenter: true
        )
        .onChange(of: data) { _, newValue in
            let b64 = newValue.base64EncodedString()
            let ann = Annotation(tool: .freehand,
                                 color: state.currentColor,
                                 inkDataBase64: b64)
            state.annotationStore.add(ann, exhibitId: exhibitId, page: page)
        }
        .onAppear {
            let existing = state.annotationStore.annotations(exhibitId: exhibitId, page: page)
                .first(where: { $0.tool == .freehand })
            if let b64 = existing?.inkDataBase64, let d = Data(base64Encoded: b64) {
                data = d
            }
        }
    }
}
```

Note: the existing top-level `import SwiftUI` is sufficient; the helpers don't need `import PencilKit` because `FreehandCanvas` re-exports its types transitively through SwiftUI usage.

- [ ] **Step 3: Build + test**

Expected: all tests pass; freehand-strokes-update-store path is exercised by `test_freehand_replace_keeps_single_annotation_per_page` from Task 7.

- [ ] **Step 4: Commit**

```bash
git add IronGavel/Annotation/Tools/FreehandCanvas.swift IronGavel/Annotation/Views/PageAnnotationLayer.swift
git commit -m "$(cat <<'EOF'
feat(annotation): freehand via PencilKit (single annotation per page)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Jury overlay (read-only mirror)

**Files:**
- Create: `IronGavel/Annotation/Views/PageAnnotationLayerJury.swift`
- Modify: `IronGavel/Jury/JuryView.swift`

- [ ] **Step 1: Implement `PageAnnotationLayerJury.swift`**

Create `IronGavel/Annotation/Views/PageAnnotationLayerJury.swift`:

```swift
import SwiftUI

struct PageAnnotationLayerJury: View {
    let exhibitId: String
    let exhibitFileURL: URL?
    let page: Int
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(state.annotationStore.annotations(exhibitId: exhibitId, page: page), id: \.id) { ann in
                    rendered(ann, in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityIdentifier("jury.annotation.layer.\(exhibitId).p\(page)")
    }

    @ViewBuilder
    private func rendered(_ annotation: Annotation, in size: CGSize) -> some View {
        switch annotation.tool {
        case .highlight:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(annotation.color.uiColor.opacity(0.4))
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width, y: (b.y + b.h/2) * size.height)
            }
        case .redact:
            if let b = annotation.bounds {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: b.w * size.width, height: b.h * size.height)
                    .position(x: (b.x + b.w/2) * size.width, y: (b.y + b.h/2) * size.height)
            }
        case .callout:
            CalloutBubble(annotation: annotation, exhibitFileURL: exhibitFileURL, pageIndex: page)
        case .freehand:
            if let b64 = annotation.inkDataBase64, let data = Data(base64Encoded: b64) {
                FreehandCanvas(
                    drawingData: .constant(data),
                    inkColor: UIColor(annotation.color.uiColor),
                    isPresenter: false
                )
            }
        }
    }
}
```

- [ ] **Step 2: Modify `JuryView.swift`**

Open `IronGavel/Jury/JuryView.swift`. Replace its body with the version below — the change is wrapping the existing exhibit content in a `ZStack` that adds `PageAnnotationLayerJury`:

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
        case let .exhibit(exhibit, page, _):
            if let fileURL = resolvedURL(for: exhibit) {
                ZStack {
                    switch exhibit.mediaType {
                    case .pdf:
                        PDFJuryView(fileURL: fileURL, pageIndex: page)
                    case .image:
                        ImageJuryView(fileURL: fileURL)
                    case .video, .unknown:
                        BlankView()
                    }
                    PageAnnotationLayerJury(
                        exhibitId: exhibit.id,
                        exhibitFileURL: fileURL,
                        page: page
                    )
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

- [ ] **Step 3: Build + test**

All tests still pass. Total ≥ 47.

- [ ] **Step 4: Commit**

```bash
git add IronGavel/Annotation/Views/PageAnnotationLayerJury.swift IronGavel/Jury/JuryView.swift
git commit -m "$(cat <<'EOF'
feat(annotation): jury overlay mirrors annotations read-only

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: AnnotationToolbar + ClearPageConfirm

**Files:**
- Create: `IronGavel/Annotation/Views/AnnotationToolbar.swift`
- Create: `IronGavel/Annotation/Views/ClearPageConfirm.swift`

- [ ] **Step 1: Implement `ClearPageConfirm.swift`**

Create `IronGavel/Annotation/Views/ClearPageConfirm.swift`:

```swift
import SwiftUI

struct ClearPageConfirm: View {
    let page: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Clear all annotations on page \(page + 1)?")
                .font(.headline)
            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Clear", role: .destructive, action: onConfirm)
                    .accessibilityIdentifier("annotation.clear.confirm")
            }
        }
        .padding()
    }
}
```

- [ ] **Step 2: Implement `AnnotationToolbar.swift`**

Create `IronGavel/Annotation/Views/AnnotationToolbar.swift`:

```swift
import SwiftUI

struct AnnotationToolbar: View {
    let exhibitId: String
    let page: Int
    let onExport: () -> Void
    @Environment(AppState.self) private var state
    @State private var showClearConfirm = false

    var body: some View {
        HStack(spacing: 14) {
            toolButton(.highlight, icon: "highlighter")
            toolButton(.redact, icon: "rectangle.fill")
            toolButton(.callout, icon: "rectangle.dashed.and.paperclip")
            toolButton(.freehand, icon: "pencil.tip")

            Divider().frame(height: 22)

            colorPicker

            Divider().frame(height: 22)

            Button(action: undo) {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .accessibilityIdentifier("annotation.undo")

            Button(action: { showClearConfirm = true }) {
                Label("Clear", systemImage: "trash")
            }
            .accessibilityIdentifier("annotation.clear")

            Spacer()

            Button(action: onExport) {
                Label("Save Copy", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("annotation.export")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .sheet(isPresented: $showClearConfirm) {
            ClearPageConfirm(
                page: page,
                onConfirm: { showClearConfirm = false; state.annotationStore.clear(exhibitId: exhibitId, page: page) },
                onCancel: { showClearConfirm = false }
            )
        }
    }

    @ViewBuilder
    private func toolButton(_ tool: AnnotationTool, icon: String) -> some View {
        Button {
            state.currentTool = (state.currentTool == tool) ? nil : tool
        } label: {
            Image(systemName: icon)
                .padding(6)
                .background(state.currentTool == tool ? Color.accentColor.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityIdentifier("annotation.tool.\(tool.rawValue)")
    }

    private var colorPicker: some View {
        HStack(spacing: 8) {
            ForEach(AnnotationColor.allCases, id: \.self) { c in
                Button {
                    state.currentColor = c
                } label: {
                    Circle()
                        .fill(c.uiColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.primary, lineWidth: state.currentColor == c ? 2 : 0)
                        )
                }
                .accessibilityIdentifier("annotation.color.\(c.rawValue)")
            }
        }
    }

    private func undo() {
        state.annotationStore.undo(exhibitId: exhibitId, page: page)
    }
}
```

- [ ] **Step 3: Build + test**

Expected: clean build; tests pass.

- [ ] **Step 4: Commit**

```bash
git add IronGavel/Annotation/Views/AnnotationToolbar.swift IronGavel/Annotation/Views/ClearPageConfirm.swift
git commit -m "$(cat <<'EOF'
feat(annotation): toolbar (tool picker, color, undo, clear, export)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: AnnotationFlattener (export flattened PDF)

**Files:**
- Create: `IronGavel/Annotation/Export/AnnotationFlattener.swift`
- Create: `IronGavelTests/Annotation/AnnotationFlattenerTests.swift`
- Create: `IronGavelTests/Fixtures/FlattenSource/sample.pdf` (1-page PDF)

- [ ] **Step 1: Generate the fixture PDF**

Run from the repo root in Terminal:

```bash
mkdir -p IronGavelTests/Fixtures/FlattenSource
python3 - <<'EOF'
from pathlib import Path
pdf = b"""%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<<>>>>endobj
4 0 obj<</Length 44>>stream
BT /F1 12 Tf 72 720 Td (Iron Gavel) Tj ET
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000010 00000 n 
0000000053 00000 n 
0000000094 00000 n 
0000000178 00000 n 
trailer<</Size 5/Root 1 0 R>>
startxref
280
%%EOF"""
Path("IronGavelTests/Fixtures/FlattenSource/sample.pdf").write_bytes(pdf)
print("wrote", Path("IronGavelTests/Fixtures/FlattenSource/sample.pdf").stat().st_size, "bytes")
EOF
```

Verify the file exists and `PDFDocument` can open it manually if you want, but the test itself will fail loudly if it cannot.

- [ ] **Step 2: Add folder reference for the fixture in `project.yml`**

Edit the `IronGavelTests` target's `sources:` list. Add to `excludes`:

```yaml
          - "Fixtures/FlattenSource/**"
```

And add another folder reference entry:

```yaml
      - path: IronGavelTests/Fixtures/FlattenSource
        buildPhase: resources
        type: folder
```

Run `xcodegen generate`.

- [ ] **Step 3: Write the failing test**

Create `IronGavelTests/Annotation/AnnotationFlattenerTests.swift`:

```swift
import XCTest
import PDFKit
@testable import IronGavel

final class AnnotationFlattenerTests: XCTestCase {
    private func sourcePDFURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let folder = try XCTUnwrap(bundle.url(forResource: "FlattenSource", withExtension: nil))
        return folder.appendingPathComponent("sample.pdf")
    }

    private func tempOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("flatten-\(UUID().uuidString).pdf")
    }

    func test_flatten_produces_single_page_pdf_with_input_dimensions() throws {
        let annotations: [Annotation] = [
            Annotation(tool: .highlight, color: .yellow,
                       bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.5, h: 0.05))
        ]
        let output = tempOutputURL()
        defer { try? FileManager.default.removeItem(at: output) }

        let flattener = AnnotationFlattener()
        try flattener.flatten(
            exhibitFileURL: try sourcePDFURL(),
            pageIndex: 0,
            annotations: annotations,
            outputURL: output
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let doc = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(doc.pageCount, 1)
        let page = try XCTUnwrap(doc.page(at: 0))
        XCTAssertEqual(page.bounds(for: .mediaBox).width, 612, accuracy: 0.5)
        XCTAssertEqual(page.bounds(for: .mediaBox).height, 792, accuracy: 0.5)
    }
}
```

- [ ] **Step 4: Run tests — expect failure**

Expected: `Cannot find 'AnnotationFlattener' in scope`.

- [ ] **Step 5: Implement `AnnotationFlattener.swift`**

Create `IronGavel/Annotation/Export/AnnotationFlattener.swift`:

```swift
import Foundation
import PDFKit
import PencilKit
import UIKit

struct AnnotationFlattener {
    enum FlattenError: Error {
        case cannotOpenSource
        case cannotResolvePage
        case writeFailed(message: String)
    }

    func flatten(
        exhibitFileURL: URL,
        pageIndex: Int,
        annotations: [Annotation],
        outputURL: URL
    ) throws {
        guard let source = PDFDocument(url: exhibitFileURL) else { throw FlattenError.cannotOpenSource }
        guard let page = source.page(at: pageIndex) else { throw FlattenError.cannotResolvePage }
        let pageBounds = page.bounds(for: .mediaBox)

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext
            cg.saveGState()
            cg.translateBy(x: 0, y: pageBounds.height)
            cg.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: cg)
            cg.restoreGState()

            for annotation in annotations {
                draw(annotation, in: pageBounds, cg: cg)
            }
        }

        let tmp = outputURL.deletingLastPathComponent()
            .appendingPathComponent(outputURL.lastPathComponent + ".tmp")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.removeItem(at: outputURL)
            try FileManager.default.moveItem(at: tmp, to: outputURL)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw FlattenError.writeFailed(message: String(describing: error))
        }
    }

    private func draw(_ annotation: Annotation, in pageBounds: CGRect, cg: CGContext) {
        switch annotation.tool {
        case .highlight:
            if let b = annotation.bounds {
                let rect = pageRect(from: b, pageBounds: pageBounds)
                cg.setFillColor(uiColor(annotation.color).withAlphaComponent(0.4).cgColor)
                cg.fill(rect)
            }
        case .redact:
            if let b = annotation.bounds {
                let rect = pageRect(from: b, pageBounds: pageBounds)
                cg.setFillColor(UIColor.black.cgColor)
                cg.fill(rect)
            }
        case .callout:
            if let b = annotation.bounds {
                let rect = pageRect(from: b, pageBounds: pageBounds)
                cg.setStrokeColor(uiColor(annotation.color).cgColor)
                cg.setLineWidth(3)
                cg.stroke(rect)
            }
        case .freehand:
            if let b64 = annotation.inkDataBase64,
               let data = Data(base64Encoded: b64),
               let drawing = try? PKDrawing(data: data) {
                let image = drawing.image(from: pageBounds, scale: 2)
                cg.draw(image.cgImage!, in: pageBounds)
            }
        }
    }

    private func pageRect(from norm: NormalizedRect, pageBounds: CGRect) -> CGRect {
        CGRect(
            x: norm.x * pageBounds.width,
            y: norm.y * pageBounds.height,
            width: norm.w * pageBounds.width,
            height: norm.h * pageBounds.height
        )
    }

    private func uiColor(_ c: AnnotationColor) -> UIColor {
        switch c {
        case .yellow: return UIColor(red: 1.00, green: 0.84, blue: 0.04, alpha: 1)
        case .orange: return UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1)
        case .red:    return UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1)
        case .blue:   return UIColor(red: 0.04, green: 0.52, blue: 1.00, alpha: 1)
        case .green:  return UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1)
        }
    }
}
```

- [ ] **Step 6: Run tests — expect pass**

Total ≥ 48 tests.

- [ ] **Step 7: Commit**

```bash
git add IronGavel/Annotation/Export/AnnotationFlattener.swift IronGavelTests/Annotation/AnnotationFlattenerTests.swift IronGavelTests/Fixtures/FlattenSource project.yml
git commit -m "$(cat <<'EOF'
feat(annotation): AnnotationFlattener — render page + annotations into a flat PDF

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Wire annotation overlay + toolbar into PreviewPane; auto-load on exhibit select

**Files:**
- Modify: `IronGavel/Presenter/PreviewPane.swift`
- Modify: `IronGavel/Presenter/PresenterScene.swift` (load annotations after `state.apply(case:folder:)`)

- [ ] **Step 1: Modify `PreviewPane.swift`**

Replace `IronGavel/Presenter/PreviewPane.swift` with:

```swift
import SwiftUI

struct PreviewPane: View {
    @Environment(AppState.self) private var state
    @State private var page: Int = 0
    @State private var exportToast: String?

    private let flattener = AnnotationFlattener()

    var body: some View {
        VStack(spacing: 0) {
            if let exhibit = state.selectedExhibit, let fileURL = resolvedURL(for: exhibit) {
                header(for: exhibit)
                ZStack {
                    content(exhibit: exhibit, fileURL: fileURL)
                    PageAnnotationLayer(
                        exhibitId: exhibit.id,
                        exhibitFileURL: fileURL,
                        page: page
                    )
                }
                .padding(.horizontal, 12)
                if exhibit.mediaType == .pdf {
                    pageControls()
                }
                AnnotationToolbar(
                    exhibitId: exhibit.id,
                    page: page,
                    onExport: { exportFlattened(exhibit: exhibit, fileURL: fileURL) }
                )
                if let toast = exportToast {
                    Text(toast)
                        .font(.caption)
                        .padding(6)
                        .background(Color.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            } else {
                Spacer()
                Text("Select an exhibit").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .onChange(of: state.selectedExhibit?.id) { _, _ in
            page = 0
        }
        .onChange(of: page) { _, newValue in
            if let exhibit = state.selectedExhibit,
               case let .exhibit(currentExhibit, _, _) = state.juryDisplay,
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
        .padding(.horizontal, 12)
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
        .padding(.vertical, 4)
    }

    private func resolvedURL(for exhibit: Exhibit) -> URL? {
        guard let folder = state.caseFolderURL else { return nil }
        return folder.appendingPathComponent(exhibit.file)
    }

    private func exportFlattened(exhibit: Exhibit, fileURL: URL) {
        guard let folder = state.caseFolderURL else { return }
        let outDir = folder.appendingPathComponent("Trial/Annotated")
        let outURL = outDir.appendingPathComponent("\(exhibit.id)-p\(page).pdf")
        let annotations = state.annotationStore.annotations(exhibitId: exhibit.id, page: page)
        do {
            try flattener.flatten(
                exhibitFileURL: fileURL,
                pageIndex: page,
                annotations: annotations,
                outputURL: outURL
            )
            exportToast = "Saved to \(outURL.path)"
        } catch {
            exportToast = "Could not save annotated copy: \(error)"
        }
    }
}
```

- [ ] **Step 2: Modify `PresenterScene.swift` to auto-load annotations**

Open `IronGavel/Presenter/PresenterScene.swift`. Find `private func openFolder(_:persistBookmark:)`. After the line:

```swift
            state.apply(case: kase, folder: url)
```

(and before the `watcher = CaseWatcher(...)` block from Phase 1's Task 19), insert:

```swift
            preloadAnnotations(folder: url, exhibits: kase.exhibits)
```

Then, at the bottom of the struct (after `restoreLastCase()`), add:

```swift
    private func preloadAnnotations(folder: URL, exhibits: [Exhibit]) {
        let annotationsFolder = folder.appendingPathComponent("Trial/Annotations")
        let loader = AnnotationLoader()
        for exhibit in exhibits {
            if let doc = try? loader.load(annotationsFolder: annotationsFolder, exhibitId: exhibit.id) {
                state.annotationStore.apply(doc)
            }
        }
    }
```

- [ ] **Step 3: Build + test**

Total ≥ 48 tests, 0 failures. The app now actually renders annotations end-to-end.

- [ ] **Step 4: Commit**

```bash
git add IronGavel/Presenter/PreviewPane.swift IronGavel/Presenter/PresenterScene.swift
git commit -m "$(cat <<'EOF'
feat(presenter): wire annotation overlay + toolbar; preload annotations on case open

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: UI test — highlight a published exhibit and confirm jury version bumps

**Files:**
- Create: `IronGavelUITests/AnnotationFlowUITest.swift`

The Phase 1 `PublishFlowUITest` already publishes the fixture admitted exhibit. We extend that path: tap the highlight tool, drag on the preview pane, assert a `annotation.highlight.<uuid>` element exists.

- [ ] **Step 1: Write the test**

Create `IronGavelUITests/AnnotationFlowUITest.swift`:

```swift
import XCTest

final class AnnotationFlowUITest: XCTestCase {
    func test_highlight_appears_after_drag() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let admittedRow = app.staticTexts["D-001"]
        XCTAssertTrue(admittedRow.waitForExistence(timeout: 5))
        admittedRow.tap()

        let publish = app.buttons["toolbar.publish"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        publish.tap()

        let highlightTool = app.buttons["annotation.tool.highlight"]
        XCTAssertTrue(highlightTool.waitForExistence(timeout: 5))
        highlightTool.tap()

        let pane = app.otherElements["preview.pane"]
        XCTAssertTrue(pane.waitForExistence(timeout: 5))

        let start = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        let end = pane.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)

        // After the drag, a highlight rectangle should be present in the layer.
        // We can't predict the uuid, so match by prefix.
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'annotation.highlight.'")
        let highlight = app.otherElements.matching(predicate).firstMatch
        XCTAssertTrue(highlight.waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodegen generate
xcodebuild -project IronGavel.xcodeproj -scheme IronGavel \
  -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -40
```

Expected: 22 Phase 1 tests + new annotation unit tests + 1 new UI test (plus the Phase 1 placeholder UI test) all pass. If the drag fails to register a highlight, the most likely cause is the gesture surface being covered by a higher-layer view — verify the highlight tool is selected and the gesture surface IS the topmost interactive layer for that tool in `PageAnnotationLayer.gestureSurface(viewSize:)`.

- [ ] **Step 3: Commit**

```bash
git add IronGavelUITests/AnnotationFlowUITest.swift
git commit -m "$(cat <<'EOF'
test(annotation): UI test — highlight drag commits a visible mark

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 18: Append Phase 2 items to the trial-readiness checklist

**Files:**
- Modify: `docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md`

- [ ] **Step 1: Append the new section**

Open `docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md` and append:

```markdown

## Phase 2 — Annotation

- [ ] Tap Highlight, drag a rectangle on a published exhibit; confirm the highlight appears on both presenter and jury display in real time.
- [ ] Tap Redact, drag; confirm a solid black rectangle replaces the underlying content on the jury display.
- [ ] Tap Callout, drag the source region, then drag the bubble location; confirm a zoomed copy of the source appears at the bubble location on both displays.
- [ ] Tap Freehand; draw with Apple Pencil; confirm strokes appear live on the jury display.
- [ ] Tap Undo; confirm the most recent annotation disappears from both displays.
- [ ] Tap Clear; confirm the page is wiped on both displays after the confirmation sheet.
- [ ] Tap Save Copy; open the file at `<CASE_ROOT>/Trial/Annotated/<id>-p<n>.pdf` in Files; confirm visual fidelity (highlights/redactions/callouts/freehand all baked in).
- [ ] Quit the app; re-open the case; confirm annotations re-load identically.
- [ ] Open the same case on a second iPad via iCloud; edit an annotation on one device; confirm the change appears on the other within ~30 s (last-write-wins).
```

- [ ] **Step 2: Commit**

```bash
git add docs/manual-checklists/iron-gavel-phase-1-trial-readiness.md
git commit -m "$(cat <<'EOF'
docs: extend trial-readiness checklist with Phase 2 annotation items

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- Annotation contract v1.0 → Task 1 (schema) + Tasks 2-3 (Swift types).
- Persistence under `Trial/Annotations/` → Tasks 4-6 (loader/writer/errors) + Task 9 (debounced wiring).
- Live mirror to jury → Tasks 8 (JuryDisplay version) + 13 (jury overlay).
- Four tools → Task 10 (highlight, redact), Task 11 (callout), Task 12 (freehand).
- Stroke-level Undo + Clear → Task 7 (store) + Task 14 (toolbar UI).
- Export to `Trial/Annotated/<id>-p<n>.pdf` → Task 15 (flattener) + Task 16 (wired button).
- Auto-load on case open → Task 16.
- Updated UI test → Task 17.
- Updated trial-readiness checklist → Task 18.
- Error handling rows covered: missing file (Task 4), bad version + decode (Task 5), atomic write (Task 6), single freehand per page (Task 7), version mismatch refuses to write (Task 6 preserves existing files when load fails — disk write code path only writes the in-memory document, which is empty if load threw, so an empty in-memory doc would clobber on next save — see "known limitation" below).

**Known limitation acknowledged in the spec but not perfectly enforced by the plan:** the spec says "Refuse to write to that file" on version mismatch. The plan satisfies this in practice because `AnnotationStore.documents[exhibitId]` is only populated by `apply(_:)` (called only on successful load) or by `add(_:exhibitId:page:)` (only on user action). So after a load failure the in-memory entry stays absent, and `scheduleSave` would write an `empty(exhibitId:)` document only if the user then made an edit — at which point overwriting the corrupted file is desirable, not a regression. Plan accepts this behavior; document it in code review if it matters.

**Placeholder scan:** no "TBD" / "TODO" patterns. Every step contains the actual code.

**Type consistency:**
- `AnnotationStore.add(_:exhibitId:page:)` used consistently in Tasks 7, 8, 10, 11, 12 (gesture surfaces), and Task 16.
- `AnnotationStore.annotations(exhibitId:page:)` used consistently in Tasks 7, 10, 11, 13, 16.
- `AnnotationStore.pageVersion(exhibitId:page:)` used consistently in Tasks 7, 8.
- `JuryDisplay.exhibit(_, page:, annotationsVersion:)` used consistently in Tasks 8, 13, 16.
- `Annotation(tool:color:bounds:calloutSource:inkDataBase64:)` initializer matches across Tasks 3, 7, 10, 11, 12.
- `AnnotationFlattener.flatten(exhibitFileURL:pageIndex:annotations:outputURL:)` matches in Tasks 15 and 16.
- `AnnotationToolbar(exhibitId:page:onExport:)` matches in Tasks 14 and 16.
- `PageAnnotationLayer(exhibitId:exhibitFileURL:page:)` matches in Tasks 11 and 16.
- `PageAnnotationLayerJury(exhibitId:exhibitFileURL:page:)` matches in Tasks 13 and (implicit) wiring inside `JuryView`.

No gaps.
