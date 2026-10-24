/*
 * DRSM documentation: theme toggle, mobile menu, copy buttons and
 * heading anchors. Works without it, the pages are plain HTML.
 */
(function () {
  var root = document.documentElement;
  function store(k, v) {
    try {
      if (v === undefined) return localStorage.getItem(k);
      if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, v);
    } catch (e) { return null; }
  }
  var saved = store("drsm-docs-theme");
  if (saved) root.setAttribute("data-theme", saved);

  document.addEventListener("DOMContentLoaded", function () {
    var sys = window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
    if (!root.getAttribute("data-theme")) root.setAttribute("data-theme", sys);

    document.querySelectorAll("[data-action]").forEach(function (b) {
      b.addEventListener("click", function () {
        var a = b.getAttribute("data-action");
        if (a === "theme") {
          var t = root.getAttribute("data-theme") === "light" ? "dark" : "light";
          root.setAttribute("data-theme", t);
          store("drsm-docs-theme", t === sys ? null : t);
        } else if (a === "menu") {
          var open = root.classList.toggle("nav-open");
          b.setAttribute("aria-expanded", open ? "true" : "false");
        }
      });
    });
    document.querySelectorAll(".sidebar a").forEach(function (a) {
      a.addEventListener("click", function () { root.classList.remove("nav-open"); });
    });

    document.querySelectorAll("pre").forEach(function (pre) {
      if (!navigator.clipboard) return;
      var b = document.createElement("button");
      b.className = "copy";
      b.type = "button";
      b.textContent = "Copy";
      b.addEventListener("click", function () {
        var c = pre.cloneNode(true);
        c.querySelectorAll(".copy, .p, .r").forEach(function (n) { n.remove(); });
        navigator.clipboard.writeText(c.textContent.replace(/\n$/, "")).then(function () {
          b.textContent = "Copied";
          setTimeout(function () { b.textContent = "Copy"; }, 1500);
        });
      });
      pre.appendChild(b);
    });

    document.querySelectorAll(".content h2[id], .content h3[id]").forEach(function (h) {
      var a = document.createElement("a");
      a.className = "anchor";
      a.href = "#" + h.id;
      a.setAttribute("aria-label", "Link to this section");
      a.textContent = "#";
      h.appendChild(a);
    });
  });
})();
