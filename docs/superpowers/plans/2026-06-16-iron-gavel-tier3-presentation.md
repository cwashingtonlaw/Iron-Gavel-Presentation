# Iron Gavel — Tier 3 Presentation Power Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Work the phases in order (callouts → whiteboard → AirPlay); each phase ends green and is independently shippable.

**Goal:** Ship three TrialPad-class features — multiple manageable callouts, a whiteboard/diagram canvas mirrored to the jury, and AirPlay wireless output with a mirroring-safety guard.

**Architecture:** Reuse existing patterns. Callouts already render N-up via `ForEach` in both annotation layers; add per-callout delete. Whiteboard reuses the entire annotation engine via a reserved synthetic `exhibitId` and a new `.whiteboard` `JuryDisplay` case. AirPlay reuses the existing external-display scene (it already drives `JuryView` over AirPlay-as-second-display); add a route picker + a mirroring-detection warning.

**Tech Stack:** Swift 5.9, SwiftUI, PencilKit, AVKit (`AVRoutePickerView`), PDFKit, XCTest/XCUITest, XcodeGen.

**Reference:** `docs/superpowers/specs/2026-06-16-iron-gavel-tier3-presentation-design.md`.

---

## Conventions

- Repo root: `/Volumes/WD_4TB/Code/Iron-Gavel-Presentation`. Branch: `iron-gavel-tier3-presentation` (create off `main`).
- After adding files: `xcodegen generate`. Build/test on `iPad (A16)`:
  ```
  xcodebuild -project IronGavel.xcodeproj -scheme IronGavel -destination 'platform=iOS Simulator,name=iPad (A16)' test 2>&1 | tail -40
  ```
- Baseline at branch start: **124 tests passing**; keep green.
- The `Case` model property `case` is a keyword — access as `` kase.`case` ``.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## File Structure

```
IronGavel/Annotation/AnnotationStore.swift          # +remove(id:…)  (+updateBounds optional)
IronGavel/Annotation/Views/PageAnnotationLayer.swift # per-callout delete badge (presenter)
IronGavel/Annotation/Views/CalloutBubble.swift       # +shadow
IronGavel/State/JuryDisplay.swift                    # +.whiteboard
IronGavel/State/AppState.swift                        # whiteboard + airplay surface
IronGavel/Jury/JuryView.swift                         # +.whiteboard branch
IronGavel/Presenter/WhiteboardCanvas.swift            # NEW presenter canvas
IronGavel/Presenter/WhiteboardToolbar.swift           # NEW reduced toolbar
IronGavel/Presenter/PresenterScene.swift              # whiteboard + airplay wiring
IronGavel/Presenter/PresenterToolbar.swift            # +whiteboard +airplay buttons
IronGavel/Presentation/AirPlayRoutePicker.swift       # NEW AVRoutePickerView wrapper
IronGavel/Presentation/ScreenMonitor.swift            # NEW UIScreen connect/disconnect → screenCount
```

---

# PHASE 1 — Multiple manageable callouts

## Task 1: `AnnotationStore.remove(id:exhibitId:page:)`

**Files:** Modify `IronGavel/Annotation/AnnotationStore.swift`; create `IronGavelTests/Annotation/AnnotationStoreRemoveTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

@MainActor
final class AnnotationStoreRemoveTests: XCTestCase {
    private func callout(_ tag: CGFloat) -> Annotation {
        Annotation(tool: .callout, color: .red,
                   bounds: NormalizedRect(x: tag, y: tag, w: 0.1, h: 0.1),
                   calloutSource: NormalizedRect(x: 0, y: 0, w: 0.1, h: 0.1))
    }

    func test_remove_deletes_only_target_and_bumps_version() {
        let store = AnnotationStore()
        var changed: [String] = []
        store.onChange = { changed.append($0) }
        let a = callout(0.1); let b = callout(0.2)
        store.add(a, exhibitId: "D-001", page: 0)
        store.add(b, exhibitId: "D-001", page: 0)
        let v0 = store.pageVersion(exhibitId: "D-001", page: 0)

        store.remove(id: a.id, exhibitId: "D-001", page: 0)

        let remaining = store.annotations(exhibitId: "D-001", page: 0)
        XCTAssertEqual(remaining.map(\.id), [b.id])
        XCTAssertGreaterThan(store.pageVersion(exhibitId: "D-001", page: 0), v0)
        XCTAssertEqual(changed.last, "D-001")
    }

    func test_remove_unknown_id_is_noop() {
        let store = AnnotationStore()
        let a = callout(0.1)
        store.add(a, exhibitId: "D-001", page: 0)
        store.remove(id: UUID(), exhibitId: "D-001", page: 0)
        XCTAssertEqual(store.annotations(exhibitId: "D-001", page: 0).count, 1)
    }

    func test_two_callouts_coexist() {
        let store = AnnotationStore()
        store.add(callout(0.1), exhibitId: "D-001", page: 0)
        store.add(callout(0.2), exhibitId: "D-001", page: 0)
        let list = store.annotations(exhibitId: "D-001", page: 0)
        XCTAssertEqual(list.filter { $0.tool == .callout }.count, 2)
    }
}
```

