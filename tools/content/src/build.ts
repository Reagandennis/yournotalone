// npm run build: check content/, then write the snapshot the app bundles
// (assets/catalog/bundled.json). Version 0 marks the bundled copy. It is
// stamped with when it was built (`builtAt`), which is how the app tells
// whether a catalogue it downloaded earlier is newer or older than the one
// an app update ships; the version can't, as it's 0 whatever the copy holds.
// Rebuilding unchanged content keeps the old stamp, so the file only
// changes when the catalogue does.
//
// It carries the same media map a publish writes, so audio that isn't
// bundled in the app can be fetched from the first launch, before any
// catalogue has been downloaded. Keys are the same in every environment.
//
// Those keys are the sha256 of this machine's encodes. Another machine's
// ffmpeg can encode differently, so a copy built here can name files that
// were never uploaded. Don't commit one: the content workflow writes the
// committed copy with `npm run bundle`, from what production serves.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { envs, minApp } from './config.ts';
import { check, load, mediaFile, repoRoot } from './content.ts';
import { plan } from './publisher.ts';
import { snapshot } from './snapshot.ts';
import { prepareFile } from './transcode.ts';

const checked = check(load());
const { errors } = checked;
if (errors.length) {
  console.error(errors.join('\n'));
  console.error(`\n${errors.length} problem(s); nothing written.`);
  process.exit(1);
}
const out = join(repoRoot, 'assets/catalog/bundled.json');
const cacheDir = join(resolve(import.meta.dirname, '..'), '.cache');
const p = await plan({
  ...checked,
  env: envs.production,
  minApp,
  store: null,
  prepare: (src) =>
    prepareFile(mediaFile(src.path), src.role, {
      cacheDir,
      warn: (m) => console.warn(`warning: ${m}`),
    }),
});
const { media } = JSON.parse(new TextDecoder().decode(p.snapshot.body));
const before = existsSync(out) ? JSON.parse(readFileSync(out, 'utf8')) : null;
const fresh = snapshot(checked, 0, media);
const builtAt =
  before?.hash === fresh.hash && typeof before.builtAt === 'string'
    ? before.builtAt
    : new Date().toISOString();
const snap = snapshot(checked, 0, media, builtAt);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(snap) + '\n');
console.log(
  `Wrote assets/catalog/bundled.json: ${snap.items.length} items, ` +
    `${snap.courses.length} courses, ${snap.backgrounds.length} backgrounds, ` +
    `${Object.keys(media).length} with media, hash ${snap.hash}.`,
);
console.warn(
  'Media keys come from this machine\'s encodes, so this copy is for local testing; ' +
    "don't commit it. CI writes the committed copy with `npm run bundle` after a production publish.",
);
