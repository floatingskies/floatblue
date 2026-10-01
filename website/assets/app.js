/* floatblue — website behavior
   Static front-end: lists recent commits from the public GitHub API. The ISOs
   live in the repository's GitHub releases, so there is nothing to host here.
   No secrets, no tracking, no frameworks. All text is inserted via textContent. */

(function () {
  "use strict";

  var REPO = "floatingskies/floatblue";
  var API = "https://api.github.com/repos/" + REPO;

  function $id(id) { return document.getElementById(id); }

  function fetchJSON(url) {
    return fetch(url, { headers: { Accept: "application/vnd.github+json" } }).then(
      function (res) {
        if (!res.ok) {
          var err = new Error("HTTP " + res.status);
          err.status = res.status;
          return err;
        }
        return res.json();
      }
    );
  }

  /* --- Latest commits -------------------------------------------------- */

  function loadCommits() {
    var list = $id("commits");
    fetchJSON(API + "/commits?sha=main&per_page=6").then(function (data) {
      if (data instanceof Error || !data.length) {
        list.textContent = "Could not load commits right now.";
        return;
      }
      list.textContent = "";
      data.forEach(function (c) {
        var li = document.createElement("li");
        var sha = document.createElement("span");
        sha.className = "commit-sha";
        sha.textContent = c.sha.slice(0, 7);

        var msg = document.createElement("span");
        msg.className = "commit-msg";
        var a = document.createElement("a");
        a.textContent = (c.commit.message.split("\n")[0] || "").trim();
        a.href = c.html_url;
        a.title = "by " + (c.commit.author && c.commit.author.name ? c.commit.author.name : "?");
        msg.appendChild(a);

        li.appendChild(sha);
        li.appendChild(msg);
        list.appendChild(li);
      });
    }).catch(function () {
      list.textContent = "Could not reach GitHub right now.";
    });
  }

  /* --- Light / dark mode ------------------------------------------------------- */

  function initTheme() {
    var root = document.documentElement;
    var btn = $id("theme-toggle");
    var mq = window.matchMedia("(prefers-color-scheme: light)");
    var chosen = null;
    try { chosen = localStorage.getItem("floatblue-theme"); } catch (e) { /* private mode */ }

    function apply(theme) {
      root.setAttribute("data-theme", theme);
      if (btn) btn.setAttribute("aria-pressed", theme === "light" ? "true" : "false");
    }

    function current() { return root.getAttribute("data-theme") === "light" ? "light" : "dark"; }

    if (chosen) apply(chosen);
    else apply(mq.matches ? "light" : "dark");

    if (btn) {
      btn.addEventListener("click", function () {
        var next = current() === "light" ? "dark" : "light";
        chosen = next;
        apply(next);
        try { localStorage.setItem("floatblue-theme", next); } catch (e) { /* ignore */ }
      });
    }
    if (mq.addEventListener) {
      mq.addEventListener("change", function (ev) {
        if (!chosen) apply(ev.matches ? "light" : "dark");
      });
    }
  }

  loadCommits();
  initTheme();
})();