- [ ] **Step 2: Run — expect `value of type 'AnnotationStore' has no member 'remove'`.**

- [ ] **Step 3: Implement** — add to `AnnotationStore` (after `clear`):

```swift
    func remove(id: UUID, exhibitId: String, page: Int) {
        guard var doc = documents[exhibitId] else { return }
        let key = String(page)
        guard var list = doc.pages[key] else { return }
        let before = list.count
        list.removeAll { $0.id == id }
        guard list.count != before else { return }
        doc.pages[key] = list
        doc.lastModified = ISO8601DateFormatter().string(from: Date())
        documents[exhibitId] = doc
        bumpVersion(exhibitId: exhibitId, page: page)
        onChange?(exhibitId)
    }
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(annotation): per-annotation remove(id:)`).

---

## Task 2: Per-callout delete badge on the presenter + bubble shadow

**Files:** Modify `IronGavel/Annotation/Views/CalloutBubble.swift`, `IronGavel/Annotation/Views/PageAnnotationLayer.swift`

- [ ] **Step 1: Add a shadow to `CalloutBubble`** — in `CalloutBubble.body`, change the inner `ZStack { sourceImage… }` modifier chain. Find:

```swift
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityIdentifier("annotation.callout.\(annotation.id)")
```
Replace with:
```swift
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityIdentifier("annotation.callout.\(annotation.id)")
```

- [ ] **Step 2: Add the delete badge in the presenter layer** — in `PageAnnotationLayer`, replace the `.callout` arm of `rendered(annotation:in:)`. Find:

```swift
        case .callout:
            CalloutBubble(annotation: annotation, exhibitFileURL: exhibitFileURL, pageIndex: page)
```
Replace with:
```swift
        case .callout:
            ZStack(alignment: .topTrailing) {
                CalloutBubble(annotation: annotation, exhibitFileURL: exhibitFileURL, pageIndex: page)
                if state.currentTool == nil, let b = annotation.bounds {
                    Button {
                        state.annotationStore.remove(id: annotation.id, exhibitId: exhibitId, page: page)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .background(Circle().fill(.white).padding(3))
                    }
                    .accessibilityIdentifier("annotation.callout.delete.\(annotation.id)")
                    .position(
                        x: (b.x + b.w) * size.width,
                        y: b.y * size.height
                    )
                }
            }
```

> The badge appears only when no drawing tool is selected, so it never competes with `CalloutGestureModifier`'s drag. The jury layer (`PageAnnotationLayerJury`) is unchanged — it has `allowsHitTesting(false)` and shows no badge.

- [ ] **Step 3: Build + test** — 124 still pass (no test asserts callout internals beyond the new store test). **Step 4: Commit** (`feat(annotation): delete individual callouts on presenter; bubble shadow`).

---

## Task 3: UI smoke — two callouts, delete one

**Files:** Create `IronGavelUITests/MultiCalloutUITest.swift`

> Driving the two-stage callout gesture by raw coordinates is flaky; instead seed two callouts via a fixture flag and assert the layer renders two, then delete one. Add a tiny seeding hook.

- [ ] **Step 1: Add a seeding hook in `IronGavelApp.loadUITestFixtureIfRequested()`** — after `state.apply(case: kase, …)`:

