// Loads content/ and checks it: the schema of each file, then the rules
// that span files (unique ids, course days that exist, prompts that line
// up with their timings). See docs/backend-design.md §4 and §8.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { parse } from 'yaml';
import { z } from 'zod';

export const repoRoot = resolve(import.meta.dirname, '../../..');

export type Vocab = {
  locales: string[];
  kinds: string[];
  needs: string[];
  dayParts: string[];
  accents: string[];
  soundCategories: string[];
  promptGroups: string[];
};

export type Loaded = {
  vocab: Vocab;
  icons: Set<string>;
  // [path relative to the repo, parsed YAML]
  items: [string, unknown][];
  courses: [string, unknown][];
};

const vocabSchema = z.strictObject({
  locales: z.array(z.string()).min(1),
  kinds: z.array(z.string()).min(1),
  needs: z.array(z.string()).min(1),
  dayParts: z.array(z.string()).min(1),
  accents: z.array(z.string()).min(1),
  soundCategories: z.array(z.string()).min(1),
  promptGroups: z.array(z.string()).min(1),
});

function yamlFiles(dir: string): string[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { recursive: true, encoding: 'utf8' })
    .filter((f) => f.endsWith('.yaml'))
    .map((f) => join(dir, f))
    .sort();
}

/// The icon names the app knows, read from the Dart map so the two can't
/// drift apart.
export function readIcons(root = repoRoot): Set<string> {
  const dart = readFileSync(join(root, 'lib/content/content_icons.dart'), 'utf8');
  return new Set([...dart.matchAll(/^\s*'([a-z0-9_]+)': Icons\./gm)].map((m) => m[1]));
}

export function load(root = repoRoot): Loaded {
  const dir = join(root, 'content');
  const read = (f: string): [string, unknown] => [
    relative(root, f),
    parse(readFileSync(f, 'utf8')),
  ];
  return {
    vocab: vocabSchema.parse(parse(readFileSync(join(dir, 'vocab.yaml'), 'utf8'))),
    icons: readIcons(root),
    items: yamlFiles(join(dir, 'items')).map(read),
    courses: yamlFiles(join(dir, 'courses')).map(read),
  };
}

const statuses = ['draft', 'published', 'retired'] as const;
const nonEmpty = z.string().trim().min(1);

/// Which bodies each kind may carry. Recovery holds both the urge-surfing
/// meditation and app-built screens.
const bodiesFor: Record<string, string[]> = {
  breathing: ['breathing'],
  meditation: ['meditation'],
  sound: ['sound'],
  prompt: ['prompt'],
  lesson: ['lesson'],
  tool: ['native'],
  recovery: ['meditation', 'native'],
};

function schemas(v: Vocab) {
  const text = z.strictObject({
    title: nonEmpty,
    blurb: nonEmpty,
    area: nonEmpty.optional(),
    meta: nonEmpty.optional(),
    prompts: z.array(nonEmpty).optional(),
    paragraphs: z.array(nonEmpty).optional(),
    seed: z.string().optional(),
    // Translations publish only once a fluent reader has checked them.
    reviewed: z.boolean().optional(),
  });
  const body = z.discriminatedUnion('type', [
    z.strictObject({
      type: z.literal('breathing'),
      inhale: z.int().positive(),
      holdIn: z.int().nonnegative(),
      exhale: z.int().positive(),
      holdOut: z.int().nonnegative(),
    }),
    z.strictObject({
      type: z.literal('meditation'),
      promptAt: z.array(z.number().min(0).lt(1)).min(1),
      narration: nonEmpty.nullish(),
    }),
    z.strictObject({
      type: z.literal('sound'),
      category: z.enum(v.soundCategories),
      audio: nonEmpty,
      loop: z.boolean(),
      waveFreq: z.number().positive(),
      waveSpeed: z.int().positive(),
      waveHeight: z.number().positive(),
      pulse: z.boolean(),
    }),
    z.strictObject({ type: z.literal('prompt'), group: z.enum(v.promptGroups) }),
    z.strictObject({ type: z.literal('lesson'), art: nonEmpty }),
    z.strictObject({ type: z.literal('native'), screen: nonEmpty, art: nonEmpty.optional() }),
  ]);
  const item = z.strictObject({
    // Existing items keep their `kind:Title` id forever (saves, course days
    // and practice history point at it); new ones get a short slug.
    id: z.string().regex(/^([a-z]+:.+|[a-z0-9]+(-[a-z0-9]+)*)$/),
    kind: z.enum(v.kinds),
    status: z.enum(statuses),
    order: z.int().nonnegative(),
    premium: z.boolean(),
    addedOn: z.iso.date().optional(),
    minutes: z.int().positive().optional(),
    icon: nonEmpty,
    accent: nonEmpty,
    tags: z.strictObject({
      needs: z.array(z.enum(v.needs)).min(1, 'every item needs at least one need'),
      dayParts: z.array(z.enum(v.dayParts)),
    }),
    text: z.partialRecord(z.enum(v.locales), text),
    body,
  });
  const course = z.strictObject({
    id: z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/),
    status: z.enum(statuses),
    order: z.int().nonnegative(),
    icon: nonEmpty,
    accent: nonEmpty,
    need: z.enum(v.needs),
    days: z.array(nonEmpty).min(1),
    text: z.partialRecord(
      z.enum(v.locales),
      z.strictObject({
        title: nonEmpty,
        blurb: nonEmpty,
        notes: z.array(nonEmpty),
        reviewed: z.boolean().optional(),
      }),
    ),
  });
  return { item, course };
}

