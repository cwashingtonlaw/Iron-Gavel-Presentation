/* =============================================================================
 * render.js — shared exhibit renderer
 *
 * Turns an exhibit + its resolved file URL into DOM, by media_type. Used by the
 * operator preview pane and the jury display so a published exhibit looks the
 * same on both screens. Pure view code: it does NOT decide what is allowed to
 * be shown — callers gate on Contract.publishGate before reaching here for the
 * jury screen.
 * ========================================================================== */

(function (global) {
  "use strict";

  function el(tag, attrs, children) {
    const node = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        if (k === "class") node.className = attrs[k];
        else if (k === "text") node.textContent = attrs[k];
        else node.setAttribute(k, attrs[k]);
      });
    }
    (children || []).forEach(function (c) {
      node.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    });
    return node;
  }

  function placeholder(title, sub) {
    return el("div", { class: "placeholder" }, [
      el("div", { class: "placeholder-title", text: title }),
      el("div", { class: "placeholder-sub", text: sub || "" }),
    ]);
  }

  // Returns a DOM node rendering the exhibit's media, or a graceful placeholder.
  function render(ex, fileUrl, opts) {
    opts = opts || {};
    if (!fileUrl) {
      return placeholder(ex.id, "No file staged for this exhibit.");
    }
    switch (ex.media_type) {
      case "pdf": {
        const frame = el("iframe", {
          class: "media media-pdf",
          src: fileUrl + (opts.page ? "#page=" + opts.page : ""),
          title: ex.id + " — " + ex.description,
        });
        return frame;
      }
      case "image": {
        const img = el("img", {
          class: "media media-image",
          src: fileUrl,
          alt: ex.id + " — " + ex.description,
        });
        img.onerror = function () {
          img.replaceWith(placeholder(ex.id, "Image could not be loaded."));
        };
        return img;
      }
      case "video": {
        const v = el("video", {
          class: "media media-video",
          src: fileUrl,
          controls: "controls",
          preload: "metadata",
        });
        if (opts.autoplay) v.setAttribute("autoplay", "autoplay");
        v.onerror = function () {
          v.replaceWith(placeholder(ex.id, "Video could not be loaded."));
        };
        return v;
      }
      default:
        return placeholder(
          ex.id,
          "File type cannot be displayed (" + (ex.file || "no file") + ")."
        );
    }
  }

  global.Render = { render: render, el: el, placeholder: placeholder };
})(window);