```swift
        if ProcessInfo.processInfo.arguments.contains("--ui-test-seed-callouts"),
           let first = kase.exhibits.first(where: { $0.mediaType == .pdf && $0.status == .admitted }) {
            let src = NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.2)
            state.annotationStore.add(Annotation(tool: .callout, color: .red,
                bounds: NormalizedRect(x: 0.1, y: 0.5, w: 0.25, h: 0.25), calloutSource: src),
                exhibitId: first.id, page: 0)
            state.annotationStore.add(Annotation(tool: .callout, color: .blue,
                bounds: NormalizedRect(x: 0.6, y: 0.5, w: 0.25, h: 0.25), calloutSource: src),
                exhibitId: first.id, page: 0)
            state.select(first)
        }
```

- [ ] **Step 2: UI test**

```swift
import XCTest

final class MultiCalloutUITest: XCTestCase {
    func test_two_callouts_render_and_one_deletes() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture", "--ui-test-seed-callouts"]
        app.launch()

        // No drawing tool active by default → delete badges visible.
        let firstBadge = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'annotation.callout.delete.'"))
        XCTAssertTrue(firstBadge.element(boundBy: 0).waitForExistence(timeout: 10))
        XCTAssertEqual(firstBadge.count, 2)

        firstBadge.element(boundBy: 0).tap()
        // One badge remains.
        let remaining = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'annotation.callout.delete.'"))
        XCTAssertTrue(remaining.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertEqual(remaining.count, 1)
    }
}
```

- [ ] **Step 3: `xcodegen generate` + test** — all pass (≥ 125). **Step 4: Commit** (`test(annotation): UI smoke for multiple callouts + delete`).

---

# PHASE 2 — Whiteboard / live diagram canvas

## Task 4: `.whiteboard` JuryDisplay case

**Files:** Modify `IronGavel/State/JuryDisplay.swift`; create `IronGavelTests/State/JuryDisplayWhiteboardTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

final class JuryDisplayWhiteboardTests: XCTestCase {
    func test_whiteboard_equatable_by_version() {
        XCTAssertEqual(JuryDisplay.whiteboard(annotationsVersion: 1),
                       JuryDisplay.whiteboard(annotationsVersion: 1))
        XCTAssertNotEqual(JuryDisplay.whiteboard(annotationsVersion: 1),
                          JuryDisplay.whiteboard(annotationsVersion: 2))
    }
}
```

- [ ] **Step 2: Run — expect `type 'JuryDisplay' has no member 'whiteboard'`.**

- [ ] **Step 3: Implement** — add the case to `JuryDisplay`:

```swift
enum JuryDisplay: Equatable {
    case empty
    case blank
    case exhibit(Exhibit, page: Int, annotationsVersion: Int)
    case whiteboard(annotationsVersion: Int)
    // ...existing computed properties unchanged...
}
```

- [ ] **Step 4: Run — expect a NEW failure:** non-exhaustive `switch` in `AppState.persistPublishState` and/or `JuryView.content`. Fix `persistPublishState` now by adding a branch (find the `switch juryDisplay { … case .empty:` block):

```swift
        case .whiteboard:
            publishStateStore.clear()
```
(JuryView is handled in Task 6; if the build also flags JuryView here, add a temporary `case .whiteboard: EmptyView()` and replace it in Task 6.)

- [ ] **Step 5: Run — pass. Step 6: Commit** (`feat(state): add .whiteboard JuryDisplay case`).

---

## Task 5: AppState whiteboard surface

**Files:** Modify `IronGavel/State/AppState.swift`; create `IronGavelTests/State/AppStateWhiteboardTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

@MainActor
final class AppStateWhiteboardTests: XCTestCase {
    func test_showWhiteboard_publishes_and_resets_viewport() {
        let state = AppState()
        state.setJuryViewport(NormalizedRect(x: 0.1, y: 0.1, w: 0.2, h: 0.2))
        state.showWhiteboard()
        guard case .whiteboard = state.juryDisplay else { return XCTFail("not whiteboard") }
        XCTAssertTrue(state.juryViewport.isFull)
    }

    func test_drawing_on_whiteboard_bumps_published_version() {
        let state = AppState()
        state.showWhiteboard()
        let v0 = state.juryDisplay.annotationsVersion ?? -1
        state.annotationStore.add(
            Annotation(tool: .freehand, color: .red, inkDataBase64: Data().base64EncodedString()),
            exhibitId: AppState.whiteboardExhibitId, page: 0)
        let v1 = state.juryDisplay.annotationsVersion ?? -1
        XCTAssertGreaterThan(v1, v0)
    }

    func test_clearWhiteboard_empties_page() {
        let state = AppState()
        state.showWhiteboard()
        state.annotationStore.add(
            Annotation(tool: .freehand, color: .red, inkDataBase64: Data().base64EncodedString()),
            exhibitId: AppState.whiteboardExhibitId, page: 0)
        state.clearWhiteboard()
        XCTAssertTrue(state.annotationStore.annotations(exhibitId: AppState.whiteboardExhibitId, page: 0).isEmpty)
    }
}
```

