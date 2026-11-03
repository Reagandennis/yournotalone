// npm run build: check content/, then write the snapshot the app bundles
// (assets/catalog/bundled.json). Version 0 marks the bundled copy; a
// published catalogue always has a higher one.
//
// It carries the same media map a publish writes, so audio that isn't
// bundled in the app can be fetched from the first launch, before any
// catalogue has been downloaded. Keys are the same in every environment.
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { envs, minApp } from './config.ts';
import { check, load, repoRoot } from './content.ts';
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
    prepareFile(join(repoRoot, src.path), src.role, {
      cacheDir,
      warn: (m) => console.warn(`warning: ${m}`),
    }),
});
const { media } = JSON.parse(new TextDecoder().decode(p.snapshot.body));
const snap = snapshot(checked, 0, media);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(snap) + '\n');
console.log(
  `Wrote assets/catalog/bundled.json: ${snap.items.length} items, ` +
    `${snap.courses.length} courses, ${snap.backgrounds.length} backgrounds, ` +
    `${Object.keys(media).length} with media, hash ${snap.hash}.`,
);
