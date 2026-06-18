/* =============================================================================
 * channel.js — operator <-> jury display link
 *
 * The operator console and the jury display are separate windows (typically on
 * separate monitors). They talk over a same-origin BroadcastChannel. Only two
 * commands ever cross the wire:
 *
 *   { type: "publish", id: "<exhibit id>", page?, t }   show this exhibit
 *   { type: "blank",  t }                               clear the jury screen
 *
 * The wire carries an EXHIBIT ID, never a file URL or a "render this" payload.
 * The jury window looks the id up in its OWN validated copy of the sidecar and
 * re-checks the publish gate before rendering. That way the admitted-only rule
 * is enforced on the jury side too — a stale or stray message can never put a
 * non-admitted exhibit in front of the jury.
 * ========================================================================== */

(function (global) {
  "use strict";

  const NAME = "courtroom-justice-stage";

  function open(onMessage) {
    let bc = null;
    if ("BroadcastChannel" in global) {
      bc = new BroadcastChannel(NAME);
      if (onMessage) {
        bc.onmessage = function (ev) {
          onMessage(ev.data);
        };
      }
    }

    // Fallback for environments without BroadcastChannel: localStorage events.
    function storageHandler(ev) {
      if (ev.key === NAME && ev.newValue) {
        try {
          onMessage && onMessage(JSON.parse(ev.newValue));
        } catch (_) {
          /* ignore malformed */
        }
      }
    }
    if (!bc && onMessage) {
      global.addEventListener("storage", storageHandler);
    }

    function send(msg) {
      const payload = Object.assign({ t: Date.now() }, msg);
      if (bc) {
        bc.postMessage(payload);
      } else {
        // Toggle value so repeated identical commands still fire an event.
        try {
          localStorage.setItem(NAME, JSON.stringify(payload));
        } catch (_) {
          /* storage unavailable */
        }
      }
    }

    return {
      send: send,
      publish: function (id, page) {
        send({ type: "publish", id: id, page: page || null });
      },
      blank: function () {
        send({ type: "blank" });
      },
      close: function () {
        if (bc) bc.close();
        else global.removeEventListener("storage", storageHandler);
      },
    };
  }

  global.Stage = { open: open };
})(window);