> `JuryDisplay.annotationsVersion` already returns `nil` for non-exhibit cases — extend it to also cover `.whiteboard` in Step 3.

- [ ] **Step 2: Run — expect failures (`whiteboardExhibitId`, `showWhiteboard`, `clearWhiteboard` missing).**

- [ ] **Step 3: Implement** — in `AppState` add the constant + methods, and update `handleAnnotationChange`. First, the constant near the top of the class:

```swift
    static let whiteboardExhibitId = "__whiteboard__"
```
Add methods (next to `blank()` / `restore()`):
```swift
    func showWhiteboard() {
        let v = annotationStore.pageVersion(exhibitId: Self.whiteboardExhibitId, page: 0)
        juryDisplay = .whiteboard(annotationsVersion: v)
        lastStatusBanner = nil
        juryViewport = .full
        persistPublishState()
    }

    func clearWhiteboard() {
        annotationStore.clear(exhibitId: Self.whiteboardExhibitId, page: 0)
    }
```
Update `handleAnnotationChange(for:)`. Find:
```swift
    private func handleAnnotationChange(for exhibitId: String) {
        if case let .exhibit(published, page, _) = juryDisplay, published.id == exhibitId {
            let v = annotationStore.pageVersion(exhibitId: exhibitId, page: page)
            juryDisplay = .exhibit(published, page: page, annotationsVersion: v)
        }
        scheduleSave(exhibitId: exhibitId)
    }
```
Replace with:
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
Finally, in `JuryDisplay.swift`, extend `annotationsVersion`:
```swift
    var annotationsVersion: Int? {
        switch self {
        case let .exhibit(_, _, v): return v
        case let .whiteboard(v): return v
        default: return nil
        }
    }
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(state): whiteboard publish + draw-mirroring + clear`).

---

## Task 6: WhiteboardCanvas + JuryView branch

**Files:** Create `IronGavel/Presenter/WhiteboardCanvas.swift`; modify `IronGavel/Jury/JuryView.swift`

- [ ] **Step 1: Implement `WhiteboardCanvas.swift`** (shared board background + annotation layer; `isPresenter` switches which layer)

```swift
import SwiftUI

/// The blank diagram surface. Reuses the annotation engine via the reserved
/// `AppState.whiteboardExhibitId`, page 0. Presenter is interactive; jury is read-only.
struct WhiteboardCanvas: View {
    let isPresenter: Bool
    @Environment(AppState.self) private var state

    var body: some View {
        ViewportContainer(viewport: state.juryViewport) {
            ZStack {
                boardBackground
                if isPresenter {
                    PageAnnotationLayer(
                        exhibitId: AppState.whiteboardExhibitId,
                        exhibitFileURL: nil,
                        page: 0
                    )
                } else {
                    PageAnnotationLayerJury(
                        exhibitId: AppState.whiteboardExhibitId,
                        exhibitFileURL: nil,
                        page: 0
                    )
                }
            }
        }
        .accessibilityIdentifier(isPresenter ? "whiteboard.presenter" : "whiteboard.jury")
    }

    private var boardBackground: some View {
        Rectangle()
            .fill(boardColor)
            .overlay(Rectangle().stroke(Color.gray.opacity(0.25), lineWidth: 1))
    }

    private var boardColor: Color {
        // Always a light board so ink reads; on a black jury background a soft
        // off-white card still presents cleanly.
        state.settings.juryBackground == .white ? .white : Color(white: 0.97)
    }
}
```

- [ ] **Step 2: Add the `.whiteboard` branch to `JuryView.content`** — find the `switch state.juryDisplay { … }` and add a case (replacing any temporary placeholder from Task 4):

```swift
        case .whiteboard:
            WhiteboardCanvas(isPresenter: false)
```

- [ ] **Step 3: `xcodegen generate` + test** — 124 + phase-1/earlier pass; compiles with exhaustive switches. **Step 4: Commit** (`feat(whiteboard): WhiteboardCanvas + jury rendering`).

