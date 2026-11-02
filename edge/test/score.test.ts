/// <reference types="vite/client" />
import { describe, expect, it } from 'vitest';
import { parseSnapshot } from '../src/catalog';
import {
  isCalmingSafe, recommend, REASONS, TOP, type ScoreCatalog, type ScoreItem, type Signals,
} from '../src/recommend/score';
import bundled from '../../assets/catalog/bundled.json';
import catalogJson from './fixtures/recommendations/catalog.json';

// Shared fixtures: input -> exact expected output. A Dart port can run the
// same files.
const fixtures = import.meta.glob<{ description: string; signals: Signals; expected: unknown }>(
  './fixtures/recommendations/*.json',
  { eager: true, import: 'default' },
);
const fixture = catalogJson as ScoreCatalog;
const real = parseSnapshot(bundled, 0, 'catalog/bundled.json').scoring;

const NIGHT = { now: '2026-11-02T18:30:00Z', localTime: '2026-11-02T21:30' };
const AWFUL = { lastMood: 0, lastMoodAt: '2026-11-02T18:00:00Z' };
const LOW = { lastMood: 1, lastMoodAt: '2026-11-02T17:45:00Z' };

const ids = (r: { items: { id: string }[] }) => r.items.map((x) => x.id);
const byId = (c: ScoreCatalog) => new Map(c.items.map((i) => [i.id, i]));

function itemsOf(c: ScoreCatalog, s: Signals): ScoreItem[] {
  const map = byId(c);
  return recommend(c, s).items.map((x) => map.get(x.id)!);
}

describe('fixtures', () => {
  const cases = Object.entries(fixtures).filter(([path]) => !path.endsWith('/catalog.json'));

  it('has cases', () => expect(cases.length).toBeGreaterThanOrEqual(10));

  for (const [path, c] of cases) {
    it(`${path.split('/').pop()}: ${c.description}`, () => {
      expect(recommend(fixture, c.signals)).toEqual(c.expected);
    });
  }
});

describe('safety (design §5, §9)', () => {
  for (const [name, catalog] of [['fixture', fixture], ['bundled', real]] as const) {
    for (const [mood, signals] of [['awful', AWFUL], ['low', LOW]] as const) {
      for (const premium of [false, true]) {
        const s: Signals = { ...NIGHT, ...signals, premium, limit: 20 };
        const label = `${name}, ${mood}, ${premium ? 'premium' : 'free'}`;

        it(`${label}: the first item is a panic or grounding item`, () => {
          const first = itemsOf(catalog, s)[0];
          expect(first.calmingSafe).toBe(true);
          expect(first.needs).toContain('panic');
          expect(recommend(catalog, s).items[0].reason).toBe(REASONS.lead);
        });

        it(`${label}: only calmingSafe items, nothing deep or for feeling good`, () => {
          const items = itemsOf(catalog, s);
          expect(items.length).toBeGreaterThan(0);
          for (const item of items) {
            expect(isCalmingSafe(item), item.id).toBe(true);
            expect(item.intensity, item.id).not.toBe('deep');
            if (!item.support) expect(item.needs, item.id).not.toContain('good');
          }
        });
      }
    }
  }

  it('a free user is led by a free grounding item when there is one', () => {
    const first = itemsOf(fixture, { ...NIGHT, ...AWFUL, premium: false })[0];
    expect(first.premium).toBe(false);
    const firstReal = itemsOf(real, { ...NIGHT, ...AWFUL, premium: false })[0];
    expect(firstReal.premium).toBe(false);
  });

  it('support items come straight after the lead', () => {
    const r = recommend(fixture, { ...NIGHT, ...AWFUL, premium: true });
    expect(r.items[1]).toEqual({ id: 'support-crisis-lines', reason: REASONS.support });
  });

  it('the rules lapse 2 hours after the check-in', () => {
    const at = (h: number) => new Date(Date.parse(NIGHT.now) - h * 3_600_000).toISOString();
    const safe = itemsOf(fixture, { ...NIGHT, lastMood: 0, lastMoodAt: at(1.9), premium: true });
    expect(safe.every(isCalmingSafe)).toBe(true);
    const later = itemsOf(fixture, { ...NIGHT, lastMood: 0, lastMoodAt: at(2.1), premium: true, limit: 20 });
    expect(later.every(isCalmingSafe)).toBe(false);
  });

  it('a mood with no time counts as recent; okay or better never triggers', () => {
    expect(itemsOf(fixture, { ...NIGHT, lastMood: 1, premium: true }).every(isCalmingSafe)).toBe(true);
    const okay = itemsOf(fixture, { ...NIGHT, lastMood: 2, lastMoodAt: AWFUL.lastMoodAt, premium: true, limit: 20 });
    expect(okay.every(isCalmingSafe)).toBe(false);
  });

  it('a course day that is not calmingSafe is skipped in safe mode', () => {
    const r = recommend(fixture, { ...NIGHT, ...AWFUL, premium: true, course: { id: 'anxiety7', day: 2 }, limit: 20 });
    expect(ids(r)).not.toContain('tool:Thought record');
  });
});

