import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { differences, download, scan, upload } from './masters.ts';
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