---

## Task 7: WhiteboardToolbar (reduced annotation controls)

**Files:** Create `IronGavel/Presenter/WhiteboardToolbar.swift`

- [ ] **Step 1: Implement** (freehand + highlight + color + undo + clear + save; no callout/redact)

```swift
import SwiftUI

struct WhiteboardToolbar: View {
    let onExport: () -> Void
    @Environment(AppState.self) private var state
    @State private var showClearConfirm = false

    private var exhibitId: String { AppState.whiteboardExhibitId }
    private let page = 0

    var body: some View {
        HStack(spacing: 14) {
            toolButton(.freehand, icon: "pencil.tip")
            toolButton(.highlight, icon: "highlighter")

            Divider().frame(height: 22)
            colorPicker
            Divider().frame(height: 22)

            Button { state.annotationStore.undo(exhibitId: exhibitId, page: page) } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .accessibilityIdentifier("whiteboard.undo")

            Button { showClearConfirm = true } label: {
                Label("Clear", systemImage: "trash")
            }
            .accessibilityIdentifier("whiteboard.clear")

            Spacer()

            Button(action: onExport) {
                Label("Save PDF", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("whiteboard.export")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .sheet(isPresented: $showClearConfirm) {
            ClearPageConfirm(
                page: page,
                onConfirm: { showClearConfirm = false; state.clearWhiteboard() },
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
        .accessibilityIdentifier("whiteboard.tool.\(tool.rawValue)")
    }

    private var colorPicker: some View {
        HStack(spacing: 8) {
            ForEach(AnnotationColor.allCases, id: \.self) { c in
                Button { state.currentColor = c } label: {
                    Circle()
                        .fill(c.uiColor)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.primary, lineWidth: state.currentColor == c ? 2 : 0))
                }
                .accessibilityIdentifier("whiteboard.color.\(c.rawValue)")
            }
        }
    }
}
```

- [ ] **Step 2: Build (no test yet) — compiles. Step 3: Commit** (`feat(whiteboard): reduced toolbar (freehand/highlight/color/clear/save)`).

---

## Task 8: Whiteboard save-to-PDF helper

**Files:** Create `IronGavel/Presenter/WhiteboardExporter.swift`; create `IronGavelTests/Presenter/WhiteboardExporterTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

final class WhiteboardExporterTests: XCTestCase {
    func test_export_writes_nonempty_pdf() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let ann = [Annotation(tool: .highlight, color: .yellow,
                              bounds: NormalizedRect(x: 0.1, y: 0.1, w: 0.3, h: 0.2))]
        let out = tmp.appendingPathComponent("board.pdf")
        try WhiteboardExporter().export(annotations: ann, to: out)

        let data = try Data(contentsOf: out)
        XCTAssertGreaterThan(data.count, 0)
    }
}
```

- [ ] **Step 2: Run — expect `Cannot find 'WhiteboardExporter'`.**

- [ ] **Step 3: Implement** — reuses `AnnotationFlattener.flatten(image:annotations:outputURL:)` over a blank base image:

```swift
import Foundation
import UIKit

struct WhiteboardExporter {
    /// 4:3 flip-chart canvas; white base so ink/highlight read on paper.
    private let canvas = CGSize(width: 1600, height: 1200)

    func export(annotations: [Annotation], to outputURL: URL) throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let base = UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))
        }
        guard let cg = base.cgImage else { return }
        try AnnotationFlattener().flatten(image: cg, annotations: annotations, outputURL: outputURL)
    }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(whiteboard): save board to PDF via existing flattener`).

---

## Task 9: Wire whiteboard into PresenterScene + PresenterToolbar

**Files:** Modify `IronGavel/Presenter/PresenterToolbar.swift`, `IronGavel/Presenter/PresenterScene.swift`

> `PresenterToolbar`'s current header is `let openCaseAction` + `let importAction` (from the self-contained-cases phase). Add a whiteboard callback. **Verify the exact current initializer in the file before editing.**

- [ ] **Step 1: Add the whiteboard button to `PresenterToolbar`** — add a stored callback to the struct:

```swift
    let whiteboardAction: () -> Void
```
Add the button (after the Import button):
```swift
            Button(action: whiteboardAction) {
                Label("Whiteboard", systemImage: "rectangle.and.pencil.and.ellipsis")
            }
            .disabled(state.currentCase == nil)
            .accessibilityIdentifier("toolbar.whiteboard")
```

