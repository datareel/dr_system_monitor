/*
 * DataReel System Monitor (DRSM) Web interface script.
 * Theme, live refresh, wall display, relative times, filters and
 * table sorting. Plain ES5, no libraries. The pages work without it.
 */
(function () {
  "use strict";

  var root = document.documentElement;

  function store(kind, key, value) {
    // Storage can be blocked, in a private window for example
    try {
      var s = window[kind];
      if (value === undefined) return s.getItem("drsm." + key);
      if (value === null) s.removeItem("drsm." + key);
      else s.setItem("drsm." + key, value);
    } catch (e) {}
    return null;
  }

  // Theme first, before the page paints
  function systemTheme() {
    return (window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches) ? "light" : "dark";
  }
  root.setAttribute("data-theme", store("localStorage", "theme") || systemTheme());
  if (store("localStorage", "wall") === "1") root.classList.add("wall");

  function $all(sel, el) { return Array.prototype.slice.call((el || document).querySelectorAll(sel)); }

  // ---------- Relative times ----------

  function ago(epoch) {
    var s = Math.round(Date.now() / 1000 - epoch);
    if (s < 0) s = 0;
    if (s < 45) return "just now";
    if (s < 90) return "1 min ago";
    if (s < 3600) return Math.round(s / 60) + " min ago";
    if (s < 5400) return "1 hour ago";
    if (s < 86400) return Math.round(s / 3600) + " hours ago";
    if (s < 172800) return "yesterday";
    return Math.round(s / 86400) + " days ago";
  }

  function updateTimes() {
    $all("time[data-epoch]").forEach(function (t) {
      var e = parseInt(t.getAttribute("data-epoch"), 10);
      if (e > 0) t.textContent = ago(e);
    });
  }

  // ---------- Live refresh ----------

  var refreshSecs = 0, left = 0, paused = false, ringLen = 56.55;

  function setRing() {
    var ring = document.querySelector(".ring-fill");
    if (!ring) return;
    var frac = (paused || refreshSecs <= 0) ? 1 : left / refreshSecs;
    ring.style.strokeDashoffset = String(ringLen * (1 - frac));
  }

  function reload() {
    store("sessionStorage", "scroll." + location.pathname + location.search, String(window.scrollY || 0));
    location.reload();
  }

  function tick() {
    updateTimes();
    if (paused || refreshSecs <= 0) return;
    left -= 1;
    if (left <= 0) {
      // Wait for a hidden tab or a busy search box, reload when back
      var active = document.activeElement;
      var typing = active && (active.tagName === "INPUT" || active.tagName === "SELECT") && active.value;
      if (document.hidden || typing) { left = 0; return; }
      reload();
      return;
    }
    setRing();
  }

  function setPaused(p) {
    paused = p;
    store("localStorage", "paused", p ? "1" : null);
    var b = document.querySelector('[data-action="refresh"]');
    if (b) {
      b.setAttribute("aria-pressed", p ? "false" : "true");
      b.title = p ? "Auto refresh is paused, select to resume" : "Auto refresh every " + refreshSecs + " seconds, select to pause";
      var label = b.querySelector(".refresh-label");
      if (label) label.textContent = p ? "Paused" : "Live";
    }
    if (!p) left = refreshSecs;
    setRing();
  }

  // ---------- Filters ----------

  function setupFilters(box) {
    var scope = document.getElementById(box.getAttribute("data-filter-scope"));
    if (!scope) return;
    var items = scope.tagName === "TABLE" ? $all("tbody tr", scope) : $all("[data-state]", scope);
    var text = box.querySelector("[data-filter-text]");
    var group = box.querySelector("[data-filter-group]");
    var stateBtns = $all("[data-filter-state]", box);
    var emptyMsg = scope.parentNode.querySelector(".empty.filtered") || (scope.parentNode.parentNode && scope.parentNode.parentNode.querySelector(".empty.filtered"));
    var key = "filter." + location.pathname;
    var state = "all";

    function apply() {
      var q = text ? text.value.trim().toLowerCase() : "";
      var g = group ? group.value : "";
      var shown = 0;
      items.forEach(function (el) {
        var st = el.getAttribute("data-state");
        var ok = true;
        if (state === "problem") ok = st !== "OK";
        else if (state !== "all") ok = st === state;
        if (ok && g) ok = el.getAttribute("data-group") === g;
        if (ok && q) ok = (el.getAttribute("data-text") || "").indexOf(q) !== -1;
        el.hidden = !ok;
        if (ok) shown++;
      });
      stateBtns.forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-filter-state") === state); });
      if (emptyMsg) emptyMsg.hidden = shown !== 0 || items.length === 0;
      store("sessionStorage", key, JSON.stringify({ q: text ? text.value : "", g: g, s: state }));
    }

    function setState(s) {
      state = s;
      if (s !== "all" && stateBtns.length && !stateBtns.some(function (b) { return b.getAttribute("data-filter-state") === s; })) state = "problem";
      apply();
    }

    try {
      var saved = JSON.parse(store("sessionStorage", key) || "null");
      if (saved) {
        if (text) text.value = saved.q || "";
        if (group) group.value = saved.g || "";
        state = saved.s || "all";
      }
    } catch (e) {}

    if (text) text.addEventListener("input", apply);
    if (group) group.addEventListener("change", apply);
    stateBtns.forEach(function (b) {
      b.addEventListener("click", function () { setState(b.getAttribute("data-filter-state")); });
    });
    $all("[data-set-filter]").forEach(function (a) {
      a.addEventListener("click", function () {
        if (text) text.value = "";
        if (group) group.value = "";
        setState(a.getAttribute("data-set-filter") === "all" ? "all" : a.getAttribute("data-set-filter"));
      });
    });
    apply();
  }

  // ---------- Table sorting ----------

  function setupSort(table) {
    var heads = $all("thead th", table);
    var body = table.tBodies[0];
    function sortBy(i, dir) {
      var type = heads[i].getAttribute("data-sort");
      var rows = Array.prototype.slice.call(body.rows);
      rows.sort(function (a, b) {
        var x = a.cells[i].getAttribute("data-v") || a.cells[i].textContent;
        var y = b.cells[i].getAttribute("data-v") || b.cells[i].textContent;
        var r = type === "num" ? (parseFloat(x) || 0) - (parseFloat(y) || 0) : x.localeCompare(y, undefined, { numeric: true, sensitivity: "base" });
        if (r === 0) r = (a.cells[0].getAttribute("data-v") || "").localeCompare(b.cells[0].getAttribute("data-v") || "");
        return dir === "asc" ? r : -r;
      });
      rows.forEach(function (r) { body.appendChild(r); });
      heads.forEach(function (h) { h.classList.remove("sorted-asc", "sorted-desc"); h.removeAttribute("aria-sort"); });
      heads[i].classList.add("sorted-" + dir);
      heads[i].setAttribute("aria-sort", dir === "asc" ? "ascending" : "descending");
      store("sessionStorage", "sort." + location.pathname, i + ":" + dir);
    }
    heads.forEach(function (h, i) {
      if (!h.hasAttribute("data-sort")) return;
      h.tabIndex = 0;
      function go() {
        var dir = h.classList.contains("sorted-desc") ? "asc" : (h.classList.contains("sorted-asc") ? "desc" : (h.getAttribute("data-sort") === "num" ? "desc" : "asc"));
        sortBy(i, dir);
      }
      h.addEventListener("click", go);
      h.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); go(); } });
    });
    var saved = (store("sessionStorage", "sort." + location.pathname) || "").split(":");
    if (saved.length === 2 && heads[+saved[0]]) sortBy(+saved[0], saved[1]);
    else {
      for (var i = 0; i < heads.length; i++) {
        if (heads[i].classList.contains("sorted-desc")) { sortBy(i, "desc"); break; }
        if (heads[i].classList.contains("sorted-asc")) { sortBy(i, "asc"); break; }
      }
    }
  }

  // ---------- Wall display ----------

  function toggleWall() {
    var on = !root.classList.contains("wall");
    root.classList.toggle("wall", on);
    store("localStorage", "wall", on ? "1" : null);
    try {
      if (on && root.requestFullscreen && !document.fullscreenElement) root.requestFullscreen();
      else if (!on && document.fullscreenElement && document.exitFullscreen) document.exitFullscreen();
    } catch (e) {}
  }

  // ---------- Start ----------

  function openTarget() {
    var id = location.hash.slice(1);
    var el = id && document.getElementById(id);
    if (el && el.tagName === "DETAILS") el.open = true;
  }

  document.addEventListener("DOMContentLoaded", function () {
    refreshSecs = parseInt(document.body.getAttribute("data-refresh"), 10) || 0;
    left = refreshSecs;
    var rb = document.querySelector('[data-action="refresh"]');
    if (refreshSecs <= 0 && rb) rb.hidden = true;
    setPaused(store("localStorage", "paused") === "1");

    document.addEventListener("click", function (e) {
      var b = e.target.closest ? e.target.closest("[data-action]") : null;
      if (!b) return;
      var a = b.getAttribute("data-action");
      if (a === "theme") {
        var t = root.getAttribute("data-theme") === "light" ? "dark" : "light";
        root.setAttribute("data-theme", t);
        store("localStorage", "theme", t === systemTheme() ? null : t);
      }
      else if (a === "refresh") setPaused(!paused);
      else if (a === "wall") toggleWall();
      else if (a === "expand-all" || a === "collapse-all") {
        $all("details.section").forEach(function (d) { d.open = a === "expand-all"; });
      }
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && root.classList.contains("wall")) toggleWall();
    });
    document.addEventListener("visibilitychange", function () {
      if (!document.hidden && !paused && refreshSecs > 0 && left <= 0) reload();
    });

    $all("[data-filter-scope]").forEach(setupFilters);
    $all("table.sortable").forEach(setupSort);
    openTarget();
    window.addEventListener("hashchange", openTarget);

    var y = store("sessionStorage", "scroll." + location.pathname + location.search);
    if (y !== null && !location.hash) {
      store("sessionStorage", "scroll." + location.pathname + location.search, null);
      window.scrollTo(0, parseInt(y, 10) || 0);
    }

    updateTimes();
    setInterval(tick, 1000);
  });
})();
