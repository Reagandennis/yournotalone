// npm run build: check content/, then write the snapshot the app bundles
// (assets/catalog/bundled.json). Version 0 marks the bundled copy; a
// published catalogue always has a higher one.
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { check, load, repoRoot } from './content.ts';
import { snapshot } from './snapshot.ts';

const { items, courses, errors } = check(load());
if (errors.length) {
  console.error(errors.join('\n'));
  console.error(`\n${errors.length} problem(s); nothing written.`);
  process.exit(1);
}
const out = join(repoRoot, 'assets/catalog/bundled.json');
const snap = snapshot(items, courses, 0);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(snap) + '\n');
console.log(
  `Wrote assets/catalog/bundled.json: ${snap.items.length} items, ` +
    `${snap.courses.length} courses, hash ${snap.hash}.`,
);
