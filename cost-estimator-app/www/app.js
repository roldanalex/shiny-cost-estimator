// Small, dependency-free behaviours. Nothing here carries colour or copy.
(function () {
  "use strict";

  // 1. Summary strip: visible only while the hero estimate is scrolled out of
  //    view, so the same numbers are never shown twice on one screen.
  var heroObserver = null;
  function watchHero() {
    var hero = document.querySelector(".hero-block");
    var body = document.body;
    if (heroObserver) { heroObserver.disconnect(); heroObserver = null; }
    if (!hero || !("IntersectionObserver" in window)) {
      body.classList.remove("hero-offscreen");
      return;
    }
    heroObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        body.classList.toggle("hero-offscreen", !en.isIntersecting);
      });
    }, { threshold: 0.05 });
    heroObserver.observe(hero);
  }

  // 2. Keep scroll-padding equal to the strip height so a focused control is
  //    never hidden behind it (WCAG 2.2, focus not obscured).
  function syncStripPadding() {
    var strip = document.querySelector(".summary-strip");
    var h = strip && document.body.classList.contains("hero-offscreen") ? strip.offsetHeight : 0;
    document.documentElement.style.scrollPaddingBottom = h ? h + "px" : "";
  }

  // Shiny triggers its lifecycle events through jQuery, so bind with $.
  $(document).on("shiny:value", function (ev) {
    var id = ev.target && ev.target.id ? ev.target.id : "";
    if (/results_summary|summary_strip|results_body/.test(id)) {
      window.setTimeout(function () { watchHero(); syncStripPadding(); }, 80);
    }
  });
  $(document).on("shiny:connected", function () {
    watchHero();
    syncStripPadding();
  });
  window.addEventListener("resize", syncStripPadding);
  var mo = new MutationObserver(syncStripPadding);
  mo.observe(document.body, { attributes: true, attributeFilter: ["class"] });

  // 3. Copy-to-clipboard for the share link (button carries data-copy-target).
  document.addEventListener("click", function (ev) {
    var btn = ev.target.closest && ev.target.closest("[data-copy-target]");
    if (!btn) return;
    var src = document.querySelector(btn.getAttribute("data-copy-target"));
    if (!src) return;
    var text = src.value !== undefined ? src.value : src.textContent;
    var done = function () {
      var old = btn.textContent;
      btn.textContent = "Copied";
      btn.setAttribute("aria-live", "polite");
      window.setTimeout(function () { btn.textContent = old; }, 1800);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(src); done(); });
    } else {
      fallbackCopy(src); done();
    }
  });
  function fallbackCopy(el) {
    try {
      if (el.select) { el.select(); document.execCommand("copy"); }
    } catch (e) { /* clipboard unavailable; the text stays visible to copy by hand */ }
  }
})();

// 4. Charts inside a collapsed <details> have no size until it opens: ask
//    plotly to re-measure when a section toggles.
document.addEventListener("toggle", function (ev) {
  if (ev.target && ev.target.tagName === "DETAILS" && ev.target.open) {
    window.setTimeout(function () { window.dispatchEvent(new Event("resize")); }, 30);
  }
}, true);

// 5. Skip link first in the tab order; on phones close the inputs drawer once
//    a new estimate has rendered so the result is what the user sees.
document.addEventListener("DOMContentLoaded", function () {
  var skip = document.querySelector(".skip-link");
  if (skip && document.body.firstChild !== skip) document.body.insertBefore(skip, document.body.firstChild);
});
$(document).on("shiny:value", function (ev) {
  var id = ev.target && ev.target.id ? ev.target.id : "";
  if (!/results_body/.test(id) || window.innerWidth >= 768) return;
  var layout = document.querySelector(".bslib-sidebar-layout");
  var sidebar = layout && layout.querySelector(".sidebar");
  var toggle = layout && layout.querySelector(".collapse-toggle");
  // Only close a drawer that is actually showing (on phones it starts hidden).
  if (sidebar && toggle && sidebar.getBoundingClientRect().width > 50) {
    window.setTimeout(function () { toggle.click(); }, 150);
  }
});

// 6. "Copy link": the address bar already holds the share link.
document.addEventListener("click", function (ev) {
  var btn = ev.target.closest && ev.target.closest("[data-copy-url]");
  if (!btn) return;
  var url = window.location.href;
  var done = function (ok) {
    var old = btn.innerHTML;
    btn.innerHTML = ok ? "Link copied" : "Copy failed: use the address bar";
    btn.setAttribute("aria-live", "polite");
    window.setTimeout(function () { btn.innerHTML = old; }, 2200);
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(url).then(function () { done(true); }, function () { done(false); });
  } else { done(false); }
});
