/* Vampire Game - player feedback hub.
 * Submits bug reports / ideas to Supabase and lists the public ones. Plain fetch, no SDK.
 * Uses ONLY the public key from config.js; what that key may do is enforced by the database
 * (supabase/feedback_schema.sql), not by this file. If feedback isn't configured or the service
 * is unreachable the page degrades to a friendly message and nothing else is affected.
 */
(function () {
  'use strict';

  var doc = document;
  var cfg = window.VG_CONFIG || {};
  var base = String(cfg.supabaseUrl || '').trim().replace(/\/+$/, '');
  var key = String(cfg.supabaseAnonKey || '').trim();
  var bucket = cfg.attachmentsBucket || 'feedback-attachments';

  // https://<project>.supabase.co in production; plain http only for localhost development.
  var configured = !!key && /^(https:\/\/[^\/\s]+|http:\/\/(localhost|127\.0\.0\.1)(:\d+)?)$/i.test(base);

  var PAGE_SIZE = 10;
  var MAX_FILE = 10 * 1024 * 1024;
  var FILE_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'video/mp4', 'video/webm'];
  var COOLDOWN_MS = 45000;
  var COLUMNS = 'id,type,title,description,context,reproduction_steps,expected_behavior,idea_benefit,' +
                'submitter_name,anonymous,status,created_at';
  var STATUS_LABEL = { 'new': 'New', investigating: 'Investigating', planned: 'Planned',
                       in_progress: 'In Progress', fixed: 'Fixed', closed: 'Closed' };

  function $(sel, ctx) { return (ctx || doc).querySelector(sel); }
  function $$(sel, ctx) { return Array.prototype.slice.call((ctx || doc).querySelectorAll(sel)); }

  var list = $('#report-list');
  var moreBtn = $('#more-reports');
  var filter = $('#status-filter');
  var unavailable = $('#fb-unavailable');
  if (!list) return;   // page without a feedback hub

  /* ---------------------------------------------------------------- Supabase access */

  function headers(extra) {
    var h = { apikey: key };
    if (/^eyJ/.test(key)) h.Authorization = 'Bearer ' + key;   // legacy JWT anon key; new publishable keys use apikey only
    for (var k in extra) if (Object.prototype.hasOwnProperty.call(extra, k)) h[k] = extra[k];
    return h;
  }

  // Every request gives up after a while, so a stalled server can never leave the page spinning forever.
  function request(path, init, timeoutMs) {
    init = init || {};
    init.headers = headers(init.headers || {});
    var ctrl = typeof AbortController === 'function' ? new AbortController() : null;
    var timer = ctrl ? setTimeout(function () { ctrl.abort(); }, timeoutMs || 15000) : 0;
    if (ctrl) init.signal = ctrl.signal;
    return fetch(base + path, init).then(function (res) {
      clearTimeout(timer);
      if (!res.ok) { var err = new Error('HTTP ' + res.status); err.status = res.status; throw err; }
      return res;
    }, function (e) { clearTimeout(timer); throw e; });
  }

  /* ---------------------------------------------------------------- Unavailable state */

  function showUnavailable() {
    if (unavailable) unavailable.hidden = false;
    $$('.fb-form').forEach(function (f) {
      $$('input, textarea, button, select', f).forEach(function (el) { el.disabled = true; });
      var msg = $('.form-msg', f);
      if (msg) { msg.textContent = 'Feedback is temporarily unavailable.'; msg.className = 'form-msg is-warn'; }
    });
    if (filter) filter.disabled = true;
    list.textContent = '';
    note('Community reports will appear here once feedback is switched on.');
  }

  function note(text, retry) {
    var p = doc.createElement('p');
    p.className = 'list-note';
    p.textContent = text;
    if (retry) {
      var b = doc.createElement('button');
      b.type = 'button'; b.className = 'link-btn'; b.textContent = 'Try again';
      b.addEventListener('click', retry);
      p.appendChild(doc.createTextNode(' ')); p.appendChild(b);
    }
    list.appendChild(p);
  }

  if (!configured) { showUnavailable(); return; }

  /* ---------------------------------------------------------------- Community list */

  var state = { type: 'bug', status: '', offset: 0, loading: false, seq: 0 };

  function el(tag, cls, text) {
    var e = doc.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  function displayName(r) {
    var n = (r.submitter_name || '').trim();
    return (r.anonymous || !n) ? 'Anonymous Player' : n;
  }

  function fmtDate(iso) {
    var d = new Date(iso);
    return isNaN(d) ? '' : d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
  }

  function detail(parent, label, text) {
    if (!text || !String(text).trim()) return;
    var row = el('div', 'rdetail');
    row.appendChild(el('h5', null, label));
    row.appendChild(el('p', null, text));      // textContent only: user text is never parsed as HTML
    parent.appendChild(row);
  }

  function card(r) {
    var isBug = r.type === 'bug';
    var a = el('article', 'report');
    var head = el('header', 'report-head');
    head.appendChild(el('span', 'rtype ' + (isBug ? 'rtype-bug' : 'rtype-idea'), isBug ? 'Bug report' : 'Game idea'));
    var st = STATUS_LABEL[r.status] ? r.status : 'new';
    head.appendChild(el('span', 'status status-' + st, 'Status: ' + STATUS_LABEL[st]));
    a.appendChild(head);
    a.appendChild(el('h4', 'report-title', r.title));
    a.appendChild(el('p', 'report-desc', r.description));

    var extras = el('div', 'report-more');
    if (isBug) {
      detail(extras, 'What they were doing', r.context);
      detail(extras, 'Steps to reproduce', r.reproduction_steps);
      detail(extras, 'Expected behavior', r.expected_behavior);
    } else {
      detail(extras, 'Why it would improve the game', r.idea_benefit);
    }
    if (extras.children.length) {
      var d = el('details', 'report-details');
      d.appendChild(el('summary', null, 'More details'));
      d.appendChild(extras);
      a.appendChild(d);
    }
    var foot = el('footer', 'report-foot');
    foot.appendChild(el('span', null, 'Submitted by ' + displayName(r)));
    var when = fmtDate(r.created_at);
    if (when) foot.appendChild(el('span', 'report-date', when));
    a.appendChild(foot);
    return a;
  }

  function load(reset) {
    if (state.loading) return;
    if (reset) { state.offset = 0; list.textContent = ''; moreBtn.hidden = true; }
    state.loading = true;
    list.setAttribute('aria-busy', 'true');
    var mySeq = ++state.seq;
    var loading = null;
    if (reset) { loading = el('p', 'list-note', 'Loading reports…'); list.appendChild(loading); }

    var q = '/rest/v1/feedback?select=' + COLUMNS + '&type=eq.' + state.type +
            (state.status ? '&status=eq.' + encodeURIComponent(state.status) : '') +
            '&order=created_at.desc&limit=' + (PAGE_SIZE + 1) + '&offset=' + state.offset;
    request(q).then(function (res) { return res.json(); }).then(function (rows) {
      if (mySeq !== state.seq) return;       // a newer request replaced this one
      if (loading) loading.remove();
      if (!Array.isArray(rows)) throw new Error('bad payload');
      var more = rows.length > PAGE_SIZE;
      rows.slice(0, PAGE_SIZE).forEach(function (r) { list.appendChild(card(r)); });
      state.offset += Math.min(rows.length, PAGE_SIZE);
      moreBtn.hidden = !more;
      if (!list.children.length) {
        note(state.status ? 'No reports with that status yet.'
          : (state.type === 'bug' ? 'No bug reports yet. Found one? Report it above.' : 'No ideas yet. Got one? Share it above.'));
      }
    }).catch(function () {
      if (mySeq !== state.seq) return;
      if (loading) loading.remove();
      note('Reports couldn’t be loaded right now.', function () { list.textContent = ''; load(true); });
    }).then(function () {
      if (mySeq === state.seq) { state.loading = false; list.setAttribute('aria-busy', 'false'); }
    });
  }

  $$('.community-bar .tab').forEach(function (btn) {
    btn.addEventListener('click', function () {
      $$('.community-bar .tab').forEach(function (b) { b.setAttribute('aria-pressed', String(b === btn)); });
      state.type = btn.getAttribute('data-type');
      state.loading = false;
      load(true);
    });
  });
  if (filter) filter.addEventListener('change', function () { state.status = filter.value; state.loading = false; load(true); });
  moreBtn.addEventListener('click', function () { load(false); });

  /* ---------------------------------------------------------------- Submitting */

  function setMsg(form, text, kind) {
    var m = $('.form-msg', form);
    m.textContent = text;
    m.className = 'form-msg' + (kind ? ' is-' + kind : '');
  }

  function recentlySubmitted() {
    try { return Date.now() - Number(localStorage.getItem('vg_fb_last') || 0) < COOLDOWN_MS; } catch (e) { return false; }
  }
  function markSubmitted() { try { localStorage.setItem('vg_fb_last', String(Date.now())); } catch (e) { /* ignore */ } }

  function uuid() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    var b = crypto.getRandomValues(new Uint8Array(16)), h = [];
    b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
    for (var i = 0; i < 16; i++) h.push((b[i] + 0x100).toString(16).slice(1));
    return h.slice(0, 4).join('') + '-' + h.slice(4, 6).join('') + '-' + h.slice(6, 8).join('') + '-' +
           h.slice(8, 10).join('') + '-' + h.slice(10).join('');
  }

  function upload(file) {
    var safe = file.name.replace(/[^A-Za-z0-9._-]/g, '_').slice(-100) || 'attachment';
    var path = uuid() + '/' + safe;
    return request('/storage/v1/object/' + encodeURIComponent(bucket) + '/' + path, {
      method: 'POST', body: file, headers: { 'Content-Type': file.type, 'x-upsert': 'false' }
    }, 90000).then(function () { return path; });
  }

  function clean(v, max) { v = (v == null ? '' : String(v)).trim(); return v ? v.slice(0, max) : null; }

  function submit(form) {
    var kind = form.getAttribute('data-kind');
    var fd = new FormData(form);
    if (fd.get('company')) { setMsg(form, 'Thanks! Your report was received.', 'ok'); form.reset(); return; }   // honeypot: quietly ignore bots

    var title = clean(fd.get('title'), 120), desc = clean(fd.get('description'), 4000);
    if (!title || title.length < 3) { setMsg(form, 'Please give it a short title (at least 3 characters).', 'err'); return; }
    if (!desc || desc.length < 10) { setMsg(form, 'Please describe it in a little more detail (at least 10 characters).', 'err'); return; }
    if (recentlySubmitted()) { setMsg(form, 'Thanks! Please wait a moment before sending another.', 'warn'); return; }

    var name = clean(fd.get('submitter_name'), 40);
    var anon = fd.get('anonymous') === 'on' || !name;
    var row = { type: kind, title: title, description: desc, anonymous: anon, submitter_name: anon ? null : name };
    if (kind === 'bug') {
      row.context = clean(fd.get('context'), 2000);
      row.reproduction_steps = clean(fd.get('reproduction_steps'), 3000);
      row.expected_behavior = clean(fd.get('expected_behavior'), 2000);
    } else {
      row.idea_benefit = clean(fd.get('idea_benefit'), 2000);
    }

    var file = kind === 'bug' ? fd.get('attachment') : null;
    if (file && file.size) {
      if (FILE_TYPES.indexOf(file.type) === -1) { setMsg(form, 'That file type isn’t supported. Use PNG, JPG, GIF, WebP, MP4 or WebM.', 'err'); return; }
      if (file.size > MAX_FILE) { setMsg(form, 'That file is over 10 MB. Please use a smaller one.', 'err'); return; }
    } else { file = null; }

    var btn = $('button[type=submit]', form);
    btn.disabled = true;
    setMsg(form, file ? 'Uploading your file…' : 'Sending…');

    (file ? upload(file).then(function (p) { row.attachment_path = p; }) : Promise.resolve())
      .then(function () {
        setMsg(form, 'Sending…');
        return request('/rest/v1/feedback', {
          method: 'POST', body: JSON.stringify(row),
          headers: { 'Content-Type': 'application/json', Prefer: 'return=minimal' }
        });
      })
      .then(function () {
        markSubmitted();
        form.reset();
        setMsg(form, kind === 'bug' ? 'Thanks! Your bug report was received.' : 'Thanks! Your idea was received.', 'ok');
        if (state.type === kind) { state.loading = false; load(true); }
      })
      .catch(function (e) {
        var s = e && e.status;
        var msg = (s === 400 || s === 413 || s === 415 || s === 422)
          ? 'The server didn’t accept that (check the lengths and file). Nothing was sent.'
          : (s === 401 || s === 403) ? 'Feedback is temporarily unavailable. Nothing was sent.'
          : 'Couldn’t reach the feedback service. Check your connection and try again.';
        setMsg(form, msg, 'err');
      })
      .then(function () { btn.disabled = false; });
  }

  $$('.fb-form').forEach(function (form) {
    form.addEventListener('submit', function (e) { e.preventDefault(); submit(form); });
    // choosing "anonymous" clears and disables the name field
    var anon = $('input[name=anonymous]', form), name = $('input[name=submitter_name]', form);
    if (anon && name) {
      anon.addEventListener('change', function () {
        name.disabled = anon.checked;
        if (anon.checked) name.value = '';
      });
      form.addEventListener('reset', function () { name.disabled = false; });
    }
  });

  load(true);
})();
