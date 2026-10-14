// --- tower force patch ---
(function () {
  try {
    var ua = navigator.userAgent || "";
    var meta = document.getElementById("startMeta");
    var btn = document.getElementById("startBtn");
    var tag = document.getElementById("consoleTag");
    var rail = document.getElementById("railState");
    var dot = document.getElementById("railDot");
    if (meta) meta.textContent = "UA: " + ua.slice(0, 80);
    if (/PlayStation/i.test(ua)) {
      window.fw_str = window.fw_str || "13.60";
      if (typeof fwIsValid !== "undefined") fwIsValid = true;
      if (btn) { btn.classList.add("ready"); btn.setAttribute("aria-disabled", "false"); }
      if (tag) { tag.className = "tag ok"; tag.textContent = "READY"; }
      if (rail) rail.textContent = "JB READY";
      if (dot) dot.classList.add("live");
      if (meta) meta.textContent = "Forced ready — tap START (" + (window.fw_str || "?") + ")";
    }
  } catch (e) {
    var m = document.getElementById("startMeta");
    if (m) m.textContent = "patch err: " + e;
  }
})();
