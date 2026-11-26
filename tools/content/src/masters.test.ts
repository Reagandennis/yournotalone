import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { differences, download, merge, scan, upload, usedMasters } from './masters.ts';
import { MemoryStore } from './store.ts';

const quiet = () => {};

function folder(files: Record<string, string>) {
  const dir = mkdtempSync(join(tmpdir(), 'masters-'));
  for (const [name, body] of Object.entries(files)) writeFileSync(join(dir, name), body);
  return dir;
}

test('uploads each master once, under private/masters/', async () => {
  const dir = folder({ 'rain.wav': 'rain', 'fire.aiff': 'fire', '.DS_Store': 'x' });
  const store = new MemoryStore();
  const list = await upload(store, dir, quiet);
  assert.deepEqual(list.map((m) => m.key), ['private/masters/fire.aiff', 'private/masters/rain.wav']);
  assert.equal(store.objects.get('yournotalone/private/masters/rain.wav')!.contentType, 'audio/wav');

  store.calls = [];
  await upload(store, dir, quiet);
  assert.equal(store.puts().length, 0, 'nothing uploaded twice');
  rmSync(dir, { recursive: true });
});

test('download puts the folder back and checks every file', async () => {
  const src = folder({ 'rain.wav': 'rain', 'fire.aiff': 'fire' });
  const store = new MemoryStore();
  const list = await upload(store, src, quiet);

  const dest = folder({});
  await download(store, list, dest, quiet);
  assert.equal(readFileSync(join(dest, 'rain.wav'), 'utf8'), 'rain');
  assert.deepEqual(differences(list, scan(dest)), []);

  // A damaged copy in R2 is refused.
  await store.put('yournotalone', 'private/masters/rain.wav', new TextEncoder().encode('rian'), {
    contentType: '',
    cacheControl: '',
  });
  const fresh = folder({});
  await assert.rejects(download(store, list, fresh, quiet), /doesn't match its sha256/);
  for (const d of [src, dest, fresh]) rmSync(d, { recursive: true });
});

test('check reports missing, changed and unlisted files', async () => {
  const dir = folder({ 'rain.wav': 'rain', 'fire.aiff': 'fire' });
  const list = scan(dir);
  writeFileSync(join(dir, 'fire.aiff'), 'embers');
  writeFileSync(join(dir, 'new.wav'), 'new');
  rmSync(join(dir, 'rain.wav'));
  assert.deepEqual(differences(list, scan(dir)), ['changed  fire.aiff', 'missing  rain.wav', 'unlisted new.wav']);
  rmSync(dir, { recursive: true });
});

test('a re-recorded file with the same name is uploaded again', async () => {
  const dir = folder({ 'rain.wav': 'take 1' });
  const store = new MemoryStore();
  await upload(store, dir, quiet);
  writeFileSync(join(dir, 'rain.wav'), 'take 2');
  store.calls = [];
  const list = await upload(store, dir, quiet);
  assert.equal(store.puts().length, 1);
  const there = store.objects.get('yournotalone/private/masters/rain.wav')!;
  assert.equal(new TextDecoder().decode(there.body), 'take 2');
  assert.equal(there.metadata?.sha256, list[0].sha256);
  // So a fresh machine can download what the list says.
  await download(store, list, folder({}), quiet);
  rmSync(dir, { recursive: true });
});

test('a copy in R2 without a sha256 is uploaded again, which adds it', async () => {
  const dir = folder({ 'rain.wav': 'rain' });
  const store = new MemoryStore();
  await store.put('yournotalone', 'private/masters/rain.wav', new TextEncoder().encode('rain'), {
    contentType: 'audio/wav',
    cacheControl: 'private, no-store',
  });
  store.calls = [];
  const [m] = await upload(store, dir, quiet);
  assert.equal(store.puts().length, 1);
  assert.equal(store.objects.get('yournotalone/private/masters/rain.wav')!.metadata?.sha256, m.sha256);
  store.calls = [];
  await upload(store, dir, quiet);
  assert.equal(store.puts().length, 0);
  rmSync(dir, { recursive: true });
});

test('upload merges into the list, keeping files that are not here', () => {
  const old = [
    { name: 'a.wav', key: 'private/masters/a.wav', bytes: 1, sha256: '1' },
    { name: 'b.wav', key: 'private/masters/b.wav', bytes: 1, sha256: '2' },
  ];
  const found = [
    { name: 'b.wav', key: 'private/masters/b.wav', bytes: 2, sha256: '3' },
    { name: 'c d.wav', key: 'private/masters/c d.wav', bytes: 1, sha256: '4' },
  ];
  assert.deepEqual(merge(old, found).map((m) => [m.name, m.sha256]), [['a.wav', '1'], ['b.wav', '3'], ['c d.wav', '4']]);
});

test('the recordings items use come from the YAML, spaces and all', () => {
  const items: [string, unknown][] = [
    ['a.yaml', { body: { type: 'sound', audio: 'Sounds/brown noise.wav' } }],
    ['b.yaml', { body: { type: 'meditation', narration: 'Sounds/body scan (take 2).wav' } }],
    ['c.yaml', { body: { type: 'sound', audio: 'assets/sounds/rain.m4a' } }],
    ['d.yaml', { body: { type: 'sound', audio: 'Sounds/brown noise.wav' } }],
    ['e.yaml', null],
  ];
  assert.deepEqual(usedMasters({ items }), ['body scan (take 2).wav', 'brown noise.wav']);
});