describe('crisis and support items', () => {
  const lockedSupport: ScoreCatalog = {
    ...fixture,
    items: fixture.items.map((i) => (i.support ? { ...i, premium: true } : i)),
  };

  it('are never locked: they never take a premium slot from a free user', () => {
    // Even mislabelled premium, the support item doesn't count towards the cap.
    const items = itemsOf(lockedSupport, { ...NIGHT, ...AWFUL, premium: false });
    const locked = items.filter((i) => i.premium && !i.support);
    expect(locked.length).toBeLessThanOrEqual(2);
    expect(items.some((i) => i.support)).toBe(true);
  });

  it('every support item in the content is free', () => {
    for (const item of real.items.filter((i) => i.support)) expect(item.premium, item.id).toBe(false);
  });

  it('are never ranked down by "felt worse" or "done recently"', () => {
    const base: Signals = { ...NIGHT, premium: true, goals: ['low'], limit: 20 };
    const plain = ids(recommend(fixture, base)).indexOf('support-crisis-lines');
    const penalised = ids(
      recommend(fixture, {
        ...base,
        feelings: [{ id: 'support-crisis-lines', feeling: -1, at: '2026-11-02T10:00:00Z' }],
        sessions: [{ id: 'support-crisis-lines', at: '2026-11-02T18:00:00Z' }],
      }),
    ).indexOf('support-crisis-lines');
    // Its own penalties are skipped; others sharing its needs may drop.
    expect(plain).toBeGreaterThanOrEqual(0);
    expect(penalised).toBeLessThanOrEqual(plain);
  });
});

describe('caps on the top 6', () => {
  const signalSets: Signals[] = [
    { ...NIGHT, premium: true },
    { ...NIGHT, premium: false, goals: ['sleep', 'anxious'] },
    { now: '2026-11-02T05:00:00Z', localTime: '2026-11-02T08:00', premium: true, goals: ['stressed', 'low'], opensByKind: { meditation: 9 } },
    { ...NIGHT, premium: false, goals: ['sleep'], popularity: { 'sound:Rainfall': 50, 'sound:Pink noise': 40, 'sound:Fireside': 30 } },
    { ...NIGHT, ...AWFUL, premium: false },
  ];

  for (const [name, catalog] of [['fixture', fixture], ['bundled', real]] as const) {
    signalSets.forEach((s, n) => {
      const top = itemsOf(catalog, { ...s, limit: 12 }).slice(0, TOP);

      it(`${name} #${n}: at most 2 of one kind`, () => {
        const counts = new Map<string, number>();
        for (const i of top.filter((i) => !i.support)) counts.set(i.kind, (counts.get(i.kind) ?? 0) + 1);
        for (const [kind, count] of counts) expect(count, kind).toBeLessThanOrEqual(2);
      });

      it(`${name} #${n}: at most 1 from one course`, () => {
        for (const course of catalog.courses) {
          expect(top.filter((i) => course.days.includes(i.id)).length, course.id).toBeLessThanOrEqual(1);
        }
      });

      if (!s.premium) {
        it(`${name} #${n}: a free user sees at most 2 premium items`, () => {
          expect(top.filter((i) => i.premium && !i.support).length).toBeLessThanOrEqual(2);
        });
      }
    });
  }

  it('a premium user has no premium cap', () => {
    const top = itemsOf(fixture, { ...NIGHT, premium: true, goals: ['sleep', 'anxious'] });
    expect(top.filter((i) => i.premium).length).toBeGreaterThan(2);
  });

  it('items held back by a cap can follow the top 6', () => {
    const r = itemsOf(fixture, { ...NIGHT, premium: false, goals: ['sleep', 'anxious'], limit: 12 });
    expect(r.length).toBe(12);
    expect(r.slice(TOP).filter((i) => i.premium).length).toBeGreaterThan(0);
  });
});

