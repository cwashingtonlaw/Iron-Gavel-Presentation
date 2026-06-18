/* =============================================================================
 * jury.js — the jury display (second monitor / projector)
 *
 * Shows ONLY what the operator publishes, and re-enforces the publish gate
 * itself: it loads its own validated copy of the sidecar and, on every publish
 * command, looks the id up and runs Contract.publishGate before rendering. If
 * the exhibit is not admitted (or unknown, or has no file), it refuses and
 * stays blank. The default state is blank — the safe state in a courtroom.
 * ========================================================================== */

(function () {
  "use strict";

  const el = Render.el;
  const state = { doc: null, sidecarUrl: null, exhibits: [], currentId: null };

  document.addEventListener("DOMContentLoaded", function () {
    Stage.open(onCommand);
    boot();
    // Click anywhere to toggle true fullscreen for the courtroom monitor.
    document.getElementById("stage").addEventListener("dblclick", toggleFullscreen);
  });

  async function boot() {
    try {
      const res = await Contract.load();
      state.doc = res.doc;
      state.sidecarUrl = res.sidecarUrl;
      state.exhibits = res.doc.exhibits;
      blank(); // always start blank
    } catch (err) {
      showError(err.message);
    }
  }

  function findEx(id) {
    return state.exhibits.find(function (e) {
      return e.id === id;
    });
  }

  function onCommand(msg) {
    if (!msg || typeof msg !== "object") return;
    if (msg.type === "blank") {
      blank();
      return;
    }
    if (msg.type === "publish") {
      publish(msg.id, msg.page);
    }
  }

  function publish(id, page) {
    const ex = findEx(id);
    // Independent re-check: the jury screen NEVER renders on trust alone.
    const gate = Contract.publishGate(ex);
    if (!gate.ok) {
      // A non-admitted id reaching the jury window is blocked here, silently to
      // the jury (just blank) — the operator console is where reasons surface.
      blank();
      return;
    }
    state.currentId = id;
    const url = Contract.fileUrlFor(ex, state.sidecarUrl);
    const stage = document.getElementById("stage");
    stage.classList.remove("is-blank");
    stage.textContent = "";
    stage.appendChild(Render.render(ex, url, { page: page, autoplay: false }));
  }

  function blank() {
    state.currentId = null;
    const stage = document.getElementById("stage");
    stage.classList.add("is-blank");
    stage.textContent = "";
  }

  function showError(message) {
    const stage = document.getElementById("stage");
    stage.classList.remove("is-blank");
    stage.textContent = "";
    stage.appendChild(
      el("div", { class: "jury-error" }, [
        el("div", { class: "jury-error-title", text: "Display unavailable" }),
        el("div", { class: "jury-error-msg", text: message }),
      ])
    );
  }

  function toggleFullscreen() {
    const d = document;
    if (!d.fullscreenElement) {
      (d.documentElement.requestFullscreen || function () {}).call(d.documentElement);
    } else if (d.exitFullscreen) {
      d.exitFullscreen();
    }
  }
})();
