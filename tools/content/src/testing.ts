// Helpers for the tests (not a test file itself).
//
// The original recordings in Sounds/ aren't in git: they're in R2, listed in
// content/masters.json, and `npm run masters -- download --used` puts them
// back. On a clean checkout an item pointing at Sounds/<name> fails the
// file-exists check, so tests that are about the content (not about this
// machine's Sounds/ folder) count a listed master as present. Publishing
// still checks the real file.
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { type Loaded, repoRoot } from './content.ts';
import { usedMasters } from './masters.ts';

const listed = new Set(
  (JSON.parse(readFileSync(join(repoRoot, 'content', 'masters.json'), 'utf8')) as { name: string }[]).map(
    (m) => m.name,
  ),
);

/// A file in the repo, or a recording listed in content/masters.json.
export function inRepoOrMasters(path: string): boolean {
  if (existsSync(join(repoRoot, path))) return true;
  return path.startsWith('Sounds/') && listed.has(path.slice('Sounds/'.length));
}

/// Recordings the content points at that aren't in Sounds/ on this machine.
export function mastersNotHere(loaded: Pick<Loaded, 'items'>): string[] {
  return usedMasters(loaded).filter((n) => !existsSync(join(repoRoot, 'Sounds', n)));
}
