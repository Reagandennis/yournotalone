import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { check, load, mediaFile, mediaPathProblem } from './content.ts';
import { inRepoOrMasters } from './testing.ts';
import { snapshot } from './snapshot.ts';

const base = load();
const box = base.items.find(([p]) => p.endsWith('box-breathing.yaml'))!;
const bodyScan = base.items.find(([p]) => p.endsWith('body-scan.yaml'))!;
const awake = base.items.find(([p]) => p.endsWith('awake-at-3am.yaml'))!;

/// [i], a native tool, turned into a two-step guided exercise.
function guided(i: any) {
  i.body = { type: 'guided', steps: [{ timer: 60 }, { input: 'list', count: 3 }] };
  for (const t of Object.values(i.text) as any[]) {
    t.stepTitles = ['Breathe', 'Name three things'];
    t.steps = ['Slow your breathing for a minute.', 'Write three things you can do next.'];
  }
}

/// The repo's content with one item swapped for an edited copy.
function withItem(path: string, edit: (item: any) => void) {
  const items = base.items.map(([p, data]): [string, unknown] => {
    if (p !== path) return [p, data];
    const copy = structuredClone(data);
    edit(copy);
    return [p, copy];
  });
  return check({ ...base, items }, inRepoOrMasters);
}

test('the repo content is valid', () => {
  // Recordings listed in content/masters.json count as there (they're in R2).
  assert.deepEqual(check(base, inRepoOrMasters).errors, []);
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

test('a tool can be a guided exercise with one heading and line per step', () => {
  assert.deepEqual(withItem(awake[0], guided).errors, []);
  const short = withItem(awake[0], (i) => {
    guided(i);
    i.text.fr.steps.pop();
  });
  assert.match(short.errors.join('\n'), /text\.fr\.steps needs one line per step \(2\)/);
});

test('a guided step has a sane timer and list size', () => {
  const timer = withItem(awake[0], (i) => {
    guided(i);
    i.body.steps[0].timer = 2;
  });
  assert.match(timer.errors.join('\n'), /timer/);
  const input = withItem(awake[0], (i) => {
    guided(i);
    i.body.steps[1].input = 'drawing';
  });
  assert.match(input.errors.join('\n'), /input/);
});

test('step text only belongs on guided exercises', () => {
  const { errors } = withItem(box[0], (i) => (i.text.en.steps = ['Breathe']));
  assert.match(errors.join('\n'), /only belong on guided exercises/);
});

test('a course day must be a published item', () => {
  const { errors } = withItem(box[0], (i) => (i.status = 'draft'));
  // Box breathing isn't in a course, so only the 4-7-8 one is checked here.
  assert.deepEqual(errors, []);
  const sleep = base.items.find(([p]) => p.endsWith('4-7-8-calm.yaml'))!;
  const r = withItem(sleep[0], (i) => (i.status = 'draft'));
  assert.match(r.errors.join('\n'), /is draft, so the course can't be published/);
});

test('publishes every translation with its review flag, English without one', () => {
  const r = withItem(box[0], (i) => {
    i.text = { en: i.text.en };
    i.text.fr = { ...i.text.en, title: 'Respiration carrée', reviewed: true };
    i.text.de = { ...i.text.en, title: 'Box-Atmung' };
  });
  assert.deepEqual(r.errors, []);
  const snap = snapshot(r, 0);
  const item = snap.items.find((x) => x.id === 'breathing:Box breathing')!;
  assert.deepEqual(Object.keys(item.text).sort(), ['de', 'en', 'fr']);
  assert.equal(item.text.fr!.reviewed, true);
  // Missing means not reviewed.
  assert.equal(item.text.de!.reviewed, false);
  assert.equal('reviewed' in item.text.en!, false);
});

test('a translation has the fields and line counts English has', () => {
  let r = withItem(box[0], (i) => (i.text.fr = { title: 'Respiration carrée', blurb: 'x' }));
  assert.match(r.errors.join('\n'), /text\.fr has fields \[blurb, title\], English has \[area, blurb, title\]/);
  const lesson = base.items.find(([p]) => p.includes('/lesson/'))!;
  r = withItem(lesson[0], (i) => {
    i.text.de = { ...i.text.en, paragraphs: i.text.en.paragraphs.slice(1), reviewed: false };
  });
  assert.match(r.errors.join('\n'), /text\.de\.paragraphs has \d+ lines/);
  r = withItem(box[0], (i) => (i.text.en.reviewed = true));
  assert.match(r.errors.join('\n'), /English is the source/);
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
  return check({ ...base, backgrounds }, inRepoOrMasters);
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
  const { errors } = check({ ...base, items, backgrounds }, inRepoOrMasters);
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
  assert.deepEqual(bg.text.fr, { title: 'Vagues', reviewed: false });
  assert.equal(bg.engine, 'waves');
  const crickets = snap.items.find((i) => i.id === 'sound:Crickets at night')!;
  assert.equal(crickets.background, 'fireflies');

  const drafted = withBackground(waves[0], (b) => (b.status = 'draft'));
  // Ocean breath prefers it, so drafting it is an error; the snapshot
  // still leaves it out.
  assert.match(drafted.errors.join('\n'), /ocean-breath\.yaml: background "dusk-waves" is draft/);
  assert.equal(snapshot(drafted, 0).backgrounds.some((b) => b.id === 'dusk-waves'), false);
});

test('audio paths stay inside the repo, under assets/ or Sounds/', () => {
  const rain = base.items.find(([p]) => p.endsWith('rainfall.yaml'))!;
  for (const bad of [
    '../../../etc/passwd',
    '/etc/passwd',
    'assets/../../secrets.wav',
    'assets/./sounds/rainfall.m4a',
    'tools/content/package.json',
    'Sounds/sub/take.wav',
    'Sounds\\take.wav',
    'C:/take.wav',
  ]) {
    const { errors } = withItem(rain[0], (i) => (i.body.audio = bad));
    assert.match(errors.join('\n'), /body\.audio .* (must|can't)/, bad);
    assert.equal(errors.some((e) => e.includes("doesn't exist")), false, `${bad}: not looked up`);
    assert.throws(() => mediaFile(bad), /audio path/);
  }
  const { errors } = withItem(bodyScan[0], (i) => (i.body.narration = '../narration.wav'));
  assert.match(errors.join('\n'), /body\.narration "\.\.\/narration\.wav" can't contain '\.\.'/);

  // What the content uses is fine.
  assert.equal(mediaPathProblem('assets/sounds/rainfall.m4a'), null);
  assert.equal(mediaPathProblem('Sounds/brown noise.wav'), null);
  assert.match(mediaFile('Sounds/brown noise.wav'), /\/Sounds\/brown noise\.wav$/);
});

test('an audio path that links outside the repo is refused', () => {
  const root = mkdtempSync(join(tmpdir(), 'content-root-'));
  const elsewhere = mkdtempSync(join(tmpdir(), 'content-elsewhere-'));
  try {
    writeFileSync(join(elsewhere, 'secret.wav'), 'not audio');
    mkdirSync(join(root, 'Sounds'));
    symlinkSync(join(elsewhere, 'secret.wav'), join(root, 'Sounds', 'take.wav'));
    writeFileSync(join(root, 'Sounds', 'real.wav'), 'audio');
    assert.throws(() => mediaFile('Sounds/take.wav', root), /outside the repo/);
    assert.equal(mediaFile('Sounds/real.wav', root), join(root, 'Sounds', 'real.wav'));
    assert.equal(mediaFile('Sounds/missing.wav', root), join(root, 'Sounds', 'missing.wav'));
  } finally {
    rmSync(root, { recursive: true, force: true });
    rmSync(elsewhere, { recursive: true, force: true });
  }
});

test('a recording that is only in R2 says how to fetch it', () => {
  const rain = base.items.find(([p]) => p.endsWith('rainfall.yaml'))!;
  const items = base.items.map(([p, d]): [string, unknown] => {
    if (p !== rain[0]) return [p, d];
    const c: any = structuredClone(d);
    c.body.audio = 'Sounds/brown noise.wav';
    return [p, c];
  });
  const { errors } = check({ ...base, items }, () => false);
  assert.match(errors.join('\n'), /Sounds\/brown noise\.wav doesn't exist here; it's in content\/masters\.json/);
});
