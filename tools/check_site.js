// Static checker for website/: internal links, assets, anchors, JS element ids, root-absolute paths (which break
// under a GitHub Pages project URL). Usage: node tools/check_site.js website
const fs = require('fs');
const path = require('path');

const root = process.argv[2];
const htmlPath = path.join(root, 'index.html');
const html = fs.readFileSync(htmlPath, 'utf8');
const css = fs.readFileSync(path.join(root, 'assets/css/style.css'), 'utf8').replace(/url\("data:[^"]*"\)/g, 'url(data:stripped)');
const js = fs.readFileSync(path.join(root, 'assets/js/main.js'), 'utf8');

const problems = [];
const notes = [];
const externals = new Set();

// ---- ids defined in the HTML
const ids = new Set([...html.matchAll(/\sid="([^"]+)"/g)].map(m => m[1]));

// ---- every href/src in HTML
const refs = [...html.matchAll(/\s(href|src)="([^"]*)"/g)].map(m => ({ attr: m[1], val: m[2] }));
let internalFiles = 0, anchors = 0;
for (const { attr, val } of refs) {
  if (/^https?:\/\//i.test(val)) { externals.add(val); continue; }
  if (val.startsWith('#')) {
    anchors++;
    const id = val.slice(1);
    if (id && !ids.has(id)) problems.push(`anchor ${val} has no matching id`);
    continue;
  }
  if (val.startsWith('/') || /^[a-z]+:/i.test(val)) {
    problems.push(`root-absolute or scheme path (breaks under a project URL): ${attr}="${val}"`);
    continue;
  }
  internalFiles++;
  const file = path.join(root, val.split('#')[0].split('?')[0]);
  if (!fs.existsSync(file)) problems.push(`missing file: ${val}`);
}

// ---- url() in CSS (data: URIs are fine)
for (const m of css.matchAll(/url\(\s*["']?([^"')]+)["']?\s*\)/g)) {
  const v = m[1];
  if (v.startsWith('data:')) continue;
  if (v.startsWith('/') || /^https?:/i.test(v)) problems.push(`CSS url() not relative: ${v}`);
  else if (!fs.existsSync(path.join(root, 'assets/css', v))) problems.push(`CSS url() missing: ${v}`);
}

// ---- external requests the page would make on load (should be none)
for (const m of html.matchAll(/<(?:link|script|img|iframe)[^>]+(?:href|src)="(https?:\/\/[^"]+)"/g)) {
  if (!/rel="noopener"/.test(m[0])) problems.push(`external resource loaded on page load: ${m[1]}`);
}

// ---- JS lookups that must exist
for (const m of js.matchAll(/\$\('#([\w-]+)'\)|getElementById\('([\w-]+)'\)/g)) {
  const id = m[1] || m[2];
  if (!ids.has(id)) problems.push(`main.js looks up #${id} which is not in index.html`);
}
for (const m of js.matchAll(/\$\$?\('([.][\w-]+(?:\s[.\w-]+)*)'\)/g)) {
  const cls = m[1].split(/\s/)[0].slice(1);
  if (!new RegExp(`class="[^"]*\\b${cls}\\b`).test(html)) notes.push(`main.js selects .${cls} - not found in HTML (ok only if optional)`);
}

// ---- sprite <use> targets
for (const m of html.matchAll(/<use href="#([^"]+)"/g)) {
  if (!new RegExp(`<symbol id="${m[1]}"`).test(html)) problems.push(`<use> target missing: #${m[1]}`);
}

// ---- tab/panel wiring
for (const m of html.matchAll(/aria-controls="([^"]+)"/g)) {
  if (!ids.has(m[1])) problems.push(`aria-controls target missing: ${m[1]}`);
}
for (const m of html.matchAll(/aria-labelledby="([^"]+)"/g)) {
  if (!ids.has(m[1])) problems.push(`aria-labelledby target missing: ${m[1]}`);
}
for (const m of html.matchAll(/aria-describedby="([^"]+)"/g)) {
  if (!ids.has(m[1])) problems.push(`aria-describedby target missing: ${m[1]}`);
}

// ---- duplicate ids
const all = [...html.matchAll(/\sid="([^"]+)"/g)].map(m => m[1]);
const dupes = all.filter((x, i) => all.indexOf(x) !== i);
if (dupes.length) problems.push('duplicate ids: ' + [...new Set(dupes)].join(', '));

console.log(`HTML refs checked: ${refs.length} (${internalFiles} internal files, ${anchors} anchors, ${externals.size} unique external)`);
console.log('External URLs:\n  ' + [...externals].join('\n  '));
if (notes.length) console.log('Notes:\n  ' + notes.join('\n  '));
if (problems.length) { console.log('\nPROBLEMS:\n  ' + problems.join('\n  ')); process.exit(1); }
else console.log('\nOK: no problems found.');
