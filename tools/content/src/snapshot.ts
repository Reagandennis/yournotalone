// The published catalogue: what the app bundles and, later, what
// `publish` uploads. One JSON file, published items only, in list order,
// with only the translations that have been reviewed.
import { createHash } from 'node:crypto';
import type { Background, Course, Item } from './content.ts';

/// Bumped when the app needs new code to read the file.
export const snapshotFormat = 1;

type Localised = Record<string, { reviewed?: boolean }>;

function reviewedText<T extends Localised>(text: T): T {
  const out: Localised = {};
  for (const [locale, t] of Object.entries(text)) {
    if (locale !== 'en' && !t.reviewed) continue;
    const { reviewed: _, ...rest } = t;
    out[locale] = rest;
  }
  return out as T;
}

const byOrder = (a: { order: number; id: string }, b: { order: number; id: string }) =>
  a.order - b.order || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);

/// A published audio file. `key` is the object key in the bucket that
/// `access` implies: the public bucket for "public", the private bucket
/// (signed URLs from the Worker) for "premium".
export type MediaRef = {
  key: string;
  sha256: string;
  bytes: number;
  access: 'public' | 'premium';
};

/// Media per item id. Only `npm run publish` adds it; the bundled snapshot
/// has none, because the app plays bundled audio from its assets.
export type MediaMap = Record<string, { audio?: MediaRef; narration?: MediaRef }>;

/// What goes in a snapshot; `check()`'s result will do.
export type Content = { items: Item[]; courses: Course[]; backgrounds: Background[] };

export function snapshot(
  { items, courses, backgrounds }: Content,
  version: number,
  media?: MediaMap,
) {
  const body = {
    items: items
      .filter((i) => i.status === 'published')
      .sort(byOrder)
      .map(({ status: _, ...i }) => ({ ...i, text: reviewedText(i.text) })),
    courses: courses
      .filter((c) => c.status === 'published')
      .sort(byOrder)
      .map(({ status: _, ...c }) => ({ ...c, text: reviewedText(c.text) })),
    // Scene parameters, not files: the app draws them (lib/backgrounds/).
    // Apps from before backgrounds ignore the field.
    backgrounds: backgrounds
      .filter((b) => b.status === 'published')
      .sort(byOrder)
      .map(({ status: _, ...b }) => ({ ...b, text: reviewedText(b.text) })),
  };
  // With media, the hash covers it too, so a re-recorded file publishes a
  // new version even when the YAML didn't change. Without it, the hash and
  // output are exactly what they were before media existed.
  const hashed = media === undefined ? body : { ...body, media };
  const hash = createHash('sha256').update(JSON.stringify(hashed)).digest('hex').slice(0, 16);
  return media === undefined
    ? { format: snapshotFormat, version, hash, ...body }
    : { format: snapshotFormat, version, hash, ...body, media };
}
