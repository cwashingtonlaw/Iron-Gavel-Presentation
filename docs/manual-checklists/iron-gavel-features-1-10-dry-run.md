# Iron Gavel — Features 1–10 On-Device Dry Run

Walk this on the M5 iPad (`iPad17,2`) with the courtroom display connected, before relying on
any of the new features in trial. Each item maps to a shipped feature (1–10).

## Setup
- [ ] Iron Gavel reinstalled from `main` and launched on the iPad.
- [ ] External courtroom display connected (USB-C→HDMI or AirPlay second-display).
- [ ] A real case opened with at least one multi-page PDF, one large photo (≥12 MP),
      one video, and several exhibits across two parties / witnesses.

## #1 — Settings actually apply
- [ ] Settings → raise **Highlight opacity**; draw a highlight → it is visibly more opaque
      on both presenter and jury, and in an exported annotated PDF (Export from the toolbar).
- [ ] Settings → raise **Freehand pen width**; draw on an exhibit and on the whiteboard →
      strokes are thicker on presenter and jury.

## #7 — Witness grouping
- [ ] Sidebar grouping picker → **Witness**; exhibits group by witness alphabetically with
      **No Witness** last. Switching back to Party/Folder still works.

## #6 — Spotlight
- [ ] Tap **Spotlight**, drag a region on a published exhibit → everything outside the box
      dims on presenter AND jury, with a live-colored border.
- [ ] Publish a different exhibit or change page → spotlight clears automatically.
- [ ] Tap the exhibit once (tiny drag) with Spotlight on → spotlight clears.

## #4 — Long-document navigation
- [ ] Open the multi-page PDF → footer shows **Page N of M**.
- [ ] Use the page menu to jump to the last page; ◀/▶ disable at the ends and clamp.

## #3 — Exhibit reordering
- [ ] Long-press-drag a sidebar row within its section to a new position → order holds.
- [ ] Reopen the case → the new order persisted.

## #8 — Trial-record export
- [ ] Toolbar **Export Record** → alert shows the saved path. In Files, the
      `Trial/Record-<stamp>/` folder contains `exhibit-list.csv`, `audit-log.jsonl`,
      `dispositions.json`, and an `Annotated/` copy of any exported PDFs.

## #5 — Presentation binder
- [ ] On an exhibit at a chosen page, tap **Add to Binder**; repeat for 2–3 exhibits/pages.
- [ ] Tap **Binder** → reorder and delete steps; tap a step → jury jumps to it.
- [ ] Use the **◀ Step N of M ▶** control → presenter and jury walk the run-of-show; an
      unadmitted exhibit in the binder does not publish.
- [ ] Reopen the case → binder steps persisted.

## #2 — Backup & restore
- [ ] Case Library → swipe a case → **Back Up** → save to Files/iCloud; confirm the folder
      exists with `exhibits.json` and `Trial/`.
- [ ] **Restore Backup from Files…** → pick that folder → it reappears in the on-iPad list
      and opens correctly.

## #9 — Large-exhibit performance
- [ ] Publish the large photo → it appears promptly on presenter and jury with no stutter;
      switching pages/exhibits back and forth stays smooth (no re-decode hitch).
- [ ] Open several large PDFs in succession → no memory warning / crash.

## #10 — External-display reconnect robustness
- [ ] With an exhibit published, unplug the courtroom display, wait, replug → the jury
      display resumes showing the SAME exhibit/page (not blank), and the presenter's
      **External: Connected** indicator returns. No crash.
- [ ] Power-cycle test: with the external display ALREADY connected, force-quit and relaunch
      Iron Gavel → the jury window comes up as JuryView (never a stuck blank window).