- [ ] **Step 2: Wire `PresenterScene`** — add presenter-local state near the other `@State`s:

```swift
    @State private var whiteboardActive = false
    @State private var whiteboardToast: String?
    private let whiteboardExporter = WhiteboardExporter()
```
Pass the action where `PresenterToolbar` is constructed (add the new argument to the existing call):
```swift
                PresenterToolbar(
                    openCaseAction: { showFolderPicker = true },
                    importAction: { showImporter = true },
                    whiteboardAction: { whiteboardActivate() }
                )
```
Swap the preview surface: wherever `PreviewPane()` is rendered in the presenter body, gate it:
```swift
                if whiteboardActive {
                    whiteboardSurface
                } else {
                    PreviewPane()
                }
```
Add the surface + helpers in `PresenterScene`:
```swift
    private var whiteboardSurface: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Whiteboard").font(Theme.Typography.caseTitle)
                Spacer()
                if isWhiteboardPublished {
                    Button("Hide from Jury") { state.blank() }
                        .accessibilityIdentifier("whiteboard.hideJury")
                } else {
                    Button("Show to Jury") { state.showWhiteboard() }
                        .accessibilityIdentifier("whiteboard.showJury")
                }
                Button("Close") { whiteboardActive = false; state.currentTool = nil }
                    .accessibilityIdentifier("whiteboard.close")
            }
            .tint(Theme.Palette.accent)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.xs)

            WhiteboardCanvas(isPresenter: true)
                .padding(.horizontal, 12)

            WhiteboardToolbar(onExport: exportWhiteboard)

            if let toast = whiteboardToast {
                Text(toast).font(.caption).padding(6)
                    .background(Color.green.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 8)
    }

    private var isWhiteboardPublished: Bool {
        if case .whiteboard = state.juryDisplay { return true }
        return false
    }

    private func whiteboardActivate() {
        whiteboardActive = true
        state.currentTool = .freehand
    }

    private func exportWhiteboard() {
        guard let folder = state.caseFolderURL else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let out = folder.appendingPathComponent("Trial/Annotated/Whiteboard-\(stamp).pdf")
        let annotations = state.annotationStore.annotations(
            exhibitId: AppState.whiteboardExhibitId, page: 0)
        do {
            try whiteboardExporter.export(annotations: annotations, to: out)
            whiteboardToast = "Saved to \(out.path)"
        } catch {
            whiteboardToast = "Could not save board: \(error)"
        }
    }
```

> Adjust names to the actual `PresenterScene` body structure (it composes a sidebar + preview); the key change is gating the center preview on `whiteboardActive` and adding the toolbar argument. If `PresenterToolbar` is constructed in more than one place, update each.

- [ ] **Step 3: `xcodegen generate` + test** — 124 + earlier pass. **Step 4: Commit** (`feat(whiteboard): presenter entry, show/hide-to-jury, export wiring`).

---

## Task 10: Whiteboard UI smoke

**Files:** Create `IronGavelUITests/WhiteboardUITest.swift`

- [ ] **Step 1: UI test**

```swift
import XCTest

final class WhiteboardUITest: XCTestCase {
    func test_open_whiteboard_and_show_to_jury() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-fixture"]
        app.launch()

        let wb = app.buttons["toolbar.whiteboard"]
        XCTAssertTrue(wb.waitForExistence(timeout: 10))
        wb.tap()

        XCTAssertTrue(app.buttons["whiteboard.tool.freehand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["whiteboard.clear"].exists)

        let show = app.buttons["whiteboard.showJury"]
        XCTAssertTrue(show.waitForExistence(timeout: 5))
        show.tap()
        // After publishing, the control flips to Hide.
        XCTAssertTrue(app.buttons["whiteboard.hideJury"].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: `xcodegen generate` + test** — all pass. **Step 3: Commit** (`test(whiteboard): UI smoke for open + publish`).

---

# PHASE 3 — AirPlay wireless output

## Task 11: ScreenMonitor + AppState screen-count surface

**Files:** Create `IronGavel/Presentation/ScreenMonitor.swift`; modify `IronGavel/State/AppState.swift`; create `IronGavelTests/State/AppStateAirPlayTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import IronGavel

