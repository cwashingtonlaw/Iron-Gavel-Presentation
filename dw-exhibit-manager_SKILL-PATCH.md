# SKILL.md Patch — dw-exhibit-manager-crim → Courtroom Justice sidecar

Add the section below to `dw-exhibit-manager-crim/SKILL.md`. It instructs the
skill to emit/refresh the `exhibits.json` sidecar after every change to the
exhibit ledger, so the Courtroom Justice app always reads current truth.

Install the two support files into the skill folder:

```
dw-exhibit-manager-crim/
  SKILL.md                       ← add the block below
  scripts/
    emit_exhibits_json.py        ← the converter (tested)
    exhibits.schema.json         ← the frozen v1.0 contract
```

---

## ▼ PASTE INTO SKILL.md (new section, after the ledger-write section)

### Courtroom Justice Sidecar (exhibits.json)

The exhibit ledger in `Case Tables.xlsx` is the system of record. The Courtroom
Justice trial-presentation app consumes a **read-only JSON projection** of that
ledger. This skill MUST refresh that projection after any change to exhibit
data, so the courtroom app never shows stale status.

**When to emit.** Immediately after writing the exhibit sheet, on any of:
mark offered / objection logged / ruling entered / admitted / excluded; add or
renumber an exhibit; pre-mark a new exhibit; or on explicit request
("refresh the exhibit sidecar", "update Courtroom Justice", "rebuild exhibits.json").

**How to emit.** Run the deterministic converter — never hand-write the JSON:

```bash
python3 "{SKILL_DIR}/scripts/emit_exhibits_json.py" \
  --workbook "{CASE_ROOT}/Case Tables.xlsx" \
  --case-root "{CASE_ROOT}" \
  --schema "{SKILL_DIR}/scripts/exhibits.schema.json"
```

The script reads the sheet whose name contains "Exhibit", validates the result
against the frozen schema, and writes `{CASE_ROOT}/Trial/exhibits.json`
atomically. If a `Case` sheet (key/value rows: caption, docket, court) exists it
is used for case identity; otherwise pass `--caption/--docket/--court`.

**Hard rules.**
- The app reads this file; it never writes case truth back. The .xlsx stays
  authoritative. If the two ever disagree, re-run the converter — the JSON is
  always regenerated from the .xlsx, never edited by hand.
- Publish-gating lives in the app: only `status: "admitted"` exhibits can be
  shown to the jury. This skill's only job is to report status accurately;
  it does not decide what may be displayed.
- If the converter exits non-zero, the previous good sidecar is preserved.
  Report the FATAL line to the attorney and fix the ledger — do not work around
  it by editing JSON.
- Contract is frozen at `contract_version: "1.0"`. Changing field names or the
  path convention is a breaking change: bump the version in BOTH the schema and
  the app, never silently.

**Column expectations.** The converter matches headers flexibly (see `ALIASES`
in the script). It needs at minimum an exhibit-number column and a description
column. It derives `status` from a single Status column if present, else from
offered / objection / ruling / admitted / excluded columns
(precedence: excluded > admitted > objected > offered > pending). If the firm's
Exhibit sheet uses headers the script does not recognize, add them to `ALIASES`
— do not change the logic.

---

## Data contract summary (the seam, frozen v1.0)

`{CASE_ROOT}/Trial/exhibits.json`:
- `path_base: "sidecar_dir"` — every `exhibit.file` is relative to the folder
  holding this file (`{CASE_ROOT}/Trial/`). **This resolves the ambiguity in
  the original build brief §4**, which said "relative to CASE_ROOT" but showed
  `Exhibits_Admitted/...` paths (relative to Trial/). Frozen answer: relative to
  the sidecar (Trial/). Build the app to this; correct the brief.
- `status ∈ pending | offered | objected | admitted | excluded`.
- `media_type ∈ pdf | image | video | unknown` (derived from file extension).
- Admitted files conventionally live in `Trial/Exhibits_Admitted/`, everything
  else in `Trial/Exhibits_Pending/` — the converter places them there when the
  sheet gives no explicit path.

This contract is the first thing the app is built against and should not move
once Courtroom Justice Phase 1 begins.
