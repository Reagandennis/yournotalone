// Drafts the missing translations of an item, course or background with
// Claude and writes them into its YAML under `text.<locale>` with
// `reviewed: false`. Nothing it writes is reviewed: a fluent person reads
// it and flips the flag (design §7a, content/README.md). A locale that
// already has text is never overwritten.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { load, repoRoot } from './content.ts';

export const model = 'claude-opus-5-5';
const endpoint = 'https://api.anthropic.com/v1/messages';

/// How each language speaks to the person, matching the app's UI strings
/// (lib/l10n/README.md), and the terms those strings already use.
const languages: Record<string, { name: string; style: string }> = {
  fr: {
    name: 'French',
    style:
      'Use "tu", never "vous". Terms: respiration, méditation, bilan (check-in), journal, ' +
      'TCC (CBT), pièges de pensée, sommeil, stress. French spacing before ; : ! ? and « » quotes.',
  },
  de: {
    name: 'German',
    style:
      'Use "du", never "Sie". Terms: Atmung, Meditation, Check-in, Tagebuch, KVT (CBT), ' +
      'Denkfallen, Schlaf, Stress. Keep titles short; German quotes „…“.',
  },
  es: {
    name: 'Spanish (neutral, international)',
    style:
      'Use "tú", never "usted", "vos" or "vosotros"; avoid words only one country uses. ' +
      'Terms: respiración, meditación, registro (check-in), diario, TCC (CBT), trampas de pensamiento.',
  },
  'zh-Hans': {
    name: 'Simplified Chinese',
    style:
      'Use 你, never 您. Natural for readers in Singapore and Malaysia as well as the mainland. ' +
      'Terms: 呼吸, 冥想, 打卡/签到 as the app uses for check-in, 日记, CBT, 思维陷阱. Full-width punctuation.',
  },
};

const system = `You translate the content of "You're not alone", a mental-wellness app: \
breathing exercises, meditations, sounds, journal prompts, CBT, sleep and stress lessons, \
recovery tools and short courses. The reader may be anxious, low or not sleeping.

Write the way a kind, plain-spoken friend who knows the subject would: warm, calm, \
never clinical, never alarming, never preachy. Keep the English meaning, length and \
rhythm; a title stays a short title. Use the standard, everyday terms for CBT ideas in \
the target language, not literal calques. Keep numbers, timings and the " · " separators \
as they are. Translate every string; an empty string stays empty.

Return only the JSON object, with exactly the same keys, and every list with exactly \
as many lines, in the same order, as the English.`;

type Text = Record<string, unknown>;

/// The JSON schema of [en]'s fields, so the reply has exactly that shape.
function schemaFor(en: Text) {
  const properties: Record<string, object> = {};
  for (const [k, v] of Object.entries(en)) {
    properties[k] = Array.isArray(v)
      ? { type: 'array', items: { type: 'string' } }
      : { type: 'string' };
  }
  return {
    type: 'object',
    properties,
    required: Object.keys(en),
    additionalProperties: false,
  };
}

/// Throws unless [t] has [en]'s keys, list lengths and non-empty strings
/// where English has text.
export function assertSameShape(en: Text, t: unknown): asserts t is Text {
  if (typeof t !== 'object' || t === null) throw new Error('reply is not an object');
  const keys = (o: object) => Object.keys(o).sort().join(', ');
  if (keys(t) !== keys(en)) throw new Error(`reply has [${keys(t)}], expected [${keys(en)}]`);
  for (const [k, v] of Object.entries(en)) {
    const got = (t as Text)[k];
    if (Array.isArray(v)) {
      if (!Array.isArray(got) || got.length !== v.length) {
        throw new Error(`${k} should have ${v.length} lines`);
      }
      got.forEach((line, i) => {
        if (typeof line !== 'string' || !line.trim()) throw new Error(`${k}[${i}] is empty`);
      });
    } else if (typeof got !== 'string' || (v !== '' && !got.trim())) {
      throw new Error(`${k} is empty`);
    }
  }
}