@MainActor
final class AppStateAirPlayTests: XCTestCase {
    func test_mirroring_suspected_truth_table() {
        let state = AppState()
        state.screenCount = 1; state.externalConnected = false
        XCTAssertFalse(state.airPlayMirroringSuspected)

        state.screenCount = 2; state.externalConnected = true   // our jury scene drives it
        XCTAssertFalse(state.airPlayMirroringSuspected)

        state.screenCount = 2; state.externalConnected = false  // a mirror, no jury scene
        XCTAssertTrue(state.airPlayMirroringSuspected)
    }
}
```

- [ ] **Step 2: Run — expect `has no member 'screenCount'` / `airPlayMirroringSuspected`.**

- [ ] **Step 3: Implement** — in `AppState` add:

```swift
    var screenCount: Int = 1

    /// A second physical/AirPlay screen exists but our external jury scene did NOT
    /// connect → the OS is mirroring the presenter UI (private notes) to the room.
    var airPlayMirroringSuspected: Bool { screenCount > 1 && !externalConnected }
```
Create `ScreenMonitor.swift`:
```swift
import UIKit

/// Observes screen connect/disconnect and reports the current screen count.
/// Used to detect AirPlay/HDMI *mirroring* (a second screen with no jury scene).
@MainActor
final class ScreenMonitor {
    private var observers: [NSObjectProtocol] = []
    var onChange: ((Int) -> Void)?

