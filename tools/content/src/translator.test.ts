import assert from 'node:assert/strict';
import { cpSync, mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { parse } from 'yaml';
import { check, load, repoRoot } from './content.ts';
import { snapshot } from './snapshot.ts';
import { insertLocale, localeBlock, model, translate } from './translator.ts';

/// A copy of the repo's content to write into.
function sandbox(): string {
  const root = mkdtempSync(join(tmpdir(), 'content-'));
  cpSync(join(repoRoot, 'content'), join(root, 'content'), { recursive: true });
  cpSync(
    join(repoRoot, 'lib/content/content_icons.dart'),
    join(root, 'lib/content/content_icons.dart'),
  );
  return root;
}

/// Stands in for the Claude API: answers each request with [answer]'s
/// result for the English it was sent, and records the requests.
function mockFetch(answer: (en: Record<string, unknown>) => unknown, stop = 'end_turn') {
  const calls: { url: string; headers: Record<string, string>; body: any }[] = [];
  const fetch = (async (url: string, init: RequestInit) => {
    const body = JSON.parse(init.body as string);
    calls.push({ url, headers: init.headers as Record<string, string>, body });
    const en = JSON.parse(body.messages[0].content);
    return new Response(
      JSON.stringify({
        stop_reason: stop,
        content: [{ type: 'text', text: JSON.stringify(answer(en)) }],
      }),
    );
  }) as typeof globalThis.fetch;
  return { fetch, calls };
}

/// A fake translation: every string tagged with the locale.
const tagged = (locale: string) => (en: Record<string, unknown>) =>
  Object.fromEntries(
    Object.entries(en).map(([k, v]) => [
      k,
      Array.isArray(v) ? v.map((s) => `[${locale}] ${s}`) : v === '' ? '' : `[${locale}] ${v}`,
    ]),
  );

const id = 'meditation:Body scan';
const file = 'content/items/meditation/body-scan.yaml';

test('drafts each missing locale as unreviewed text the checker accepts', async () => {
  const root = sandbox();
  const { fetch, calls } = mockFetch((en) => tagged('xx')(en));
  const jobs = await translate({
    root,
    target: id,
    locales: ['de', 'fr'],
    apiKey: 'test-key',
    fetch,
    log: () => {},
  });
  assert.deepEqual(
    jobs.map((j) => j.locale),
    ['fr', 'de'],
    'in vocab order',
  );

  assert.equal(calls.length, 2);
  const [call] = calls;
  assert.equal(call.url, 'https://api.anthropic.com/v1/messages');
  assert.equal(call.headers['x-api-key'], 'test-key');
  assert.equal(call.headers['anthropic-version'], '2026-10-21');
  assert.equal(call.body.model, model);
  assert.equal(call.body.model, 'claude-opus-5-5');
  assert.equal(call.body.output_config.format.type, 'json_schema');
  assert.deepEqual(call.body.output_config.format.schema.required, ['title', 'blurb', 'prompts']);
  assert.match(call.body.system, /French/);
  assert.match(calls[1].body.system, /German/);

  const data = parse(readFileSync(join(root, file), 'utf8'));
  assert.equal(data.text.fr.reviewed, false);
  assert.equal(data.text.de.reviewed, false);
  assert.equal(data.text.fr.title, '[xx] Body scan');
  assert.equal(data.text.fr.prompts.length, data.text.en.prompts.length);
  // The rest of the file is untouched.
  assert.deepEqual(data.body, parse(readFileSync(join(repoRoot, file), 'utf8')).body);

  const checked = check(load(root), () => true);
  assert.deepEqual(checked.errors, []);
  const item = snapshot(checked, 0).items.find((i) => i.id === id)!;
  assert.equal(item.text.fr!.reviewed, false);
});

test('never overwrites a locale that is there', async () => {
  const root = sandbox();
  const { fetch } = mockFetch(tagged('fr'));
  await translate({ root, target: id, locales: ['fr'], apiKey: 'k', fetch, log: () => {} });
  const again = mockFetch(tagged('other'));
  const jobs = await translate({
    root,
    target: id,
    locales: ['fr'],
    apiKey: 'k',
    fetch: again.fetch,
    log: () => {},
  });
  assert.equal(jobs.length, 0);
  assert.equal(again.calls.length, 0);
  assert.equal(parse(readFileSync(join(root, file), 'utf8')).text.fr.title, '[fr] Body scan');
});

test('--all covers items, courses and backgrounds', async () => {
  const root = sandbox();
  const { fetch, calls } = mockFetch(tagged('es'));
  const jobs = await translate({
    root,
    target: '--all',
    locales: ['es'],
    dryRun: true,
    fetch,
    log: () => {},
  });
  assert.equal(calls.length, 0, 'a dry run calls nothing');
  const loaded = load(root);
  const all = loaded.items.length + loaded.courses.length + loaded.backgrounds.length;
  const without = [...loaded.items, ...loaded.courses, ...loaded.backgrounds].filter(
    ([, d]) => !('es' in (d as { text: object }).text),
  ).length;
  assert.equal(jobs.length, without);
  assert.ok(all >= without);
});

test('rejects a reply with the wrong shape, a refusal, or no key', async () => {
  const root = sandbox();
  const short = mockFetch((en) => ({ ...tagged('fr')(en), prompts: ['only one'] }));
  await assert.rejects(
    translate({ root, target: id, locales: ['fr'], apiKey: 'k', fetch: short.fetch, log: () => {} }),
    /prompts should have \d+ lines/,
  );
  const refused = mockFetch(tagged('fr'), 'refusal');
  await assert.rejects(
    translate({ root, target: id, locales: ['fr'], apiKey: 'k', fetch: refused.fetch, log: () => {} }),
    /stopped with refusal/,
  );
  await assert.rejects(
    translate({ root, target: id, locales: ['fr'], log: () => {} }),
    /ANTHROPIC_API_KEY/,
  );
  await assert.rejects(
    translate({ root, target: id, locales: ['it'], apiKey: 'k', log: () => {} }),
    /can't translate to "it"/,
  );
  // Nothing was written.
  assert.equal(
    readFileSync(join(root, file), 'utf8'),
    readFileSync(join(repoRoot, file), 'utf8'),
  );
});

test('adds the locale at the end of text:, keeping the rest in place', () => {
  const yaml = 'id: x\ntext:\n  en:\n    title: "A"\nbody:\n  type: lesson\n';
  const out = insertLocale(yaml, localeBlock('fr', { title: 'B « c »' }));
  assert.equal(
    out,
    'id: x\ntext:\n  en:\n    title: "A"\n  fr:\n    title: "B « c »"\n    reviewed: false\nbody:\n  type: lesson\n',
  );
  // Text last in the file (courses, backgrounds).
  const last = insertLocale('id: y\ntext:\n  en:\n    title: "A"\n', localeBlock('de', { title: 'B' }));
  assert.equal(last, 'id: y\ntext:\n  en:\n    title: "A"\n  de:\n    title: "B"\n    reviewed: false\n');
});
