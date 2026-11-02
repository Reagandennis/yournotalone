import assert from 'node:assert/strict';
import { test } from 'node:test';
import { check, load } from './content.ts';
import { snapshot } from './snapshot.ts';

const base = load();
const box = base.items.find(([p]) => p.endsWith('box-breathing.yaml'))!;
const bodyScan = base.items.find(([p]) => p.endsWith('body-scan.yaml'))!;

/// The repo's content with one item swapped for an edited copy.
function withItem(path: string, edit: (item: any) => void) {
  const items = base.items.map(([p, data]): [string, unknown] => {
    if (p !== path) return [p, data];
    const copy = structuredClone(data);
    edit(copy);
    return [p, copy];
  });
  return check({ ...base, items });
}

test('the repo content is valid', () => {
  assert.deepEqual(check(base).errors, []);
});

test('rejects tags outside the vocabulary', () => {
  const { errors } = withItem(box[0], (i) => i.tags.needs.push('happy'));
  assert.match(errors.join('\n'), /tags\.needs/);
});

test('rejects an item with no needs', () => {
  const { errors } = withItem(box[0], (i) => (i.tags.needs = []));
  assert.match(errors.join('\n'), /at least one need/);
});

test('a calmingSafe item is never deep or for feeling good', () => {
  const deep = withItem(box[0], (i) => (i.tags.intensity = 'deep'));
  assert.match(deep.errors.join('\n'), /calmingSafe item can't be deep/);
  const good = withItem(box[0], (i) => i.tags.needs.push('good'));
  assert.match(good.errors.join('\n'), /calmingSafe item can't be for feeling good/);
});

test('rejects an intensity outside the vocabulary', () => {
  const { errors } = withItem(bodyScan[0], (i) => (i.tags.intensity = 'extreme'));
  assert.match(errors.join('\n'), /tags\.intensity/);
});

test('support items are always free', () => {
  const { errors } = withItem(bodyScan[0], (i) => (i.tags.support = true));
  assert.match(errors.join('\n'), /support items are always free/);
});

test('rejects an icon the app does not know', () => {
  const { errors } = withItem(box[0], (i) => (i.icon = 'not_an_icon'));
  assert.match(errors.join('\n'), /content_icons\.dart/);
});

test('rejects a duplicate id', () => {
  const { errors } = withItem(bodyScan[0], (i) => (i.id = 'breathing:Box breathing'));
  assert.match(errors.join('\n'), /also used by/);
});

test('needs one prompt line per timing, in every locale', () => {
  const { errors } = withItem(bodyScan[0], (i) => {
    i.text.fr = { ...i.text.en, prompts: i.text.en.prompts.slice(1) };
  });
  assert.match(errors.join('\n'), /text\.fr\.prompts/);
});

test('rejects a body that does not suit the kind', () => {
  const { errors } = withItem(box[0], (i) => (i.body = { type: 'lesson', art: 'moon' }));
  assert.match(errors.join('\n'), /can't have a lesson body/);
});

test('a course day must be a published item', () => {
  const { errors } = withItem(box[0], (i) => (i.status = 'draft'));
  // Box breathing isn't in a course, so only the 4-7-8 one is checked here.
  assert.deepEqual(errors, []);
  const sleep = base.items.find(([p]) => p.endsWith('4-7-8-calm.yaml'))!;
  const r = withItem(sleep[0], (i) => (i.status = 'draft'));
  assert.match(r.errors.join('\n'), /is draft, so the course can't be published/);
});

test('publishes only reviewed translations, without the flag', () => {
  const r = withItem(box[0], (i) => {
    i.text.fr = { title: 'Respiration carrée', blurb: 'x', reviewed: true };
    i.text.de = { title: 'Box-Atmung', blurb: 'x' };
  });
  const snap = snapshot(r, 0);
  const item = snap.items.find((x) => x.id === 'breathing:Box breathing')!;
  assert.deepEqual(Object.keys(item.text).sort(), ['en', 'fr']);
  assert.equal('reviewed' in item.text.fr!, false);
});

test('leaves drafts out of the snapshot', () => {
  const r = withItem(box[0], (i) => (i.status = 'draft'));
  const snap = snapshot(r, 0);
  assert.equal(snap.items.some((x) => x.id === 'breathing:Box breathing'), false);
});

const waves = base.backgrounds.find(([p]) => p.endsWith('dusk-waves.yaml'))!;

/// The repo's content with one background swapped for an edited copy.
function withBackground(path: string, edit: (bg: any) => void) {
  const backgrounds = base.backgrounds.map(([p, data]): [string, unknown] => {
    if (p !== path) return [p, data];
    const copy = structuredClone(data);
    edit(copy);
    return [p, copy];
  });
  return check({ ...base, backgrounds });
}

test('rejects an engine the app cannot draw', () => {
  const { errors } = withBackground(waves[0], (b) => (b.engine = 'lava'));
  assert.match(errors.join('\n'), /dusk-waves\.yaml: engine/);
});

test('palettes are two to six #RRGGBB colours', () => {
  let r = withBackground(waves[0], (b) => (b.params.palette = ['#3764cd', '#1A2238']));
  assert.match(r.errors.join('\n'), /#RRGGBB/);
  r = withBackground(waves[0], (b) => (b.params.palette = ['#3764CD']));
  assert.match(r.errors.join('\n'), /params\.palette/);
});

test('an item can only prefer a background that exists', () => {
  let r = withItem(box[0], (i) => (i.background = 'dusk-waves'));
  assert.deepEqual(r.errors, []);
  r = withItem(box[0], (i) => (i.background = 'no-such-scene'));
  assert.match(r.errors.join('\n'), /isn't in content\/backgrounds/);
});

test('a published item cannot prefer a draft background', () => {
  const backgrounds = base.backgrounds.map(([p, data]): [string, unknown] =>
    p === waves[0] ? [p, { ...(data as object), status: 'draft' }] : [p, data],
  );
  const items = base.items.map(([p, data]): [string, unknown] =>
    p === box[0] ? [p, { ...(data as object), background: 'dusk-waves' }] : [p, data],
  );
  const { errors } = check({ ...base, items, backgrounds });
  assert.match(errors.join('\n'), /background "dusk-waves" is draft/);
});

test('each kind has at most one default background', () => {
  const { errors } = withBackground(waves[0], (b) => (b.defaultFor = ['sound', 'breathing']));
  assert.match(errors.join('\n'), /breathing already defaults to dusk-waves/);
});

test('the snapshot carries published backgrounds and item preferences', () => {
  const r = withBackground(waves[0], (b) => {
    b.text.fr = { title: 'Vagues', reviewed: false };
  });
  const snap = snapshot(r, 0);
  const bg = snap.backgrounds.find((b) => b.id === 'dusk-waves')!;
  assert.equal('status' in bg, false);
  assert.deepEqual(Object.keys(bg.text), ['en']);
  assert.equal(bg.engine, 'waves');
  const crickets = snap.items.find((i) => i.id === 'sound:Crickets at night')!;
  assert.equal(crickets.background, 'fireflies');

  const drafted = withBackground(waves[0], (b) => (b.status = 'draft'));
  // Ocean breath prefers it, so drafting it is an error; the snapshot
  // still leaves it out.
  assert.match(drafted.errors.join('\n'), /ocean-breath\.yaml: background "dusk-waves" is draft/);
  assert.equal(snapshot(drafted, 0).backgrounds.some((b) => b.id === 'dusk-waves'), false);
});
