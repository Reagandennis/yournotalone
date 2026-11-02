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
  const snap = snapshot(r.items, r.courses, 0);
  const item = snap.items.find((x) => x.id === 'breathing:Box breathing')!;
  assert.deepEqual(Object.keys(item.text).sort(), ['en', 'fr']);
  assert.equal('reviewed' in item.text.fr!, false);
});

test('leaves drafts out of the snapshot', () => {
  const r = withItem(box[0], (i) => (i.status = 'draft'));
  const snap = snapshot(r.items, r.courses, 0);
  assert.equal(snap.items.some((x) => x.id === 'breathing:Box breathing'), false);
});
