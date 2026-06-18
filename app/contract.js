/* =============================================================================
 * contract.js — Courtroom Justice / Iron Gavel
 * The single source of truth for reading the exhibits.json sidecar.
 *
 * This module enforces the FROZEN v1.0 data contract (see exhibits.schema.json
 * and dw-exhibit-manager_SKILL-PATCH.md):
 *   - The .xlsx ledger is the system of record. This app NEVER writes case truth.
 *   - exhibit.file paths are relative to the directory containing exhibits.json
 *     (path_base === "sidecar_dir", i.e. {CASE_ROOT}/Trial/).
 *   - The app REFUSES a contract major version it does not recognize.
 *   - PUBLISH GATING: only status === "admitted" may ever be shown to the jury.
 *
 * Both the operator console and the jury display load through here, so the
 * publish gate and version refusal are enforced identically on both screens.
 * ========================================================================== */

(function (global) {
  "use strict";

  // The only contract major version this build understands. A sidecar that
  // declares a different major is refused outright rather than mis-rendered.
  const SUPPORTED_MAJOR = 1;

  const STATUSES = ["pending", "offered", "objected", "admitted", "excluded"];
  const PARTIES = ["Defense", "State", "Joint", "Court"];
  const MEDIA = ["pdf", "image", "video", "unknown"];

  // Resolve where the sidecar lives. Default mirrors the bundled sample layout
  // (app served at /app/, case at /Trial/); override with ?data=<url>.
  function dataUrl() {
    const p = new URLSearchParams(global.location.search);
    return p.get("data") || "../Trial/exhibits.json";
  }

  function ContractError(message, detail) {
    const e = new Error(message);
    e.name = "ContractError";
    e.detail = detail || null;
    return e;
  }

  function majorOf(versionString) {
    const m = /^(\d+)\./.exec(String(versionString || ""));
    return m ? parseInt(m[1], 10) : NaN;
  }

  // Shape validation. Deliberately strict on the fields the app relies on, so a
  // malformed sidecar fails loudly here instead of silently mis-displaying an
  // exhibit to a jury. (The emitter validates against the JSON Schema; this is
  // the app-side backstop for when the file is hand-touched or truncated.)
  function validate(doc) {
    if (!doc || typeof doc !== "object") {
      throw ContractError("Sidecar is not a JSON object.");
    }
    const major = majorOf(doc.contract_version);
    if (Number.isNaN(major)) {
      throw ContractError(
        "Sidecar has no readable contract_version.",
        doc.contract_version
      );
    }
    if (major !== SUPPORTED_MAJOR) {
      throw ContractError(
        "Unsupported contract version " +
          doc.contract_version +
          " — this app understands major version " +
          SUPPORTED_MAJOR +
          " only. Refusing to display rather than risk mis-reading the ledger.",
        doc.contract_version
      );
    }
    if (doc.path_base && doc.path_base !== "sidecar_dir") {
      throw ContractError(
        'Unsupported path_base "' +
          doc.path_base +
          '"; this build only resolves files relative to the sidecar directory.'
      );
    }
    if (!doc.case || typeof doc.case !== "object" || !doc.case.caption) {
      throw ContractError("Sidecar is missing case identity (case.caption).");
    }
    if (!Array.isArray(doc.exhibits)) {
      throw ContractError("Sidecar has no exhibits array.");
    }
    doc.exhibits.forEach(function (ex, i) {
      const where = "exhibit[" + i + "]" + (ex && ex.id ? " (" + ex.id + ")" : "");
      if (!ex || typeof ex !== "object") {
        throw ContractError(where + " is not an object.");
      }
      ["id", "party", "description", "status", "media_type"].forEach(function (k) {
        if (typeof ex[k] !== "string") {
          throw ContractError(where + ' is missing required field "' + k + '".');
        }
      });
      if (typeof ex.file !== "string") {
        throw ContractError(where + ' is missing required field "file".');
      }
      if (STATUSES.indexOf(ex.status) === -1) {
        throw ContractError(where + ' has unknown status "' + ex.status + '".');
      }
      if (MEDIA.indexOf(ex.media_type) === -1) {
        throw ContractError(where + ' has unknown media_type "' + ex.media_type + '".');
      }
    });
    return doc;
  }

  // ---- The publish gate. This is the whole point of the app. ---------------
  // An exhibit may be shown to the jury ONLY if it is admitted AND has a file
  // that the app can actually render. Anything else is a hard "no".
  function publishGate(ex) {
    if (!ex) return { ok: false, reason: "No exhibit selected." };
    if (ex.status !== "admitted") {
      return {
        ok: false,
        reason:
          "Exhibit " +
          ex.id +
          " is “" +
          ex.status +
          "”. Only ADMITTED exhibits may be published to the jury.",
      };
    }
    if (!ex.file || !ex.file.trim()) {
      return {
        ok: false,
        reason: "Exhibit " + ex.id + " is admitted but has no file staged.",
      };
    }
    if (ex.media_type === "unknown") {
      return {
        ok: false,
        reason:
          "Exhibit " +
          ex.id +
          " is admitted but its file type (" +
          (fileExt(ex.file) || "unknown") +
          ") cannot be displayed on the jury screen.",
      };
    }
    return { ok: true, reason: "" };
  }

  function isPublishable(ex) {
    return publishGate(ex).ok;
  }

  function fileExt(file) {
    const m = /\.([A-Za-z0-9]+)$/.exec(file || "");
    return m ? m[1].toLowerCase() : "";
  }

  // Resolve an exhibit's file to an absolute URL relative to the sidecar dir,
  // honoring path_base === "sidecar_dir".
  function fileUrlFor(ex, sidecarAbsUrl) {
    if (!ex || !ex.file) return null;
    return new URL(ex.file, sidecarAbsUrl).href;
  }

  // Load + version-gate + validate the sidecar. Returns { doc, sidecarUrl }.
  async function load(url) {
    const target = url || dataUrl();
    const sidecarUrl = new URL(target, global.location.href).href;
    let resp;
    try {
      resp = await fetch(sidecarUrl, { cache: "no-store" });
    } catch (e) {
      throw ContractError(
        "Could not reach the sidecar at " +
          sidecarUrl +
          ". Is the server running? (See README — run serve.py.)",
        String(e)
      );
    }
    if (!resp.ok) {
      throw ContractError(
        "Sidecar not found (" + resp.status + ") at " + sidecarUrl,
        resp.status
      );
    }
    let doc;
    try {
      doc = await resp.json();
    } catch (e) {
      throw ContractError("Sidecar is not valid JSON.", String(e));
    }
    validate(doc);
    return { doc: doc, sidecarUrl: sidecarUrl };
  }

  const STATUS_LABEL = {
    pending: "Pending",
    offered: "Offered",
    objected: "Objected",
    admitted: "Admitted",
    excluded: "Excluded",
  };

  global.Contract = {
    SUPPORTED_MAJOR: SUPPORTED_MAJOR,
    STATUSES: STATUSES,
    PARTIES: PARTIES,
    MEDIA: MEDIA,
    STATUS_LABEL: STATUS_LABEL,
    dataUrl: dataUrl,
    load: load,
    validate: validate,
    publishGate: publishGate,
    isPublishable: isPublishable,
    fileUrlFor: fileUrlFor,
    fileExt: fileExt,
    majorOf: majorOf,
  };
})(window);