/// One locale's draft of [en], from Claude.
export async function draft(
  en: Text,
  locale: string,
  { apiKey, fetch: doFetch = fetch }: { apiKey: string; fetch?: typeof fetch },
): Promise<Text> {
  const language = languages[locale];
  if (!language) throw new Error(`no language settings for ${locale}`);
  const res = await doFetch(endpoint, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2026-10-21',
      // If the model declines, Anthropic's recommended fallback answers.
      'anthropic-beta': 'server-side-fallback-2026-07-01',
    },
    body: JSON.stringify({
      model,
      max_tokens: 16000,
      fallbacks: 'default',
      output_config: {
        effort: 'high',
        format: { type: 'json_schema', schema: schemaFor(en) },
      },
      system: `${system}\n\nTarget language: ${language.name}. ${language.style}`,
      messages: [{ role: 'user', content: JSON.stringify(en, null, 2) }],
    }),
  });
  if (!res.ok) {
    throw new Error(`Claude API ${res.status}: ${(await res.text()).slice(0, 500)}`);
  }
  const reply = (await res.json()) as {
    stop_reason?: string;
    content?: { type: string; text?: string }[];
  };
  if (reply.stop_reason !== 'end_turn') {
    throw new Error(`Claude stopped with ${reply.stop_reason}; nothing written`);
  }
  const text = reply.content?.find((b) => b.type === 'text')?.text;
  if (!text) throw new Error('Claude returned no text');
  const t: unknown = JSON.parse(text);
  assertSameShape(en, t);
  return t;
}

// ── Writing it into the YAML ──────────────────────────────────────────
// Strings are double-quoted JSON, which is valid YAML and keeps every
// quote, dash and accent intact — the same style as the Dart export, which
// copies these lines across when it rewrites a file.

/// `text.<locale>` as YAML lines, two spaces in, ending `reviewed: false`.
export function localeBlock(locale: string, t: Text): string {
  const lines = [`  ${locale}:`];
  for (const [k, v] of Object.entries(t)) {
    if (Array.isArray(v)) {
      lines.push(`    ${k}:`, ...v.map((line) => `      - ${JSON.stringify(line)}`));
    } else {
      lines.push(`    ${k}: ${JSON.stringify(v)}`);
    }
  }
  lines.push('    reviewed: false');
  return lines.join('\n') + '\n';
}

/// [yaml] with [block] added at the end of its top-level `text:` map.
export function insertLocale(yaml: string, block: string): string {
  const lines = yaml.split('\n');
  const start = lines.indexOf('text:');
  if (start < 0) throw new Error('no top-level text: map');
  let end = start + 1;
  while (end < lines.length && (lines[end].startsWith(' ') || lines[end] === '')) end++;
  // Keep trailing blank lines (or the final newline) after the block.
  while (end > start + 1 && lines[end - 1] === '') end--;
  return [...lines.slice(0, end), ...block.trimEnd().split('\n'), ...lines.slice(end)].join('\n');
}

export type Job = { path: string; id: string; locale: string; en: Text };

/// What's missing: each file matching [target] (an id, or every file for
/// `--all`) and each of [locales] it has no text for, in vocab order.
export function missing(root: string, target: string, locales: string[]): Job[] {
  const loaded = load(root);
  const files = [...loaded.items, ...loaded.courses, ...loaded.backgrounds] as [
    string,
    { id: string; text: Record<string, Text> },
  ][];
  const wanted = files.filter(([, d]) => target === '--all' || d.id === target);
  if (!wanted.length) throw new Error(`nothing in content/ has the id "${target}"`);
  const ordered = loaded.vocab.locales.filter((l) => locales.includes(l));
  return wanted.flatMap(([path, d]) =>
    ordered
      .filter((l) => !(l in d.text))
      .map((locale) => ({ path, id: d.id, locale, en: d.text.en })),
  );
}

export async function translate(opts: {
  root?: string;
  target: string;
  locales: string[];
  apiKey?: string;
  dryRun?: boolean;
  fetch?: typeof fetch;
  log?: (line: string) => void;
}): Promise<Job[]> {
  const { root = repoRoot, target, locales, dryRun = false, log = console.log } = opts;
  for (const l of locales) {
    if (!languages[l]) throw new Error(`can't translate to "${l}": use ${Object.keys(languages).join(', ')}`);
  }
  const jobs = missing(root, target, locales);
  if (!dryRun && jobs.length && !opts.apiKey) {
    throw new Error('ANTHROPIC_API_KEY is not set');
  }
  for (const job of jobs) {
    if (dryRun) {
      log(`would draft ${job.locale} for ${job.id} (${job.path})`);
      continue;
    }
    const t = await draft(job.en, job.locale, { apiKey: opts.apiKey!, fetch: opts.fetch });
    // Written one at a time, so a failure part-way keeps what's done.
    const file = join(root, job.path);
    writeFileSync(file, insertLocale(readFileSync(file, 'utf8'), localeBlock(job.locale, t)));
    log(`drafted ${job.locale} for ${job.id}`);
  }
  if (!jobs.length) log('Nothing to translate: every locale asked for is there.');
  return jobs;
}
