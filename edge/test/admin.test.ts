import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { parse } from 'yaml';
import { resetAuthState } from '../src/auth';
import { indexItems, prepare, slugify, toYaml, withMaster } from '../src/admin/items';
import { call, json, mockFetch, setupKeys, testEnv, token, type MockState } from './helpers';

const ADMIN_ENV = { ADMIN_GITHUB_TOKEN: 'github_pat_test', GITHUB_REPO: 'owner/repo' };
const GH = 'https://api.github.com';

const RAIN = `id: "sound:Rainfall"
kind: sound
status: published
order: 210
premium: true
icon: water_drop_outlined
accent: blue
tags:
  needs: [sleep]
  dayParts: [night]
text:
  en:
    title: "Rainfall"
    blurb: "Steady rain on a quiet evening."
    area: "Sound · Sleep"
  fr:
    title: "Pluie"
    blurb: "Une pluie régulière."
    area: "Son · Sommeil"
    reviewed: true
body:
  type: sound
  category: sleep
  audio: "assets/sounds/rainfall.m4a"
  loop: true
  waveFreq: 7
  waveSpeed: 3
  waveHeight: 0.4
  pulse: false
`;
const PROMPT = `id: prompt-three-lines\nkind: prompt\nstatus: published\norder: 300\n`;

let m: MockState;
/** Commits made through the git data API, as {path: text}. */
let committed: Record<string, string>[];
let dispatched: unknown[];

function github(files: Record<string, string>) {
  committed = [];
  dispatched = [];
  let pendingTree: Record<string, string> = {};
  return async (url: URL, init?: RequestInit) => {
    const body = init?.body ? JSON.parse(String(init.body)) : undefined;
    const p = url.pathname;
    if (p === '/graphql') {
      const entries = Object.entries(files)
        .filter(([path]) => path.startsWith('content/items/'))
        .map(([path, text]) => ({ path, type: 'blob', object: { text } }));
      return json({ data: { repository: { object: { entries: [{ path: 'content/items/x', type: 'tree', object: { entries } }] } } } });
    }
    if (p.startsWith('/repos/owner/repo/contents/')) {
      const path = decodeURIComponent(p.slice('/repos/owner/repo/contents/'.length));
      const text = files[path];
      return text === undefined ? json({ message: 'Not Found' }, 404) : json({ content: btoa(unescape(encodeURIComponent(text))), encoding: 'base64' });
    }
    if (p === '/repos/owner/repo/git/ref/heads/main') return json({ object: { sha: 'head1' } });
    if (p === '/repos/owner/repo/git/commits/head1') return json({ tree: { sha: 'tree1' } });
    if (p === '/repos/owner/repo/git/trees') {
      pendingTree = Object.fromEntries(body.tree.map((t: { path: string; content: string }) => [t.path, t.content]));
      return json({ sha: 'tree2' });
    }
    if (p === '/repos/owner/repo/git/commits') return json({ sha: 'commit2' });
    if (p === '/repos/owner/repo/git/refs/heads/main' && init?.method === 'PATCH') {
      committed.push(pendingTree);
      return json({ object: { sha: body.sha } });
    }
    if (p === '/repos/owner/repo/actions/workflows/content.yml/dispatches') {
      dispatched.push(body);
      return new Response(null, { status: 204 });
    }
    if (p === '/repos/owner/repo/actions/workflows/content.yml/runs') return json({ workflow_runs: [] });
    return json({ message: 'Not Found' }, 404);
  };
}

const files = () => ({
  'content/items/sound/rainfall.yaml': RAIN,
  'content/items/prompt/three-lines.yaml': PROMPT,
  'content/vocab.yaml': 'kinds: [sound]\n',
  'lib/content/content_icons.dart': "'water_drop_outlined': Icons.water_drop_outlined,",
  'content/masters.json': '[]\n',
});

async function admin(path: string, init: RequestInit = {}, o: { admin?: boolean; env?: object } = {}) {
  return call(path, { ...init, bearer: await token({ admin: o.admin ?? true }) }, { ...ADMIN_ENV, ...(o.env ?? {}) });
}

const post = (body: unknown): RequestInit => ({
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});

const newSound = (audio = 'Sounds/sound-ocean-waves-x1.wav') => ({
  kind: 'sound',
  status: 'draft',
  premium: false,
  icon: 'waves_rounded',
  accent: 'blue',
  tags: { needs: ['sleep'], dayParts: ['night'], intensity: 'gentle', calmingSafe: true },
  text: { en: { title: 'Ocean waves at night', blurb: 'Slow waves on a dark shore.', area: 'Sound · Sleep' } },
  body: { type: 'sound', category: 'sleep', audio, loop: true, waveFreq: 7, waveSpeed: 3, waveHeight: 0.35, pulse: false },
});

beforeAll(setupKeys);
beforeEach(() => {
  resetAuthState();
  m = mockFetch();
  m.github = github(files());
  vi.spyOn(console, 'log').mockImplementation(() => {});
});
afterEach(() => vi.restoreAllMocks());