describe('scoring', () => {
  it('puts the course in progress first, with its day', () => {
    const r = recommend(fixture, { ...NIGHT, premium: true, course: { id: 'sleep7', day: 1 } });
    expect(r.items[0]).toEqual({ id: 'meditation:Body scan', reason: 'Day 2 of 7 days to better sleep' });
  });

  it('ignores an unknown course or a day out of range', () => {
    const plain = recommend(fixture, { ...NIGHT, premium: true });
    expect(recommend(fixture, { ...NIGHT, premium: true, course: { id: 'nope', day: 0 } })).toEqual(plain);
    expect(recommend(fixture, { ...NIGHT, premium: true, course: { id: 'sleep7', day: 9 } })).toEqual(plain);
  });

  it('names the item that felt better', () => {
    const r = recommend(fixture, {
      ...NIGHT,
      premium: true,
      feelings: [{ id: 'tool:Physiological sigh', feeling: 1, at: '2026-11-01T10:00:00Z' }],
      limit: 20,
    });
    expect(r.items.find((x) => x.id === 'breathing:Box breathing')?.reason).toBe(
      'Because you felt better after Physiological sigh',
    );
  });

  it('ignores feelings older than 90 days', () => {
    const plain = recommend(fixture, { ...NIGHT, premium: true });
    const old = recommend(fixture, {
      ...NIGHT,
      premium: true,
      feelings: [{ id: 'tool:Physiological sigh', feeling: 1, at: '2026-07-01T10:00:00Z' }],
    });
    expect(old).toEqual(plain);
  });

  it('ranks down what was finished in the last 24 hours', () => {
    const s: Signals = { ...NIGHT, premium: true, limit: 20 };
    const before = ids(recommend(fixture, s)).indexOf('meditation:Sleep wind-down');
    const after = ids(
      recommend(fixture, { ...s, sessions: [{ id: 'meditation:Sleep wind-down', at: '2026-11-02T12:00:00Z' }] }),
    ).indexOf('meditation:Sleep wind-down');
    expect(after).toBeGreaterThan(before);
  });

  it('is deterministic, and the shuffle changes by the day', () => {
    const s: Signals = { ...NIGHT, premium: true, limit: 20 };
    expect(recommend(real, s)).toEqual(recommend(real, s));
    const tomorrow = recommend(real, { ...s, localTime: '2026-11-03T21:30', now: '2026-11-03T18:30:00Z' });
    expect(ids(tomorrow)).not.toEqual(ids(recommend(real, s)));
  });

  it('respects the limit', () => {
    expect(recommend(real, { ...NIGHT, premium: true, limit: 3 }).items).toHaveLength(3);
    expect(recommend(real, { ...NIGHT, premium: true, limit: 99 }).items).toHaveLength(20);
    expect(recommend(real, { ...NIGHT, premium: true }).items).toHaveLength(6);
  });

  it('every reason is a non-empty line', () => {
    for (const r of [
      recommend(real, { ...NIGHT, premium: false, limit: 20 }),
      recommend(real, { ...NIGHT, ...AWFUL, premium: false, limit: 20 }),
    ]) {
      for (const x of r.items) expect(x.reason.length).toBeGreaterThan(0);
    }
  });
});
