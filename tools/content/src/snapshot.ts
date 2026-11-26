// The published catalogue: what the app bundles and, later, what
// `publish` uploads. One JSON file, published items only, in list order.
// Every translation goes in with `reviewed: true` or `false`; the app
// shows an unreviewed one only in a build with drafts on (design §7a).
import { createHash } from 'node:crypto';
import type { Background, Course, Item } from './content.ts';

/// Bumped when the app needs new code to read the file.
export const snapshotFormat = 1;

type Localised = Record<string, { reviewed?: boolean }>;

/// English as it is; each translation with an explicit `reviewed` flag.
/// Apps from before translations read only `en`; ones that read other
/// locales treat a missing flag as reviewed, which is what snapshots
/// before this one meant.
function localisedText<T extends Localised>(text: T): T {
  const out: Localised = {};
  for (const [locale, t] of Object.entries(text)) {
    const { reviewed, ...rest } = t;
    out[locale] = locale === 'en' ? rest : { ...rest, reviewed: reviewed === true };
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

/// `builtAt` is when the snapshot was made (an ISO time): the publish, or
/// the build for the copy the app bundles. The app compares it, not the
/// version, to pick the newer of the bundled and the downloaded catalogue,
/// since the bundled copy is version 0 whatever it holds. It isn't in the
/// hash: the same content made twice is the same catalogue.
export function snapshot(
  { items, courses, backgrounds }: Content,
  version: number,
  media?: MediaMap,
  builtAt?: string,
  /// What `format` says; [snapshotFormat] except in tests.
  format = snapshotFormat,
) {
  const body = {
    items: items
      .filter((i) => i.status === 'published')
      .sort(byOrder)
      .map(({ status: _, ...i }) => ({ ...i, text: localisedText(i.text) })),
    courses: courses
      .filter((c) => c.status === 'published')
      .sort(byOrder)
      .map(({ status: _, ...c }) => ({ ...c, text: localisedText(c.text) })),
    // Scene parameters, not files: the app draws them (lib/backgrounds/).
    // Apps from before backgrounds ignore the field.
    backgrounds: backgrounds
      .filter((b) => b.status === 'published')
      .sort(byOrder)
      .map(({ status: _, ...b }) => ({ ...b, text: localisedText(b.text) })),
  };
  // With media, the hash covers it too, so a re-recorded file publishes a
  // new version even when the YAML didn't change. The format is in it as
  // well, so raising snapshotFormat alone publishes. (minApp lives in
  // latest.json; the publisher compares it separately.)
  const hashed = media === undefined
    ? { format, ...body }
    : { format, ...body, media };
  const hash = createHash('sha256').update(JSON.stringify(hashed)).digest('hex').slice(0, 16);
  const head = builtAt === undefined
    ? { format, version, hash }
    : { format, version, hash, builtAt };
  return media === undefined ? { ...head, ...body } : { ...head, ...body, media };
}
