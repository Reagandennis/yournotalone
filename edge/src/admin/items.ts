// Content items as the admin page reads and writes them: the YAML files in
// content/items/ (content/README.md). The checks here are only the ones a
// form can get wrong; the content workflow runs the full checker
// (tools/content, npm run check) before anything is published, and stops
// on any error.

import { parse, stringify } from 'yaml';
import { HttpError } from '../http';
import type { RepoFile } from './github';

export const ITEMS_DIR = 'content/items';
export const MASTERS_PATH = 'content/masters.json';
export const MASTERS_PREFIX = 'private/masters/';

/** Kinds the page can create. Tools and recovery screens are built into the app. */
export const CREATABLE = ['sound', 'meditation', 'breathing', 'prompt', 'lesson'] as const;
const STATUSES = ['draft', 'published', 'retired'];
const LOCALES = ['fr', 'de', 'es', 'zh-Hans'];
const KEY_ORDER = [
  'id', 'kind', 'status', 'order', 'premium', 'addedOn', 'minutes', 'icon', 'accent', 'tags', 'text', 'body', 'background',
];

/** Upload names: what the item is called, plus the recording's own extension. */
export const MASTER_NAME = /^[a-z0-9]+(-[a-z0-9]+)*\.(wav|flac|aif|aiff|m4a|mp3|aac)$/;
const ID = /^([a-z]+:.+|[a-z0-9]+(-[a-z0-9]+)*)$/;

export type Item = Record<string, any>;

export interface Master {
  name: string;
  key: string;
  bytes: number;
  sha256: string;
}

/** What a save needs to know about every other item, read without a YAML parser (CPU is short here). */
export interface IndexEntry {
  id: string;
  kind: string;
  order: number;
  path: string;
}

export function slugify(s: string): string {
  return s
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48)
    .replace(/-+$/, '');
}

const unquote = (v: string) => {
  const t = v.trim();
  if (t.startsWith('"')) {
    try {
      return JSON.parse(t) as string;
    } catch {
      return t.slice(1, -1);
    }
  }
  return t.startsWith("'") ? t.slice(1, -1).replace(/''/g, "'") : t;
};

/** The top-level id, kind and order of each item file. */
export function indexItems(files: RepoFile[]): IndexEntry[] {
  const out: IndexEntry[] = [];
  for (const f of files) {
    if (!f.path.endsWith('.yaml')) continue;
    const field = (name: string) => new RegExp(`^${name}:[ \\t]*(.+)$`, 'm').exec(f.text)?.[1];
    const id = field('id');
    if (!id) continue;
    out.push({ id: unquote(id), kind: unquote(field('kind') ?? ''), order: Number(field('order')) || 0, path: f.path });
  }
  return out;
}

export function parseItem(text: string): Item {
  const item = parse(text);
  if (!item || typeof item !== 'object' || typeof item.id !== 'string') throw new HttpError(500, 'item_unreadable');
  return item;
}

/** The item's YAML, keys in the order the files use. */
export function toYaml(item: Item): string {
  const ordered: Item = {};
  for (const k of KEY_ORDER) if (item[k] !== undefined && item[k] !== null) ordered[k] = item[k];
  for (const k of Object.keys(item)) if (!(k in ordered) && item[k] !== undefined && item[k] !== null) ordered[k] = item[k];
  return stringify(ordered, { lineWidth: 0 });
}

const bad = (message: string) => new HttpError(400, 'invalid_item', message);
const text = (x: unknown) => typeof x === 'string' && x.trim().length > 0;

/**
 * Checks what a form can get wrong, and fills in what a new item needs:
 * its id, order, the day it was added. [existing] is everything on main.
 */
export function prepare(
  input: Item,
  index: IndexEntry[],
  before: { item: Item; path: string } | null,
  today: string,
): { item: Item; path: string } {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw bad('item must be an object');
  const item: Item = structuredClone(input);

  if (before) {
    // The id, kind and kind of body never change: saves, course days and
    // practice history point at the id, and the app opens items by body.
    item.id = before.item.id;
    item.kind = before.item.kind;
    if (item.body?.type !== before.item.body?.type) throw bad("an item's body type can't change");
  } else {
    if (!CREATABLE.includes(item.kind)) throw bad(`new items can be ${CREATABLE.join(', ')}`);
    const base = `${item.kind}-${slugify(item.text?.en?.title ?? '')}`;
    if (base === `${item.kind}-`) throw bad('a title is needed');
    const taken = new Set(index.map((e) => e.id));
    let id = base;
    for (let n = 2; taken.has(id); n++) id = `${base}-${n}`;
    item.id = id;
    item.addedOn ??= today;
    if (typeof item.order !== 'number') {
      const orders = index.filter((e) => e.kind === item.kind).map((e) => e.order);
      item.order = (orders.length ? Math.max(...orders) : 0) + 10;
    }
  }

  if (!ID.test(item.id)) throw bad('bad id');
  if (!STATUSES.includes(item.status)) throw bad(`status must be ${STATUSES.join(', ')}`);
  if (typeof item.premium !== 'boolean') throw bad('premium must be true or false');
  if (!text(item.text?.en?.title) || !text(item.text?.en?.blurb)) throw bad('English title and description are needed');
  if (!Array.isArray(item.tags?.needs) || item.tags.needs.length === 0) throw bad('pick at least one need');
  if (!Array.isArray(item.tags?.dayParts)) item.tags.dayParts = [];
  if (!text(item.icon) || !text(item.accent)) throw bad('icon and colour are needed');
  if (!item.body || typeof item.body !== 'object' || !text(item.body.type)) throw bad('body is missing');
  if (item.tags.support === true && item.premium) throw bad('support content is always free');

  // An English change makes the old translations stale: send them back
  // to review rather than publish them as checked.
  if (before) {
    const en = (i: Item) => JSON.stringify(i.text?.en ?? {});
    if (en(before.item) !== en(item)) {
      for (const l of LOCALES) {
        if (item.text?.[l] && JSON.stringify(item.text[l]) === JSON.stringify(before.item.text?.[l])) {
          item.text[l].reviewed = false;
        }
      }
    }
  }

  const path = before?.path ?? `${ITEMS_DIR}/${item.kind}/${item.id.replace(/^[a-z]+-/, '')}.yaml`;
  if (!before && index.some((e) => e.path === path)) throw new HttpError(409, 'path_taken', path);
  return { item, path };
}

/** content/masters.json with [m] added, or replacing the entry of the same name. */
export function withMaster(current: string | null, m: Master): string {
  let list: Master[] = [];
  if (current) {
    try {
      const parsed = JSON.parse(current);
      if (Array.isArray(parsed)) list = parsed;
    } catch {
      throw new HttpError(500, 'masters_unreadable');
    }
  }
  list = [...list.filter((x) => x.name !== m.name), m].sort((a, b) => (a.name < b.name ? -1 : 1));
  return `${JSON.stringify(list, null, 2)}\n`;
}
