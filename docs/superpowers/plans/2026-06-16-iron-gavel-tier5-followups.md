# Iron Gavel — Tier 5 Follow-ups (deferred integration features)

Delivered in Tier 5:
- **Clerk's exhibit-list export** (`ExhibitListExporter`) → `Trial/exhibit-list.csv`, toolbar button.
- **Audit trail** (`AuditLog`) → append-only `Trial/audit-log.jsonl`; publish/blank/restore/disposition events recorded with timestamps.
- **Disposition logging** (`DispositionLog` + `DispositionSheet`) → `Trial/dispositions.json`; log objection/ruling/notes live without touching the generated `exhibits.json`.

## Deferred: live status write-back affecting the publish gate

Letting the attorney change an exhibit's *status* (admitted/excluded/...) from the bench and have the publish gate honor it live is intentionally deferred — it is the invasive part and needs careful design:

- Introduce a `TrialRecord` sidecar (`Trial/trial-record.json`) of per-exhibit overrides `{ status?, objection?, ruling? }`, written atomically (reuse `AnnotationWriter`'s temp+rename pattern).
- `AppState` keeps the original loaded `Case` and derives an **effective** case by applying overrides; `currentCase` becomes the effective one so `publishSelected`'s `status == .admitted` gate and the auto-blank-on-downgrade logic both operate on live status.
- Refresh `selectedExhibit` to the effective exhibit after an override.
- On case load, merge any existing `trial-record.json`.
- UI: a status picker in the disposition sheet (or a dedicated bench panel).
- Tests: effective-status derivation, publish gate honoring an override, downgrade auto-blank triggered by an override.

This was scoped out to avoid destabilizing the well-tested publish core in this pass; the disposition log already captures objection/ruling for the record in the meantime.