    func start() {
        let nc = NotificationCenter.default
        let update = { [weak self] (_: Notification) in
            self?.onChange?(UIScreen.screens.count)
        }
        observers.append(nc.addObserver(forName: UIScreen.didConnectNotification,
                                        object: nil, queue: .main, using: update))
        observers.append(nc.addObserver(forName: UIScreen.didDisconnectNotification,
                                        object: nil, queue: .main, using: update))
        onChange?(UIScreen.screens.count)
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
```

- [ ] **Step 4: Run — pass. Step 5: Commit** (`feat(airplay): screen-count tracking + mirroring detection`).

---

## Task 12: AirPlayRoutePicker

**Files:** Create `IronGavel/Presentation/AirPlayRoutePicker.swift`

- [ ] **Step 1: Implement** (system route chooser wrapper)

```swift
import SwiftUI
import AVKit

/// Presents the system AirPlay route chooser so the attorney can pick the
/// courtroom receiver in-app. Screen output then flows through the existing
/// external-display jury scene (see design doc, Feature 3).
struct AirPlayRoutePicker: UIViewRepresentable {
    var tint: UIColor = .label

    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.activeTintColor = tint
        v.tintColor = tint
        v.prioritizesVideoDevices = true
        v.accessibilityIdentifier = "airplay.routePicker"
        return v
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.activeTintColor = tint
        uiView.tintColor = tint
    }
}
```

- [ ] **Step 2: Build — compiles. Step 3: Commit** (`feat(airplay): in-app AVRoutePickerView wrapper`).

---

## Task 13: Presenter AirPlay button + mirroring warning banner

**Files:** Modify `IronGavel/Presenter/PresenterToolbar.swift`, `IronGavel/Presenter/PresenterScene.swift`

- [ ] **Step 1: Add the AirPlay control to `PresenterToolbar`** — embed the route picker directly (it is its own button) after the whiteboard button:

```swift
            AirPlayRoutePicker(tint: UIColor(Theme.Palette.accent))
                .frame(width: 40, height: 40)
                .accessibilityIdentifier("toolbar.airplay")
```
(`import AVKit`/`import UIKit` as needed at the top of `PresenterToolbar.swift`.)

- [ ] **Step 2: Wire the screen monitor + warning in `PresenterScene`** — add state + monitor:

```swift
    @State private var screenMonitor = ScreenMonitor()
```
On the presenter root view, start/stop the monitor and pipe its count into `AppState`:
```swift
        .onAppear {
            screenMonitor.onChange = { count in state.screenCount = count }
            screenMonitor.start()
        }
        .onDisappear { screenMonitor.stop() }
```
Add the warning banner as a top overlay on the presenter content:
```swift
        .overlay(alignment: .top) {
            if state.airPlayMirroringSuspected {
                Text("Screen Mirroring is showing your private notes to the courtroom. In Control Center, use the courtroom display as a second display, not a mirror.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Palette.live)
                    .accessibilityIdentifier("airplay.mirroringWarning")
            }
        }
```

> `Theme.Palette.live` is the existing red. If a different alert affordance exists in the codebase, prefer it; the key is a prominent, dismissible-by-fixing warning tied to `airPlayMirroringSuspected`.

- [ ] **Step 3: `xcodegen generate` + test** — 124 + earlier pass (the warning is hidden with one screen in the simulator, so no UI test regression). **Step 4: Commit** (`feat(airplay): route-picker button + mirroring warning banner`).

---

## Task 14: VideoController external-playback invariant + manual checklist

**Files:** Create `IronGavelTests/Video/VideoControllerExternalPlaybackTests.swift`; create `docs/manual-checklists/airplay-courtroom-output.md`

- [ ] **Step 1: Invariant test** (documents that we keep video inside the jury layout, not AirPlay handoff)

```swift
import XCTest
import AVFoundation
@testable import IronGavel

@MainActor
final class VideoControllerExternalPlaybackTests: XCTestCase {
    func test_player_does_not_hand_off_video_to_airplay() {
        // We render video into the jury AVPlayerLayer on the external screen;
        // AVPlayer handoff (allowsExternalPlayback) would yank it out of our layout.
        let controller = VideoController()
        XCTAssertFalse(controller.player.allowsExternalPlayback)
    }
}
```

> If `VideoController.player.allowsExternalPlayback` is already `false` (the default) this passes immediately and pins the behavior. If a future change sets it true, this test catches the regression. If the controller currently sets it true, set it to `false` in `VideoController` init and note the reason.

- [ ] **Step 2: Manual checklist** — `docs/manual-checklists/airplay-courtroom-output.md`:

```markdown
# Manual checklist — AirPlay courtroom output

Requires: an iPad + an Apple TV / AirPlay receiver on the same network.

1. Open a case. Tap the AirPlay button (`toolbar.airplay`) → pick the courtroom receiver.
2. If you used Control Center "Screen Mirroring":
   - Confirm the iPad shows the RED "Screen Mirroring is showing your private notes…" banner
     when the receiver is mirroring (jury scene NOT yet driving the display).
3. Confirm that once the external/jury scene connects, the receiver shows **JuryView**
   (blank/exhibit/whiteboard) and NOT the presenter sidebar/tools, and the red banner clears.
4. Publish an exhibit → it appears on the courtroom display.
5. Open the Whiteboard → Show to Jury → draw → strokes appear on the courtroom display live.
6. Play a video exhibit → it plays inside the jury layout on the receiver (not full-screen
   AVPlayer handoff).
7. Disconnect AirPlay → presenter shows "external disconnected" state; no crash.
```

- [ ] **Step 3: `xcodegen generate` + test** — all pass (final count ≥ 124 + new unit/UI tests). **Step 4: Commit** (`test(airplay): external-playback invariant + manual checklist`).

---

## Done criteria

- **Callouts:** two callouts coexist on presenter + jury; each can be deleted individually; bubbles read as distinct cards.
- **Whiteboard:** `toolbar.whiteboard` opens the board; freehand/highlight/color/undo/clear work; Show to Jury mirrors live; Save PDF writes to `Trial/Annotated/`.
- **AirPlay:** route picker present; mirroring of the presenter UI raises the red warning; the external jury scene drives the courtroom display over AirPlay exactly as over HDMI; video stays inside the jury layout.
- All existing tests stay green (124 baseline + new). Then run **superpowers:finishing-a-development-branch**.

## Integration risks (for reviewers)

- **`JuryDisplay` exhaustiveness:** adding `.whiteboard` forces `switch` updates in `JuryView.content`, `AppState.persistPublishState`, and `JuryDisplay.annotationsVersion`. Build errors will pinpoint each; do not silence with `default:` in `persistPublishState` (it would hide future cases).
- **`PresenterToolbar` initializer arity** changes twice (whiteboard callback in Phase 2; AirPlay button is self-contained). Update every construction site in `PresenterScene`.
- **Whiteboard sidecar:** `scheduleSave` will persist `__whiteboard__.json` into `Trial/Annotations/`. Harmless, but note it appears alongside real exhibit annotation docs; v1 does not reload it.
- **Delete-badge vs. gesture:** the callout delete badge is gated on `currentTool == nil` so it never competes with `CalloutGestureModifier`; keep that guard.
- **AirPlay mirroring detection is heuristic** (`screenCount > 1 && !externalConnected`). It is correct for the common cases but should be validated against the manual checklist on real hardware before relying on it in court.
