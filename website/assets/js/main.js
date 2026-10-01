/* Vampire Game - public website.
 * Small, dependency-free progressive enhancement. The page is fully readable without any of this;
 * the script only adds the menu, the ember effect, scroll reveals and the controls tabs.
 */
(function () {
  'use strict';

  var doc = document;
  var root = doc.documentElement;
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function $(sel, ctx) { return (ctx || doc).querySelector(sel); }
  function $$(sel, ctx) { return Array.prototype.slice.call((ctx || doc).querySelectorAll(sel)); }

  /* ------------------------------------------------------------ Header */
  var header = $('#site-header');
  var toggle = $('.nav-toggle');
  var nav = $('#site-nav');

  function onScroll() {
    if (header) header.classList.toggle('scrolled', window.scrollY > 24);
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  function setNav(open) {
    if (!header || !toggle) return;
    header.classList.toggle('nav-open', open);
    toggle.setAttribute('aria-expanded', String(open));
  }
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      setNav(toggle.getAttribute('aria-expanded') !== 'true');
    });
    nav.addEventListener('click', function (e) {
      if (e.target.closest('a')) setNav(false);
    });
    doc.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
        setNav(false);
        toggle.focus();
      }
    });
  }

  /* Highlight the nav link of the section in view. */
  var links = $$('.nav-links a');
  var byId = {};
  links.forEach(function (a) { byId[a.getAttribute('href').slice(1)] = a; });
  if ('IntersectionObserver' in window && links.length) {
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        links.forEach(function (a) { a.removeAttribute('aria-current'); });
        var a = byId[en.target.id];
        if (a) a.setAttribute('aria-current', 'true');
      });
    }, { rootMargin: '-45% 0px -50% 0px' });
    Object.keys(byId).forEach(function (id) {
      var s = doc.getElementById(id);
      if (s) spy.observe(s);
    });
    var hero = doc.getElementById('top');
    if (hero) new IntersectionObserver(function (entries) {
      if (entries[0].isIntersecting) links.forEach(function (a) { a.removeAttribute('aria-current'); });
    }, { threshold: 0.5 }).observe(hero);
  }

  /* ------------------------------------------------------------ Reveals */
  var reveals = $$('.reveal').filter(function (el) { return !el.closest('.hero'); });
  if ('IntersectionObserver' in window && !reduceMotion) {
    var io = new IntersectionObserver(function (entries, obs) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add('in'); obs.unobserve(en.target); }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add('in'); });
  }

  /* ------------------------------------------------------------ Card spotlight */
  $$('.card, .link-card').forEach(function (card) {
    card.addEventListener('pointermove', function (e) {
      var r = card.getBoundingClientRect();
      card.style.setProperty('--mx', (e.clientX - r.left) + 'px');
      card.style.setProperty('--my', (e.clientY - r.top) + 'px');
    });
  });

  /* ------------------------------------------------------------ Tabs (controls, feedback hub)
   * Every .tabs[role=tablist] group is independent: its tabs point at panels with aria-controls. */
  $$('.tabs[role="tablist"]').forEach(function (group) {
    var tabs = $$('.tab', group);
    var panels = tabs.map(function (t) { return doc.getElementById(t.getAttribute('aria-controls')); });
    var select = function (index, focus) {
      tabs.forEach(function (t, i) {
        var on = i === index;
        t.setAttribute('aria-selected', String(on));
        t.tabIndex = on ? 0 : -1;
        if (panels[i]) panels[i].hidden = !on;
      });
      if (focus) tabs[index].focus();
    };
    tabs.forEach(function (t, i) {
      t.addEventListener('click', function () { select(i); });
      t.addEventListener('keydown', function (e) {
        var n = tabs.length, next = null;
        if (e.key === 'ArrowRight' || e.key === 'ArrowDown') next = (i + 1) % n;
        else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') next = (i - 1 + n) % n;
        else if (e.key === 'Home') next = 0;
        else if (e.key === 'End') next = n - 1;
        if (next !== null) { e.preventDefault(); select(next, true); }
      });
    });
    select(0);
  });

  /* ------------------------------------------------------------ Play Now / Download Launcher
   * Neither the Godot Web export nor a launcher release is connected yet, so these buttons are
   * placeholders. They are switched on from <html> (index.html), nothing else needs editing:
   *   PHASE 2:  data-play-url="play/"            -> every .js-play becomes a link to the web build
   *   LAUNCHER: data-launcher-url="https://..."  -> the .js-launcher button becomes the download link */
  function wirePlaceholder(selector, url, liveText) {
    $$(selector).forEach(function (btn) {
      var sub = $('.btn-sub', btn);
      if (url) {
        btn.setAttribute('href', url);
        btn.removeAttribute('role');
        btn.removeAttribute('aria-disabled');
        btn.removeAttribute('tabindex');
        btn.classList.remove('is-disabled');
        if (sub) sub.textContent = liveText;
        return;
      }
      function nudge(e) {
        if (e.type === 'keydown' && e.key !== 'Enter' && e.key !== ' ') return;
        e.preventDefault();
        btn.classList.remove('nudge');
        void btn.offsetWidth; // restart the animation
        btn.classList.add('nudge');
      }
      btn.addEventListener('click', nudge);
      btn.addEventListener('keydown', nudge);
    });
  }
  var playUrl = (root.getAttribute('data-play-url') || '').trim();
  var launcherUrl = (root.getAttribute('data-launcher-url') || '').trim();
  if (playUrl) $$('.play-note').forEach(function (n) { n.hidden = true; });
  wirePlaceholder('.js-play', playUrl, 'Play in your browser');
  wirePlaceholder('.js-launcher', launcherUrl, 'Windows installer');

  /* ------------------------------------------------------------ Embers
   * Slow red sparks drifting up, echoing the game's title screen. Capped, pauses when the hero is
   * off screen or the tab is hidden, and draws a single still frame if reduced motion is requested. */
  var canvas = $('#embers');
  var ctx = canvas && canvas.getContext && canvas.getContext('2d');
  if (ctx) {
    var w = 0, h = 0, parts = [], raf = 0, last = 0, visible = true;

    var spawn = function (anywhere) {
      return {
        x: Math.random() * w,
        y: anywhere ? Math.random() * h : h + 12,
        r: 0.7 + Math.random() * 2.1,
        vy: 9 + Math.random() * 26,
        ph: Math.random() * 6.283,
        sp: 0.3 + Math.random() * 0.8,
        amp: 6 + Math.random() * 16,
        a: 0.18 + Math.random() * 0.42
      };
    };

    var resize = function () {
      var rect = canvas.getBoundingClientRect();
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      w = rect.width; h = rect.height;
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      var count = Math.round(Math.min(70, Math.max(22, (w * h) / 24000)));
      while (parts.length < count) parts.push(spawn(true));
      parts.length = count;
    };

    var draw = function () {
      ctx.clearRect(0, 0, w, h);
      for (var i = 0; i < parts.length; i++) {
        var p = parts[i];
        var fade = Math.min(1, Math.max(0, p.y / (h * 0.35))); // fade out toward the top
        var x = p.x + Math.sin(p.ph) * p.amp;
        ctx.fillStyle = 'rgba(217,30,26,' + (p.a * 0.28 * fade).toFixed(3) + ')';
        ctx.beginPath(); ctx.arc(x, p.y, p.r * 3.2, 0, 6.283); ctx.fill();
        ctx.fillStyle = 'rgba(255,110,90,' + (p.a * fade).toFixed(3) + ')';
        ctx.beginPath(); ctx.arc(x, p.y, p.r, 0, 6.283); ctx.fill();
      }
    };

    var tick = function (now) {
      raf = 0;
      if (!visible || doc.hidden) return;
      var dt = Math.min(0.05, (now - last) / 1000 || 0.016);
      last = now;
      for (var i = 0; i < parts.length; i++) {
        var p = parts[i];
        p.y -= p.vy * dt;
        p.ph += p.sp * dt;
        if (p.y < -12) parts[i] = spawn(false);
      }
      draw();
      raf = requestAnimationFrame(tick);
    };

    var start = function () {
      if (reduceMotion || raf || !visible || doc.hidden) return;
      last = performance.now();
      raf = requestAnimationFrame(tick);
    };

    resize();
    draw();
    var resizeTimer = 0;
    window.addEventListener('resize', function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () { resize(); draw(); }, 150);
    });
    doc.addEventListener('visibilitychange', function () { if (!doc.hidden) start(); });
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        visible = entries[0].isIntersecting;
        if (visible) start();
      }).observe(canvas);
    }
    start();
  }
})();
