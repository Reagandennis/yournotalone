// The published catalogue: what the app bundles and, later, what
// `publish` uploads. One JSON file, published items only, in list order,
// with only the translations that have been reviewed.
import { createHash } from 'node:crypto';
import type { Course, Item } from './content.ts';

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

export function snapshot(items: Item[], courses: Course[], version: number) {
  const body = {
    items: items
      .filter((i) => i.status === 'published')
      .sort(byOrder)
      .map(({ status: _, ...i }) => ({ ...i, text: reviewedText(i.text) })),
    courses: courses
      .filter((c) => c.status === 'published')
      .sort(byOrder)
      .map(({ status: _, ...c }) => ({ ...c, text: reviewedText(c.text) })),
  };
  const hash = createHash('sha256').update(JSON.stringify(body)).digest('hex').slice(0, 16);
  return { format: snapshotFormat, version, hash, ...body };
}
