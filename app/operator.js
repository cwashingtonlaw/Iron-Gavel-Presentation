/* =============================================================================
 * operator.js — the lawyer's console
 *
 * The operator sees EVERY exhibit and its true status, and can preview anything
 * (this is counsel's private screen). The one thing they cannot do is push a
 * non-admitted exhibit to the jury: the "Publish to Jury" control is gated by
 * Contract.publishGate, and the jury window re-checks the gate independently.
 * ========================================================================== */

(function () {
  "use strict";

  const el = Render.el;
  const state = {
    doc: null,
    sidecarUrl: null,
    exhibits: [],
    selectedId: null,
    publishedId: null, // what we believe is currently on the jury screen
    filter: { q: "", status: "all", party: "all" },
  };

  const stage = Stage.open();
  let juryWindow = null;

  // ---- boot ----------------------------------------------------------------
  document.addEventListener("DOMContentLoaded", function () {
    bindChrome();
    reload();
  });

  function bindChrome() {
    document.getElementById("btn-reload").addEventListener("click", reload);
    document.getElementById("btn-open-jury").addEventListener("click", openJury);
    document.getElementById("btn-blank").addEventListener("click", blankJury);

    const q = document.getElementById("filter-q");
    q.addEventListener("input", function () {
      state.filter.q = q.value.trim().toLowerCase();
      renderList();
    });
    document.getElementById("filter-status").addEventListener("change", function (e) {
      state.filter.status = e.target.value;
      renderList();
    });
    document.getElementById("filter-party").addEventListener("change", function (e) {
      state.filter.party = e.target.value;
      renderList();
    });

    document.getElementById("btn-publish").addEventListener("click", publishSelected);

    // Keyboard: Esc blanks the jury screen instantly — the courtroom panic key.
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") blankJury();
    });
  }

  async function reload() {
    setBanner("", "");
    try {
      const res = await Contract.load();
      state.doc = res.doc;
      state.sidecarUrl = res.sidecarUrl;
      state.exhibits = res.doc.exhibits;
      // Drop selection/publish if the exhibit no longer exists after a refresh.
      if (!findEx(state.selectedId)) state.selectedId = null;
      if (!findEx(state.publishedId)) state.publishedId = null;
      renderHeader();
      renderList();
      renderDetail();
      renderPublishedStrip();
    } catch (err) {
      renderFatal(err);
    }
  }

  function findEx(id) {
    return state.exhibits.find(function (e) {
      return e.id === id;
    });
  }

  // ---- header / case identity ---------------------------------------------
  function renderHeader() {
    const c = state.doc.case;
    document.getElementById("case-caption").textContent = c.caption;
    document.getElementById("case-meta").textContent = [c.docket, c.court]
      .filter(Boolean)
      .join("  •  ");
    document.getElementById("contract-badge").textContent =
      "contract v" + state.doc.contract_version;
    const gen = state.doc.generated
      ? new Date(state.doc.generated).toLocaleString()
      : "—";
    document.getElementById("generated").textContent = "ledger as of " + gen;

    const counts = tally();
    document.getElementById("counts").textContent =
      counts.admitted +
      " admitted / " +
      state.exhibits.length +
      " exhibits";
  }

  function tally() {
    const t = { total: state.exhibits.length };
    Contract.STATUSES.forEach(function (s) {
      t[s] = 0;
    });
    state.exhibits.forEach(function (e) {
      t[e.status] = (t[e.status] || 0) + 1;
    });
    return t;
  }

  // ---- exhibit list --------------------------------------------------------
  function passesFilter(ex) {
    const f = state.filter;
    if (f.status !== "all" && ex.status !== f.status) return false;
    if (f.party !== "all" && ex.party !== f.party) return false;
    if (f.q) {
      const hay = (
        ex.id +
        " " +
        ex.description +
        " " +
        (ex.witness || "") +
        " " +
        (ex.bates || "")
      ).toLowerCase();
      if (hay.indexOf(f.q) === -1) return false;
    }
    return true;
  }

  function renderList() {
    const list = document.getElementById("exhibit-list");
    list.textContent = "";
    const items = state.exhibits.filter(passesFilter);
    if (!items.length) {
      list.appendChild(Render.placeholder("No exhibits", "Adjust the filters."));
      return;
    }
    items.forEach(function (ex) {
      const row = el("button", {
        class:
          "exhibit-row" +
          (ex.id === state.selectedId ? " is-selected" : "") +
          (ex.id === state.publishedId ? " is-live" : ""),
        type: "button",
      });
      row.appendChild(el("span", { class: "ex-id", text: ex.id }));
      row.appendChild(
        el("span", { class: "ex-party party-" + ex.party.toLowerCase(), text: ex.party })
      );
      row.appendChild(el("span", { class: "ex-desc", text: ex.description }));
      row.appendChild(statusBadge(ex.status));
      if (ex.id === state.publishedId) {
        row.appendChild(el("span", { class: "live-dot", title: "On jury screen", text: "● LIVE" }));
      }
      row.addEventListener("click", function () {
        state.selectedId = ex.id;
        renderList();
        renderDetail();
      });
      list.appendChild(row);
    });
  }

  function statusBadge(status) {
    return el("span", {
      class: "badge badge-" + status,
      text: Contract.STATUS_LABEL[status] || status,
    });
  }

  // ---- detail / preview ----------------------------------------------------
  function renderDetail() {
    const host = document.getElementById("detail");
    host.textContent = "";
    const ex = findEx(state.selectedId);
    if (!ex) {
      host.appendChild(
        Render.placeholder("Select an exhibit", "Counsel preview appears here.")
      );
      document.getElementById("btn-publish").disabled = true;
      document.getElementById("publish-reason").textContent = "";
      return;
    }

    const meta = el("div", { class: "detail-meta" }, [
      el("div", { class: "detail-title" }, [
        el("span", { class: "ex-id", text: ex.id }),
        statusBadge(ex.status),
        el("span", { class: "ex-party party-" + ex.party.toLowerCase(), text: ex.party }),
      ]),
      el("div", { class: "detail-desc", text: ex.description }),
    ]);
    const facts = el("dl", { class: "facts" });
    addFact(facts, "Witness", ex.witness);
    addFact(facts, "Bates", ex.bates);
    addFact(facts, "Objection", ex.objection);
    addFact(facts, "Ruling", ex.ruling);
    addFact(facts, "Media", ex.media_type);
    addFact(facts, "File", ex.file || "(none staged)");
    addFact(facts, "Notes", ex.notes);
    meta.appendChild(facts);
    host.appendChild(meta);

    const preview = el("div", { class: "detail-preview" });
    const url = Contract.fileUrlFor(ex, state.sidecarUrl);
    preview.appendChild(Render.render(ex, url));
    host.appendChild(preview);

    // Publish control, gated.
    const gate = Contract.publishGate(ex);
    const btn = document.getElementById("btn-publish");
    btn.disabled = !gate.ok;
    btn.textContent = gate.ok
      ? "Publish " + ex.id + " to Jury"
      : "Cannot publish " + ex.id;
    document.getElementById("publish-reason").textContent = gate.ok
      ? "Admitted — cleared for the jury."
      : "🔒 " + gate.reason;
  }

  function addFact(dl, label, value) {
    if (!value) return;
    dl.appendChild(el("dt", { text: label }));
    dl.appendChild(el("dd", { text: String(value) }));
  }

  // ---- publishing ----------------------------------------------------------
  function publishSelected() {
    const ex = findEx(state.selectedId);
    const gate = Contract.publishGate(ex);
    if (!gate.ok) {
      // Belt and suspenders: the button is disabled, but never trust the UI.
      setBanner(gate.reason, "warn");
      return;
    }
    state.publishedId = ex.id;
    stage.publish(ex.id);
    setBanner("Published " + ex.id + " to the jury.", "ok");
    renderList();
    renderPublishedStrip();
  }

  function blankJury() {
    state.publishedId = null;
    stage.blank();
    setBanner("Jury screen blanked.", "ok");
    renderList();
    renderPublishedStrip();
  }

  function renderPublishedStrip() {
    const strip = document.getElementById("published-strip");
    strip.textContent = "";
    const ex = findEx(state.publishedId);
    if (!ex) {
      strip.appendChild(el("span", { class: "live-none", text: "Jury screen: BLANK" }));
      return;
    }
    strip.appendChild(el("span", { class: "live-dot", text: "● LIVE" }));
    strip.appendChild(el("span", { class: "ex-id", text: ex.id }));
    strip.appendChild(el("span", { class: "ex-desc", text: ex.description }));
  }

  function openJury() {
    const url = "jury.html" + window.location.search;
    juryWindow = window.open(url, "courtroom-jury");
    if (juryWindow) {
      juryWindow.focus();
      // Re-assert current state shortly after the jury window boots.
      setTimeout(function () {
        if (state.publishedId) stage.publish(state.publishedId);
        else stage.blank();
      }, 600);
    }
  }

  // ---- banners / fatal -----------------------------------------------------
  function setBanner(msg, kind) {
    const b = document.getElementById("banner");
    b.textContent = msg || "";
    b.className = "banner" + (msg ? " banner-" + (kind || "info") : "");
  }

  function renderFatal(err) {
    const main = document.getElementById("app");
    main.innerHTML = "";
    const box = el("div", { class: "fatal" }, [
      el("h1", { text: "Cannot load the exhibit sidecar" }),
      el("p", { class: "fatal-msg", text: err.message }),
    ]);
    if (err.detail) {
      box.appendChild(el("p", { class: "fatal-detail", text: String(err.detail) }));
    }
    box.appendChild(
      el("p", {
        class: "fatal-hint",
        text:
          "The sidecar is regenerated from the case .xlsx by the exhibit skill. " +
          "Re-run the converter and reload; do not edit exhibits.json by hand.",
      })
    );
    const retry = el("button", { class: "btn", type: "button", text: "Retry" });
    retry.addEventListener("click", function () {
      location.reload();
    });
    box.appendChild(retry);
    main.appendChild(box);
  }
})();