describe('admin page', () => {
  it('serves the page with a fresh nonce and no placeholders left', async () => {
    const res = await call('/admin');
    expect(res.status).toBe(200);
    const html = await res.text();
    const csp = res.headers.get('Content-Security-Policy')!;
    const nonce = /'nonce-([^']+)'/.exec(csp)![1];
    expect(html).toContain(`nonce="${nonce}"`);
    expect(html).not.toMatch(/__[A-Z_]+__/);
    expect(html).toContain('https://test-project.supabase.co');
    expect(csp).toContain("frame-ancestors 'none'");
    expect(res.headers.get('Cache-Control')).toBe('no-store');
  });
});

describe('admin API: who gets in', () => {
  it('401 without a session', async () => {
    expect((await call('/admin/api/items', {}, ADMIN_ENV)).status).toBe(401);
  });

  it('403 for a signed-in user who is not a content admin', async () => {
    const res = await admin('/admin/api/items', {}, { admin: false });
    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: 'not_admin' });
  });

  it('403 when the flag is only in user_metadata', async () => {
    // token() puts goals in user_metadata; content_admin there must not count.
    const res = await call('/admin/api/items', { bearer: await token({ goals: [] }) }, ADMIN_ENV);
    expect(res.status).toBe(403);
  });

  it('503 when the GitHub token is not set', async () => {
    const res = await admin('/admin/api/items', {}, { env: { ADMIN_GITHUB_TOKEN: undefined } });
    expect(res.status).toBe(503);
  });

  it('lists the item files, vocabulary and icons for an admin', async () => {
    const res = await admin('/admin/api/items');
    expect(res.status).toBe(200);
    const body = (await res.json()) as { files: { path: string }[]; vocab: string; icons: string };
    expect(body.files.map((f) => f.path).sort()).toEqual(['content/items/prompt/three-lines.yaml', 'content/items/sound/rainfall.yaml']);
    expect(body.vocab).toContain('kinds');
    const auth = m.requests.find((r) => r.url.origin === GH)!.init!.headers as Record<string, string>;
    expect(auth.Authorization).toBe('Bearer github_pat_test');
  });
});

describe('admin API: saving', () => {
  async function putRecording(name: string, bytes: number) {
    await testEnv.CONTENT_BUCKET!.put(`private/masters/${name}`, new Uint8Array(bytes));
  }

  it('adds a new sound with its recording in one commit', async () => {
    await putRecording('sound-ocean-waves-x1.wav', 1234);
    const res = await admin('/admin/api/items', post({
      item: newSound(),
      master: { role: 'audio', name: 'sound-ocean-waves-x1.wav', bytes: 1234, sha256: 'a'.repeat(64) },
    }));
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ id: 'sound-ocean-waves-at-night', path: 'content/items/sound/ocean-waves-at-night.yaml' });
    expect(committed).toHaveLength(1);
    const item = parse(committed[0]['content/items/sound/ocean-waves-at-night.yaml']);
    expect(item).toMatchObject({ id: 'sound-ocean-waves-at-night', kind: 'sound', order: 220, status: 'draft' });
    expect(item.addedOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(Object.keys(item).slice(0, 4)).toEqual(['id', 'kind', 'status', 'order']);
    expect(JSON.parse(committed[0]['content/masters.json'])).toEqual([
      { name: 'sound-ocean-waves-x1.wav', key: 'private/masters/sound-ocean-waves-x1.wav', bytes: 1234, sha256: 'a'.repeat(64) },
    ]);
  });

  it('refuses a recording that was never uploaded', async () => {
    const res = await admin('/admin/api/items', post({
      item: newSound('Sounds/sound-missing.wav'),
      master: { role: 'audio', name: 'sound-missing.wav', bytes: 10, sha256: 'a'.repeat(64) },
    }));
    expect(res.status).toBe(400);
    expect(committed).toHaveLength(0);
  });

  it('refuses a recording the item does not point at', async () => {
    await putRecording('sound-other.wav', 10);
    const res = await admin('/admin/api/items', post({
      item: newSound('Sounds/sound-ocean.wav'),
      master: { role: 'audio', name: 'sound-other.wav', bytes: 10, sha256: 'a'.repeat(64) },
    }));
    expect(res.status).toBe(400);
  });

  it('keeps the id and kind of an existing item and sends changed English back to review', async () => {
    const before = parse(RAIN);
    const edited = { ...before, id: 'sound:Hacked', kind: 'meditation', text: { ...before.text, en: { ...before.text.en, blurb: 'Rain, all night.' } } };
    const res = await admin('/admin/api/items', post({ path: 'content/items/sound/rainfall.yaml', item: edited }));
    expect(res.status).toBe(200);
    const item = parse(committed[0]['content/items/sound/rainfall.yaml']);
    expect(item.id).toBe('sound:Rainfall');
    expect(item.kind).toBe('sound');
    expect(item.text.fr.reviewed).toBe(false);
    expect(Object.keys(committed[0])).toEqual(['content/items/sound/rainfall.yaml']);
  });

  it("refuses to change an item's body type", async () => {
    const before = parse(RAIN);
    const res = await admin('/admin/api/items', post({ path: 'content/items/sound/rainfall.yaml', item: { ...before, body: { type: 'lesson', art: 'moon' } } }));
    expect(res.status).toBe(400);
  });

  it('says what a form got wrong', async () => {
    const res = await admin('/admin/api/items', post({ item: { ...newSound(), tags: { needs: [], dayParts: [] } } }));
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: 'invalid_item', message: 'pick at least one need' });
  });

  it('only creates kinds that are content, not app screens', async () => {
    const res = await admin('/admin/api/items', post({ item: { ...newSound(), kind: 'tool' } }));
    expect(res.status).toBe(400);
  });
});

