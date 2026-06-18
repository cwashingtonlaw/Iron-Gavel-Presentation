# Iron Gavel — Courtroom Justice

A dependency-free, dual-screen **trial-presentation app** for displaying
exhibits to a jury. It is the consumer end of the D&W exhibit pipeline: a skill
keeps the case's exhibit ledger in `Case Tables.xlsx` and projects it to a
read-only JSON sidecar (`Trial/exhibits.json`); this app reads that sidecar and
lets counsel put **admitted** exhibits in front of the jury — and nothing else.

```
 Case Tables.xlsx  ──emit_exhibits_json.py──▶  Trial/exhibits.json  ──▶  Iron Gavel
   (system of record)        (frozen v1.0 contract)                   (this app, read-only)
```

## The one rule

> **Only `status: "admitted"` exhibits may be shown to the jury.**

This publish gate is the whole point of the app. It is enforced in two
independent places (`app/contract.js → publishGate`):

1. **Operator console** — the *Publish to Jury* button is disabled for anything
   that isn't admitted, with the reason shown.
2. **Jury display** — re-checks the gate against its *own* validated copy of the
   sidecar before rendering anything. A stale or stray command can never put a
   non-admitted exhibit on the jury screen.

An exhibit is publishable only if it is `admitted`, has a staged `file`, and is
a renderable `media_type` (`pdf` / `image` / `video`). An admitted file the app
can't render (e.g. a `.docx`, `media_type: "unknown"`) is held back too.

## Run it

The bundled sample case (`Trial/`) runs out of the box. No build, no install —
just Python 3 stdlib:

```bash
python3 serve.py            # serves the sample case, opens the operator console
```

Point it at a real case (any folder containing `Trial/exhibits.json`):

```bash
python3 serve.py --case-root "/path/to/CASE_ROOT" --port 8000
```

Then:

1. The **operator console** opens. It lists every exhibit with its true status;
   counsel can preview any of them (this is counsel's private screen).
2. Click **⧉ Open Jury Display** to open the jury window — drag it to the second
   monitor / projector and double-click for fullscreen.
3. Select an admitted exhibit and click **Publish to Jury**. It appears on the
   jury display.
4. **⛔ Blank jury screen** (or the **Esc** key) instantly clears the jury
   display. Blank is the default, safe state.

The two windows sync over a same-origin `BroadcastChannel`; only an exhibit *id*
crosses the wire, never a file or a "render this" payload.

## The data contract (frozen v1.0)

The app is built against `exhibits.schema.json`. Key invariants:

- `contract_version` is `"1.0"`. The app **refuses** a major version it doesn't
  recognize rather than risk mis-reading the ledger.
- `path_base: "sidecar_dir"` — every `exhibit.file` is resolved **relative to
  the directory holding `exhibits.json`** (i.e. `Trial/`).
- `status ∈ pending | offered | objected | admitted | excluded`.
- `media_type ∈ pdf | image | video | unknown` (derived from file extension).

The `.xlsx` is authoritative. **The app never writes case truth back.** If the
sidecar and the spreadsheet disagree, re-run the converter
(`emit_exhibits_json.py`) — never hand-edit `exhibits.json`. Click
**↻ Reload ledger** in the console to re-read the sidecar after a refresh.

## Files

| Path | Role |
| --- | --- |
| `serve.py` | Local read-only HTTP server (routes the app + the case `Trial/`). |
| `app/index.html` · `operator.js` | Operator console (sees all, gates publishing). |
| `app/jury.html` · `jury.js` | Jury display (shows only published, re-gates). |
| `app/contract.js` | Loads, version-gates, validates the sidecar; the publish gate. |
| `app/channel.js` | Operator ↔ jury sync (BroadcastChannel, id-only wire). |
| `app/render.js` | Media renderer (pdf / image / video). |
| `app/styles.css` | Console + jury display styling. |
| `Trial/` | Bundled **sample** case so the app runs immediately. |
| `emit_exhibits_json.py` · `exhibits.schema.json` | The upstream emitter + frozen contract. |
| `exhibits.json.SAMPLE` · `dw-exhibit-manager_SKILL-PATCH.md` | Sample sidecar + skill integration notes. |

## Notes for a live courtroom

- Runs fully offline/local; the server sets `Cache-Control: no-store` so a
  reload always reflects the current sidecar.
- **Esc** blanks the jury screen — the panic key. Use it whenever a sidebar or
  objection is in progress.
- The jury window starts blank and returns to blank on any refused command.
