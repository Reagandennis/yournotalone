// The admin page: one HTML document, no build step. It signs in with the
// app's own Supabase accounts, reads and writes through /admin/api, and
// parses YAML in the browser (the Worker's CPU budget is small). The
// placeholders are filled per request by routes.ts.

export const ADMIN_PAGE = /* html */ `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>yournotalone · content</title>
<link rel="icon" href="data:,">
<style nonce="__NONCE__">
  :root { --ink:#1A2238; --muted:#5d6577; --line:#e3e6ee; --bg:#f7f8fb; --blue:#3764CD; --red:#D2453A; --yellow:#F2B33D; --ok:#1f8a4c; }
  * { box-sizing: border-box; }
  body { margin:0; font:15px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif; color:var(--ink); background:var(--bg); }
  header { display:flex; align-items:center; gap:16px; padding:14px 24px; background:#fff; border-bottom:1px solid var(--line); position:sticky; top:0; z-index:5; }
  header h1 { font-size:17px; margin:0; flex:1; }
  main { max-width:1100px; margin:0 auto; padding:24px; }
  button, .btn { font:inherit; border:1px solid var(--line); background:#fff; color:var(--ink); padding:8px 14px; border-radius:10px; cursor:pointer; }
  button.primary { background:var(--blue); border-color:var(--blue); color:#fff; }
  button.danger { color:var(--red); }
  button:disabled { opacity:.5; cursor:default; }
  input, select, textarea { font:inherit; width:100%; padding:8px 10px; border:1px solid var(--line); border-radius:8px; background:#fff; color:var(--ink); }
  textarea { min-height:90px; resize:vertical; }
  label { display:block; font-weight:600; font-size:13px; margin:14px 0 4px; }
  .hint { font-weight:400; color:var(--muted); font-size:12.5px; }
  .card { background:#fff; border:1px solid var(--line); border-radius:14px; padding:18px 20px; margin-bottom:16px; }
  .row { display:flex; gap:12px; flex-wrap:wrap; align-items:center; }
  .row > * { flex:1; min-width:140px; }
  .checks { display:flex; flex-wrap:wrap; gap:6px 14px; }
  .checks label { display:flex; gap:6px; align-items:center; font-weight:400; margin:0; font-size:14px; }
  .checks input { width:auto; }
  table { width:100%; border-collapse:collapse; }
  td, th { text-align:left; padding:9px 8px; border-bottom:1px solid var(--line); vertical-align:top; font-size:14px; }
  th { font-size:12px; color:var(--muted); text-transform:uppercase; letter-spacing:.04em; }
  tr.item:hover { background:#f2f5fc; cursor:pointer; }
  .tag { display:inline-block; font-size:11.5px; padding:1px 7px; border-radius:20px; background:#eef1f8; color:var(--muted); margin:0 4px 2px 0; }
  .tag.premium { background:#fff4dc; color:#8a6100; }
  .tag.draft { background:#e8f0ff; color:var(--blue); }
  .tag.retired { background:#fdeceb; color:var(--red); }
  .muted { color:var(--muted); }
  .error { color:var(--red); white-space:pre-wrap; }
  .ok { color:var(--ok); }
  .bar { height:8px; background:#eef1f8; border-radius:8px; overflow:hidden; margin-top:6px; }
  .bar > div { height:100%; width:0; background:var(--blue); transition:width .2s; }
  .hidden { display:none !important; }
  .grid2 { display:grid; grid-template-columns:1fr 1fr; gap:0 16px; }
  @media (max-width:720px) { .grid2 { grid-template-columns:1fr; } main { padding:14px; } }
  .locale { border-top:1px solid var(--line); margin-top:14px; padding-top:6px; }
  .runs li { margin:4px 0; }
</style>
</head>
<body>
<header>
  <h1>yournotalone · content</h1>
  <span id="who" class="muted"></span>
  <button id="signout" class="hidden">Sign out</button>
</header>
<main>
  <form id="signin" class="card hidden" style="max-width:420px;margin:40px auto">
    <h2 style="margin-top:0">Sign in</h2>
    <p class="muted">Use your yournotalone account. Only accounts marked as content admins get in.</p>
    <button type="button" id="google" style="width:100%">Continue with Google</button>
    <p class="muted" style="text-align:center">or</p>
    <label for="email">Email</label><input id="email" type="email" autocomplete="username">
    <label for="password">Password</label><input id="password" type="password" autocomplete="current-password">
    <p><button type="submit" class="primary" style="width:100%">Sign in</button></p>
    <p id="signin-error" class="error"></p>
  </form>

  <section id="app" class="hidden">
    <div class="card">
      <div class="row" style="align-items:flex-start">
        <div style="flex:2">
          <strong>Live now</strong>
          <div id="live" class="muted">…</div>
          <ul id="runs" class="runs muted" style="padding-left:18px;margin:8px 0 0"></ul>
        </div>
        <div style="flex:1;text-align:right">
          <button id="publish-prod" class="primary">Publish to production</button>
          <p class="hint" style="margin:6px 0 0">Every save publishes to staging by itself. Check it there first.</p>
        </div>
      </div>
    </div>

    <div class="card" id="list-card">
      <div class="row" style="margin-bottom:10px">
        <input id="search" placeholder="Search titles" style="flex:2">
        <select id="kind-filter"><option value="">All kinds</option></select>
        <select id="status-filter"><option value="">Any status</option><option>published</option><option>draft</option><option>retired</option></select>
        <select id="new-kind"><option value="">+ Add new…</option></select>
      </div>
      <table><thead><tr><th>Title</th><th>Kind</th><th>For</th><th>Translations</th></tr></thead><tbody id="rows"></tbody></table>
      <p id="list-error" class="error"></p>
    </div>

    <form id="editor" class="card hidden" autocomplete="off">
      <div class="row"><h2 id="editor-title" style="margin:0;flex:3"></h2><button type="button" id="close">Close</button></div>
      <p id="editor-id" class="muted" style="margin:4px 0 0"></p>

      <div class="grid2">
        <div><label for="f-title">Title</label><input id="f-title" required maxlength="60"></div>
        <div><label for="f-status">Status <span class="hint">drafts aren't published</span></label>
          <select id="f-status"><option value="published">Published</option><option value="draft">Draft</option><option value="retired">Retired</option></select></div>
      </div>
      <label for="f-blurb">Description <span class="hint">one line under the title</span></label><input id="f-blurb" required maxlength="140">

      <div class="grid2">
        <div><label>Who gets it</label><div class="checks"><label><input type="checkbox" id="f-premium"> Premium only</label></div></div>
        <div class="grid2" style="gap:0 10px">
          <div><label for="f-icon">Icon</label><select id="f-icon"></select></div>
          <div><label for="f-accent">Colour</label><select id="f-accent"></select></div>
        </div>
      </div>

      <label>What it helps with <span class="hint">at least one; used for search, Explore and recommendations</span></label>
      <div id="f-needs" class="checks"></div>
      <label>Best time of day <span class="hint">leave empty for any time; tagged items only show then</span></label>
      <div id="f-dayparts" class="checks"></div>
      <div class="grid2">
        <div><label for="f-intensity">How heavy it is</label>
          <select id="f-intensity"><option value="gentle">Gentle</option><option value="">Moderate / not sure</option><option value="deep">Deep: digs into what's hard</option></select></div>
        <div><label>After a bad check-in</label>
          <div class="checks"><label><input type="checkbox" id="f-calming"> Safe to suggest right after someone checks in feeling awful or low</label></div>
          <p class="hint" style="margin:4px 0 0">Only soft sounds, grounding and breathing without long holds. Never on a deep item.</p></div>
      </div>

      <div id="kind-fields"></div>

      <details id="translations" class="locale">
        <summary><strong>Translations</strong> <span id="tr-summary" class="hint"></span></summary>
        <p class="hint">Missing languages are drafted automatically after you save. Tick "checked" once a fluent reader has read it; only checked translations show in release builds.</p>
        <div id="tr-fields"></div>
      </details>

      <p style="margin-top:22px" class="row">
        <button type="submit" class="primary" id="save" style="flex:0 0 auto">Save and publish to staging</button>
        <span id="save-status" class="muted" style="flex:3"></span>
      </p>
      <p id="save-error" class="error"></p>
    </form>
  </section>
</main>

<script type="module" nonce="__NONCE__">
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.86.0';
import YAML from 'https://esm.sh/yaml@2.9.1';

const supabase = createClient('__SUPABASE_URL__', '__SUPABASE_KEY__');
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
const LOCALES = { fr: 'French', de: 'German', es: 'Spanish', 'zh-Hans': 'Chinese' };
const KIND_LABEL = { sound: 'Sound', meditation: 'Meditation', breathing: 'Breathing', prompt: 'Journal prompt', lesson: 'Lesson', tool: 'Tool', recovery: 'Recovery' };
const NEED_LABEL = { sleep: 'Sleep', anxious: 'Anxiety', panic: 'Panic', low: 'Low mood', stressed: 'Stress', angry: 'Anger', urges: 'Urges', focus: 'Focus', reflect: 'Reflection', good: 'Good days' };
const CREATABLE = ['sound', 'meditation', 'breathing', 'prompt', 'lesson'];
const LESSON_ART = ['thoughts','traps','activity','worry','grounding','problem','learn','resources','moon','diary','tomorrowList','awake','habits','windDown','gauge','circles','sigh','muscles','battery','pause'];
const WAVES = { sleep: [7, 3, 0.35], focus: [6, 3, 0.45], calm: [4, 2, 0.5] };

let session = null;
let state = { items: [], vocab: null, icons: [] };
let editing = null; // { path, item } or { path: null, item } for new
let upload = null;  // { role, file, name }

async function api(path, init = {}) {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  const res = await fetch(path, { ...init, headers: { ...(init.headers || {}), Authorization: 'Bearer ' + token, ...(init.body && !(init.body instanceof Blob) ? { 'Content-Type': 'application/json' } : {}) } });
  const body = res.headers.get('content-type')?.includes('json') ? await res.json() : await res.text();
  if (!res.ok) throw new Error(body?.message || body?.error || ('HTTP ' + res.status));
  return body;
}

// ------------------------------------------------------------- sign in
async function showFor(s) {
  session = s;
  $('signin').classList.toggle('hidden', !!s);
  $('app').classList.toggle('hidden', !s);
  $('signout').classList.toggle('hidden', !s);
  $('who').textContent = s ? s.user.email : '';
  if (s) await load();
}
$('google').onclick = () => supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin + '/admin' } });
$('signin').onsubmit = async (e) => {
  e.preventDefault();
  $('signin-error').textContent = '';
  const { error } = await supabase.auth.signInWithPassword({ email: $('email').value.trim(), password: $('password').value });
  if (error) $('signin-error').textContent = error.message;
};
$('signout').onclick = () => supabase.auth.signOut();
supabase.auth.onAuthStateChange((event, s) => { if (event !== 'TOKEN_REFRESHED') showFor(s); });

// ---------------------------------------------------------------- list
async function load() {
  $('list-error').textContent = '';
  try {
    const data = await api('/admin/api/items');
    state.vocab = YAML.parse(data.vocab);
    state.icons = [...data.icons.matchAll(/'([a-z_]+)': Icons/g)].map((m) => m[1]);
    state.items = data.files.filter((f) => f.path.endsWith('.yaml')).map((f) => {
      try { return { path: f.path, item: YAML.parse(f.text) }; } catch { return null; }
    }).filter(Boolean);
    fillFilters();
    render();
    status();
  } catch (e) {
    $('list-error').textContent = e.message === 'not_admin'
      ? 'This account isn\\'t a content admin. Set content_admin in its app_metadata (see edge/README.md), then sign out and in again.'
      : 'Couldn\\'t load the content: ' + e.message;
  }
}

function fillFilters() {
  const kinds = state.vocab.kinds;
  $('kind-filter').innerHTML = '<option value="">All kinds</option>' + kinds.map((k) => '<option value="' + k + '">' + KIND_LABEL[k] + '</option>').join('');
  $('new-kind').innerHTML = '<option value="">+ Add new…</option>' + CREATABLE.map((k) => '<option value="' + k + '">' + KIND_LABEL[k] + '</option>').join('');
}

function render() {
  const q = $('search').value.trim().toLowerCase();
  const kind = $('kind-filter').value, st = $('status-filter').value;
  const rows = state.items
    .filter(({ item }) => (!kind || item.kind === kind) && (!st || item.status === st))
    .filter(({ item }) => !q || (item.text?.en?.title || '').toLowerCase().includes(q) || item.id.toLowerCase().includes(q))
    .sort((a, b) => (a.item.kind < b.item.kind ? -1 : a.item.kind > b.item.kind ? 1 : (a.item.order || 0) - (b.item.order || 0)));
  $('rows').innerHTML = rows.map(({ item, path }) => {
    const t = item.text || {};
    const missing = Object.keys(LOCALES).filter((l) => !t[l]).length;
    const toCheck = Object.keys(LOCALES).filter((l) => t[l] && t[l].reviewed !== true).length;
    return '<tr class="item" data-path="' + esc(path) + '"><td><strong>' + esc(t.en?.title || item.id) + '</strong> '
      + (item.premium ? '<span class="tag premium">Premium</span>' : '')
      + (item.status !== 'published' ? '<span class="tag ' + esc(item.status) + '">' + esc(item.status) + '</span>' : '')
      + '<br><span class="muted">' + esc(t.en?.blurb) + '</span></td>'
      + '<td>' + esc(KIND_LABEL[item.kind] || item.kind) + '</td>'
      + '<td>' + (item.tags?.needs || []).map((n) => '<span class="tag">' + esc(NEED_LABEL[n] || n) + '</span>').join('')
      + (item.tags?.dayParts || []).map((d) => '<span class="tag">' + esc(d) + '</span>').join('') + '</td>'
      + '<td class="muted">' + (missing ? missing + ' missing' : toCheck ? toCheck + ' to check' : '<span class="ok">all checked</span>') + '</td></tr>';
  }).join('') || '<tr><td colspan="4" class="muted">Nothing matches.</td></tr>';
}
$('search').oninput = render;
$('kind-filter').onchange = render;
$('status-filter').onchange = render;
$('rows').onclick = (e) => {
  const tr = e.target.closest('tr.item');
  if (!tr) return;
  const found = state.items.find((x) => x.path === tr.dataset.path);
  if (found) open(found.path, structuredClone(found.item));
};
$('new-kind').onchange = () => {
  const kind = $('new-kind').value;
  $('new-kind').value = '';
  if (kind) open(null, blank(kind));
};

// -------------------------------------------------------------- editor
function blank(kind) {
  const body = {
    sound: { type: 'sound', category: 'sleep', audio: '', loop: true, waveFreq: 7, waveSpeed: 3, waveHeight: 0.35, pulse: false },
    meditation: { type: 'meditation', promptAt: [], narration: null },
    breathing: { type: 'breathing', inhale: 4, holdIn: 0, exhale: 6, holdOut: 0 },
    prompt: { type: 'prompt', group: 'Everyday' },
    lesson: { type: 'lesson', art: 'learn' },
  }[kind];
  return {
    kind, status: 'draft', premium: false,
    icon: { sound: 'graphic_eq_rounded', meditation: 'self_improvement_rounded', breathing: 'air_rounded', prompt: 'edit_note_rounded', lesson: 'menu_book_rounded' }[kind],
    accent: 'blue', tags: { needs: [], dayParts: [], intensity: 'gentle' },
    ...(kind === 'meditation' || kind === 'lesson' ? { minutes: 5 } : {}),
    text: { en: { title: '', blurb: '' } }, body,
  };
}

function checks(id, values, chosen, labels) {
  $(id).innerHTML = values.map((v) => '<label><input type="checkbox" value="' + v + '"' + (chosen.includes(v) ? ' checked' : '') + '> ' + esc(labels?.[v] || v) + '</label>').join('');
}
const checked = (id) => [...$(id).querySelectorAll('input:checked')].map((i) => i.value);
const options = (values, chosen, labels) => values.map((v) => '<option value="' + esc(v) + '"' + (v === chosen ? ' selected' : '') + '>' + esc(labels?.[v] || v) + '</option>').join('');
const lines = (s) => s.split('\\n').map((x) => x.trim()).filter(Boolean);

function open(path, item) {
  editing = { path, item };
  upload = null;
  const v = state.vocab, en = item.text?.en || {};
  $('editor').classList.remove('hidden');
  $('editor-title').textContent = path ? (en.title || item.id) : 'New ' + KIND_LABEL[item.kind].toLowerCase();
  $('editor-id').textContent = path ? item.id + ' · ' + path : 'The id is made from the title when you save, and never changes after that.';
  $('f-title').value = en.title || '';
  $('f-blurb').value = en.blurb || '';
  $('f-status').value = item.status || 'draft';
  $('f-premium').checked = !!item.premium;
  $('f-icon').innerHTML = options(state.icons, item.icon);
  $('f-accent').innerHTML = options(v.accents, item.accent);
  checks('f-needs', v.needs, item.tags?.needs || [], NEED_LABEL);
  checks('f-dayparts', v.dayParts, item.tags?.dayParts || []);
  $('f-intensity').value = item.tags?.intensity === 'moderate' ? '' : (item.tags?.intensity ?? '');
  $('f-calming').checked = !!item.tags?.calmingSafe;
  kindFields(item);
  translations(item);
  $('save-error').textContent = '';
  $('save-status').textContent = '';
  $('editor').scrollIntoView({ behavior: 'smooth' });
}
$('close').onclick = () => { $('editor').classList.add('hidden'); editing = null; };

function kindFields(item) {
  const b = item.body, en = item.text?.en || {}, v = state.vocab;
  const recording = (role, required) => '<label for="f-file">' + (role === 'audio' ? 'Recording' : 'Voice recording (optional)')
    + ' <span class="hint">WAV or FLAC is best; it\\'s levelled and converted for the app when published. Current: ' + esc(b[role] || 'none') + '</span></label>'
    + '<input type="file" id="f-file" accept=".wav,.flac,.aif,.aiff,.m4a,.mp3,.aac,audio/*"' + (required ? ' required' : '') + '>'
    + '<div class="bar"><div id="f-progress"></div></div><span id="f-upload" class="hint"></span>';
  let html = '';
  switch (b.type) {
    case 'sound':
      html = '<div class="grid2"><div><label for="f-category">Category</label><select id="f-category">' + options(v.soundCategories, b.category) + '</select></div><div></div></div>'
        + recording('audio', !b.audio);
      break;
    case 'meditation':
      html = '<div class="grid2"><div><label for="f-minutes">Minutes</label><input id="f-minutes" type="number" min="1" max="90" value="' + (item.minutes || 5) + '"></div><div></div></div>'
        + '<label for="f-prompts">Guidance lines <span class="hint">one per line, spread evenly through the session</span></label>'
        + '<textarea id="f-prompts" rows="6">' + esc((en.prompts || []).join('\\n')) + '</textarea>'
        + recording('narration', false);
      break;
    case 'breathing':
      html = '<label>Pattern, in seconds</label><div class="row">'
        + ['inhale', 'holdIn', 'exhale', 'holdOut'].map((k) => '<div><span class="hint">' + { inhale: 'Breathe in', holdIn: 'Hold', exhale: 'Breathe out', holdOut: 'Hold' }[k] + '</span><input id="f-' + k + '" type="number" min="' + (k.startsWith('hold') ? 0 : 1) + '" max="20" value="' + b[k] + '"></div>').join('')
        + '</div>';
      break;
    case 'prompt':
      html = '<div class="grid2"><div><label for="f-group">Group</label><select id="f-group">' + options(v.promptGroups, b.group) + '</select></div><div></div></div>'
        + '<label for="f-seed">Starter text <span class="hint">what the journal entry opens with</span></label><textarea id="f-seed">' + esc(en.seed || '') + '</textarea>';
      break;
    case 'lesson':
      html = '<div class="grid2"><div><label for="f-area">Toolkit</label><select id="f-area">' + options(['CBT', 'Sleep', 'Stress'], { cbt: 'CBT', sleep: 'Sleep', stress: 'Stress' }[item.accent] || 'CBT') + '</select></div>'
        + '<div class="grid2" style="gap:0 10px"><div><label for="f-minutes">Minutes</label><input id="f-minutes" type="number" min="1" max="30" value="' + (item.minutes || 3) + '"></div>'
        + '<div><label for="f-art">Picture</label><select id="f-art">' + options(LESSON_ART, b.art) + '</select></div></div></div>'
        + '<label for="f-paragraphs">Text <span class="hint">a blank line between paragraphs</span></label>'
        + '<textarea id="f-paragraphs" rows="10">' + esc((en.paragraphs || []).join('\\n\\n')) + '</textarea>';
      break;
    default:
      html = '<p class="hint">This kind is a screen built into the app: only its titles, tags and translations can change here.</p>';
  }
  $('kind-fields').innerHTML = html;
  const file = $('f-file');
  if (file) file.onchange = () => {
    const f = file.files[0];
    upload = f ? { role: b.type === 'sound' ? 'audio' : 'narration', file: f } : null;
    $('f-upload').textContent = f ? f.name + ' · ' + (f.size / 1e6).toFixed(1) + ' MB, uploads when you save' : '';
  };
}

const TR_FIELDS = ['title', 'blurb', 'area', 'seed', 'prompts', 'paragraphs'];
function translations(item) {
  const t = item.text || {};
  const done = Object.keys(LOCALES).filter((l) => t[l]?.reviewed === true).length;
  $('tr-summary').textContent = done + ' of 4 checked';
  $('tr-fields').innerHTML = Object.entries(LOCALES).map(([l, name]) => {
    const x = t[l];
    if (!x) return '<div class="locale"><strong>' + name + '</strong> <span class="hint">not translated yet; drafted after saving</span></div>';
    return '<div class="locale" data-locale="' + l + '"><div class="row"><strong>' + name + '</strong>'
      + '<div class="checks" style="justify-content:flex-end"><label><input type="checkbox" class="tr-reviewed"' + (x.reviewed ? ' checked' : '') + '> checked by a fluent reader</label></div></div>'
      + TR_FIELDS.filter((k) => x[k] !== undefined).map((k) => {
        const val = Array.isArray(x[k]) ? x[k].join(k === 'paragraphs' ? '\\n\\n' : '\\n') : x[k];
        const multi = Array.isArray(x[k]) || k === 'seed';
        return '<label>' + k + '</label>' + (multi ? '<textarea data-k="' + k + '">' + esc(val) + '</textarea>' : '<input data-k="' + k + '" value="' + esc(val) + '">');
      }).join('') + '</div>';
  }).join('');
}

// ---------------------------------------------------------------- save
function collect() {
  const item = structuredClone(editing.item);
  const en = item.text.en = { ...(item.text.en || {}) };
  en.title = $('f-title').value.trim();
  en.blurb = $('f-blurb').value.trim();
  item.status = $('f-status').value;
  item.premium = $('f-premium').checked;
  item.icon = $('f-icon').value;
  item.accent = $('f-accent').value;
  item.tags = { ...(item.tags || {}), needs: checked('f-needs'), dayParts: checked('f-dayparts') };
  const intensity = $('f-intensity').value;
  if (intensity) item.tags.intensity = intensity; else delete item.tags.intensity;
  if ($('f-calming').checked) item.tags.calmingSafe = true; else delete item.tags.calmingSafe;
  if (item.tags.calmingSafe && item.tags.intensity === 'deep') throw new Error('A deep item can\\'t be marked safe after a bad check-in.');
  const b = item.body;
  switch (b.type) {
    case 'sound': {
      b.category = $('f-category').value;
      if (!editing.path || !b.waveFreq) [b.waveFreq, b.waveSpeed, b.waveHeight] = WAVES[b.category] || WAVES.calm;
      en.area = 'Sound · ' + b.category[0].toUpperCase() + b.category.slice(1);
      if (!b.audio && !upload) throw new Error('Choose the recording to upload.');
      break;
    }
    case 'meditation': {
      item.minutes = Number($('f-minutes').value);
      en.prompts = lines($('f-prompts').value);
      if (!en.prompts.length) throw new Error('Add at least one guidance line.');
      b.promptAt = en.prompts.map((_, i) => Math.round((i / en.prompts.length) * 1000) / 1000);
      break;
    }
    case 'breathing':
      for (const k of ['inhale', 'holdIn', 'exhale', 'holdOut']) b[k] = Number($('f-' + k).value);
      break;
    case 'prompt':
      b.group = $('f-group').value;
      en.seed = $('f-seed').value;
      break;
    case 'lesson':
      item.minutes = Number($('f-minutes').value);
      b.art = $('f-art').value;
      en.area = $('f-area').value;
      // The app files a lesson under the hub its colour names.
      item.accent = en.area.toLowerCase();
      en.paragraphs = $('f-paragraphs').value.split(/\\n\\s*\\n/).map((p) => p.trim()).filter(Boolean);
      if (!en.paragraphs.length) throw new Error('Add the lesson text.');
      break;
  }
  for (const box of document.querySelectorAll('#tr-fields [data-locale]')) {
    const l = box.dataset.locale, x = item.text[l] = { ...item.text[l] };
    for (const f of box.querySelectorAll('[data-k]')) {
      const k = f.dataset.k;
      x[k] = k === 'prompts' ? lines(f.value) : k === 'paragraphs' ? f.value.split(/\\n\\s*\\n/).map((p) => p.trim()).filter(Boolean) : f.value.trim();
    }
    x.reviewed = box.querySelector('.tr-reviewed').checked;
  }
  // Prompts and paragraphs must line up with English in every language;
  // a changed count can't be fixed by a reviewer later, so drop that
  // translation and let it be drafted again.
  for (const l of Object.keys(LOCALES)) {
    const x = item.text[l];
    if (!x) continue;
    for (const k of ['prompts', 'paragraphs']) {
      if (en[k] && x[k] && x[k].length !== en[k].length) delete item.text[l];
    }
  }
  return item;
}

async function sha256(file) {
  const digest = await crypto.subtle.digest('SHA-256', await file.arrayBuffer());
  return [...new Uint8Array(digest)].map((x) => x.toString(16).padStart(2, '0')).join('');
}

async function sendRecording(name, file) {
  const progress = (p) => { const bar = $('f-progress'); if (bar) bar.style.width = Math.round(p * 100) + '%'; };
  const start = await api('/admin/api/uploads', { method: 'POST', body: JSON.stringify({ name, bytes: file.size, contentType: file.type }) });
  if (start.done) { progress(1); return; }
  const parts = [];
  try {
    for (let n = 1, at = 0; at < file.size; n++, at += start.partSize) {
      const chunk = file.slice(at, Math.min(file.size, at + start.partSize));
      parts.push(await api('/admin/api/uploads/' + encodeURIComponent(start.uploadId) + '/' + n + '?key=' + encodeURIComponent(start.key), { method: 'PUT', body: chunk }));
      progress(Math.min(1, (at + chunk.size) / file.size));
    }
    await api('/admin/api/uploads/' + encodeURIComponent(start.uploadId) + '/complete', { method: 'POST', body: JSON.stringify({ key: start.key, parts: parts.map(({ partNumber, etag }) => ({ partNumber, etag })) }) });
  } catch (e) {
    api('/admin/api/uploads/' + encodeURIComponent(start.uploadId) + '?key=' + encodeURIComponent(start.key), { method: 'DELETE' }).catch(() => {});
    throw e;
  }
}

$('editor').onsubmit = async (e) => {
  e.preventDefault();
  $('save-error').textContent = '';
  const button = $('save');
  button.disabled = true;
  try {
    const item = collect();
    let master;
    if (upload) {
      const ext = upload.file.name.split('.').pop().toLowerCase();
      const base = (editing.path ? item.id : item.kind + '-' + item.text.en.title).toLowerCase().normalize('NFKD').replace(/[\\u0300-\\u036f]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60);
      const name = base + '-' + Date.now().toString(36) + '.' + ext;
      $('save-status').textContent = 'Checking the recording…';
      const hash = await sha256(upload.file);
      $('save-status').textContent = 'Uploading the recording…';
      await sendRecording(name, upload.file);
      item.body[upload.role] = 'Sounds/' + name;
      master = { role: upload.role, name, bytes: upload.file.size, sha256: hash };
    }
    $('save-status').textContent = 'Saving…';
    const saved = await api('/admin/api/items', { method: 'POST', body: JSON.stringify({ path: editing.path, item, master }) });
    $('save-status').innerHTML = '<span class="ok">Saved.</span> Translations, checks and the staging publish run now; this takes a few minutes.';
    upload = null;
    await load();
    const found = state.items.find((x) => x.path === saved.path);
    if (found) editing = { path: found.path, item: structuredClone(found.item) };
  } catch (err) {
    $('save-status').textContent = '';
    $('save-error').textContent = err.message;
  } finally {
    button.disabled = false;
  }
};

// -------------------------------------------------------------- status
async function status() {
  try {
    const s = await api('/admin/api/status');
    const v = (x) => x ? 'version ' + x.version : 'not published';
    $('live').textContent = 'Staging: ' + v(s.live.staging) + ' · Production: ' + v(s.live.production)
      + (s.live.staging && s.live.production && s.live.staging.path.split('-').pop() === s.live.production.path.split('-').pop() ? ' · the same content' : '');
    $('runs').innerHTML = s.runs.slice(0, 4).map((r) => '<li><a href="' + esc(r.url) + '" target="_blank" rel="noopener">' + esc(r.title) + '</a> · '
      + esc(r.status === 'completed' ? (r.conclusion === 'success' ? 'done' : r.conclusion) : r.status) + ' · ' + new Date(r.createdAt).toLocaleString() + '</li>').join('');
    const busy = s.runs.some((r) => r.status !== 'completed');
    clearTimeout(status.timer);
    status.timer = setTimeout(status, busy ? 8000 : 60000);
  } catch (e) {
    $('live').textContent = 'Couldn\\'t read the publish status: ' + e.message;
  }
}
$('publish-prod').onclick = async () => {
  if (!confirm('Publish what\\'s on staging to everyone using the app?')) return;
  const b = $('publish-prod');
  b.disabled = true;
  try {
    await api('/admin/api/publish', { method: 'POST', body: JSON.stringify({ target: 'production' }) });
    setTimeout(status, 3000);
  } catch (e) {
    alert('Couldn\\'t start the publish: ' + e.message);
  } finally {
    b.disabled = false;
  }
};

supabase.auth.getSession().then(({ data }) => showFor(data.session));
</script>
</body>
</html>`;