describe('admin API: uploads', () => {
  it('uploads a recording in parts to private/masters/', async () => {
    const start = await admin('/admin/api/uploads', post({ name: 'sound-test-upload.wav', bytes: 6 * 1024 * 1024 + 10, contentType: 'audio/wav' }));
    expect(start.status).toBe(200);
    const { key, uploadId } = (await start.json()) as { key: string; uploadId: string };
    expect(key).toBe('private/masters/sound-test-upload.wav');
    const parts = [];
    for (const [n, size] of [[1, 6 * 1024 * 1024], [2, 10]] as const) {
      const res = await admin(`/admin/api/uploads/${encodeURIComponent(uploadId)}/${n}?key=${encodeURIComponent(key)}`, {
        method: 'PUT',
        headers: { 'Content-Length': String(size) },
        body: new Uint8Array(size),
      });
      expect(res.status).toBe(200);
      parts.push(await res.json());
    }
    const done = await admin(`/admin/api/uploads/${encodeURIComponent(uploadId)}/complete`, post({ key, parts }));
    expect(await done.json()).toEqual({ key, bytes: 6 * 1024 * 1024 + 10 });
    expect((await testEnv.CONTENT_BUCKET!.head(key))?.size).toBe(6 * 1024 * 1024 + 10);
  });

  it('refuses names that could land outside private/masters/', async () => {
    for (const name of ['../catalog/latest.json', 'Rain.wav', 'a/b.wav', 'rain.exe']) {
      const res = await admin('/admin/api/uploads', post({ name, bytes: 10 }));
      expect(res.status, name).toBe(400);
    }
    const part = await admin('/admin/api/uploads/x/1?key=catalog/latest.json', { method: 'PUT', body: 'x' });
    expect(part.status).toBe(400);
  });

  it('says a name is taken by a different recording', async () => {
    await testEnv.CONTENT_BUCKET!.put('private/masters/sound-taken.wav', new Uint8Array(5));
    expect((await admin('/admin/api/uploads', post({ name: 'sound-taken.wav', bytes: 6 }))).status).toBe(409);
    expect(await (await admin('/admin/api/uploads', post({ name: 'sound-taken.wav', bytes: 5 }))).json()).toMatchObject({ done: true });
  });
});

describe('admin API: publishing', () => {
  it('starts the content workflow for production', async () => {
    const res = await admin('/admin/api/publish', post({ target: 'production' }));
    expect(res.status).toBe(200);
    expect(dispatched).toEqual([{ ref: 'main', inputs: { env: 'production' } }]);
  });

  it('refuses any other target', async () => {
    expect((await admin('/admin/api/publish', post({ target: 'everywhere' }))).status).toBe(400);
    expect(dispatched).toEqual([]);
  });
});

describe('items', () => {
  it('slugs titles', () => {
    expect(slugify('Ocean waves — at night!')).toBe('ocean-waves-at-night');
    expect(slugify('Café crème')).toBe('cafe-creme');
  });

  it('indexes ids, kinds and orders without a YAML parser', () => {
    expect(indexItems([{ path: 'content/items/sound/rainfall.yaml', text: RAIN }])).toEqual([
      { id: 'sound:Rainfall', kind: 'sound', order: 210, path: 'content/items/sound/rainfall.yaml' },
    ]);
  });

  it('numbers a new id that is taken', () => {
    const index = [{ id: 'sound-ocean', kind: 'sound', order: 10, path: 'content/items/sound/ocean.yaml' }];
    const { item, path } = prepare({ ...newSound(), text: { en: { title: 'Ocean', blurb: 'x' } } }, index, null, '2026-11-04');
    expect(item.id).toBe('sound-ocean-2');
    expect(path).toBe('content/items/sound/ocean-2.yaml');
  });

  it('keeps masters.json sorted, one entry per name', () => {
    const one = withMaster(null, { name: 'b.wav', key: 'private/masters/b.wav', bytes: 1, sha256: 'x' });
    const two = withMaster(withMaster(one, { name: 'a.wav', key: 'private/masters/a.wav', bytes: 2, sha256: 'y' }), { name: 'b.wav', key: 'private/masters/b.wav', bytes: 3, sha256: 'z' });
    expect(JSON.parse(two).map((x: { name: string; bytes: number }) => [x.name, x.bytes])).toEqual([['a.wav', 2], ['b.wav', 3]]);
  });

  it('writes YAML the content tool reads back the same', () => {
    const item = parse(RAIN);
    expect(parse(toYaml(item))).toEqual(item);
  });
});