export type Item = z.infer<ReturnType<typeof schemas>['item']>;
export type Course = z.infer<ReturnType<typeof schemas>['course']>;

export type Checked = { items: Item[]; courses: Course[]; errors: string[] };

const hexAccent = /^#[0-9A-F]{8}$/;

export function check(
  loaded: Loaded,
  fileExists: (path: string) => boolean = (p) => existsSync(join(repoRoot, p)),
): Checked {
  const { vocab, icons } = loaded;
  const { item: itemSchema, course: courseSchema } = schemas(vocab);
  const errors: string[] = [];
  const items: Item[] = [];
  const courses: Course[] = [];
  const fail = (path: string, msg: string) => errors.push(`${path}: ${msg}`);

  const parseAll = <T>(
    files: [string, unknown][],
    schema: z.ZodType<T>,
    out: T[],
    paths: Map<T, string>,
  ) => {
    for (const [path, data] of files) {
      const r = schema.safeParse(data);
      if (!r.success) {
        for (const issue of r.error.issues) {
          fail(path, `${issue.path.join('.') || '(root)'}: ${issue.message}`);
        }
      } else {
        out.push(r.data);
        paths.set(r.data, path);
      }
    }
  };
  const itemPaths = new Map<Item, string>();
  const coursePaths = new Map<Course, string>();
  parseAll(loaded.items, itemSchema, items, itemPaths);
  parseAll(loaded.courses, courseSchema, courses, coursePaths);

  const common = (path: string, x: { icon: string; accent: string; text: object }) => {
    if (!icons.has(x.icon)) {
      fail(path, `icon "${x.icon}" isn't in lib/content/content_icons.dart`);
    }
    if (!vocab.accents.includes(x.accent) && !hexAccent.test(x.accent)) {
      fail(path, `accent "${x.accent}" is neither a named accent nor #AARRGGBB`);
    }
    if (!('en' in x.text)) fail(path, 'text.en is required');
  };

  const byId = new Map<string, Item>();
  for (const item of items) {
    const path = itemPaths.get(item)!;
    const other = byId.get(item.id);
    if (other) fail(path, `id "${item.id}" is also used by ${itemPaths.get(other)}`);
    byId.set(item.id, item);
    common(path, item);

    const { body } = item;
    if (!bodiesFor[item.kind]?.includes(body.type)) {
      fail(path, `a ${item.kind} can't have a ${body.type} body`);
    }
    for (const [locale, t] of Object.entries(item.text)) {
      const where = `text.${locale}`;
      if (body.type === 'meditation') {
        if (t.prompts?.length !== body.promptAt.length) {
          fail(path, `${where}.prompts needs one line per promptAt (${body.promptAt.length})`);
        }
      } else if (t.prompts) {
        fail(path, `${where}.prompts only belongs on meditations`);
      }
      if (body.type === 'lesson' && !t.paragraphs?.length) {
        fail(path, `${where}.paragraphs is required for a lesson`);
      }
      if (body.type !== 'lesson' && t.paragraphs) {
        fail(path, `${where}.paragraphs only belongs on lessons`);
      }
      if (body.type === 'prompt' && t.seed === undefined) {
        fail(path, `${where}.seed is required for a journal prompt`);
      }
    }
    if (body.type === 'meditation') {
      const at = body.promptAt;
      if (at.some((x, i) => i > 0 && x <= at[i - 1])) {
        fail(path, 'body.promptAt must go up');
      }
      if (body.narration && !fileExists(body.narration)) {
        fail(path, `narration file ${body.narration} doesn't exist`);
      }
    }
    if (body.type === 'sound' && !fileExists(body.audio)) {
      fail(path, `audio file ${body.audio} doesn't exist`);
    }
  }

  const courseIds = new Set<string>();
  for (const course of courses) {
    const path = coursePaths.get(course)!;
    if (courseIds.has(course.id)) fail(path, `course id "${course.id}" is used twice`);
    courseIds.add(course.id);
    common(path, course);
    for (const day of course.days) {
      const item = byId.get(day);
      if (!item) fail(path, `day "${day}" isn't an item`);
      else if (course.status === 'published' && item.status !== 'published') {
        fail(path, `day "${day}" is ${item.status}, so the course can't be published`);
      }
    }
    for (const [locale, t] of Object.entries(course.text)) {
      if (t.notes.length !== course.days.length) {
        fail(path, `text.${locale}.notes needs one note per day (${course.days.length})`);
      }
    }
  }

  return { items, courses, errors };
}
