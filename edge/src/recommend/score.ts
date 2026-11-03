// Recommendation scoring, v1 (design §5). Pure and deterministic: the same
// catalogue and signals always give the same list, so the shared fixtures
// in test/fixtures/recommendations/ can check a Dart port later. No I/O,
// no clock: `now` and `localTime` come in with the signals.
//
// Order of work:
//   1. Safety. After an awful or low check-in in the last 2 hours, only
//      calmingSafe (or support) items are allowed, never a deep one or one
//      for feeling good, and the list leads with a panic/grounding item and
//      the support items.
//   2. The next day of the course in progress.
//   3. Everything else by score (TERMS below).
//   4. Caps on the top 6: at most 2 of one kind, at most 2 from one
//      course (only the day to continue from the course in progress), and
//      for a free user at most 2 premium items.
//
// Every suggestion carries a reason twice: an English line (`reason`, for
// older apps) and a code with arguments (`reasonKey`, `reasonArgs`) that
// the app turns into its own language. Arguments are ids, never English:
// the app looks titles up in its catalogue.
//
// Support items (crisis content) are always free, skip the caps and never
// get a negative term.

export const RULES = 'v1';

/** The window the diversity and premium caps apply to. */
export const TOP = 6;
export const DEFAULT_LIMIT = 6;
export const MAX_LIMIT = 20;

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const SAFE_WINDOW = 2 * HOUR;
const RECENT_WINDOW = DAY;
const FEELINGS_WINDOW = 90 * DAY;
const FRESH_DAYS = 21;

export const WEIGHTS = {
  /** Per need shared with the person's goals, at most two. */
  goal: 1,
  /** Times the summed per-need weight from "felt better/worse", within ±2. */
  felt: 1,
  /** Safe mode only: per need shared with what the check-in points to. */
  mood: 2,
  dayPart: 1.5,
  /** Tagged for other parts of the day only. */
  wrongDayPart: -0.5,
  fresh: 0.75,
  /** Times count / the top count. */
  popular: 0.5,
  saved: 0.5,
  /** Times opens of this kind / the most-opened kind. */
  habit: 0.3,
  /** Finished in the last 24 hours. */
  recent: -3,
} as const;

// In Need order (lib/discover/content_index.dart).
const NEEDS = ['sleep', 'anxious', 'panic', 'low', 'stressed', 'angry', 'urges', 'focus', 'reflect', 'good'];

const NEED_LABEL: Record<string, string> = {
  sleep: 'sleep',
  anxious: 'anxiety',
  panic: 'panic',
  low: 'low moods',
  stressed: 'stress',
  angry: 'anger',
  urges: 'urges',
  focus: 'focus',
  reflect: 'reflection',
  good: 'good days',
};

/** Need.forMood: what each check-in face (0 awful … 4 great) points to. */
function needsForMood(mood: number): string[] {
  if (mood <= 0) return ['panic', 'anxious'];
  if (mood === 1) return ['low'];
  if (mood === 2) return ['reflect'];
  return ['good'];
}

type DayPart = 'morning' | 'afternoon' | 'evening' | 'night';

const DAY_PART_REASON: Record<DayPart, string> = {
  morning: 'For this morning',
  afternoon: 'For this afternoon',
  evening: 'For this evening',
  night: 'For tonight',
};

/** DayPart.of in the app. */
function dayPartOf(hour: number): DayPart {
  if (hour < 5) return 'night';
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  if (hour < 21) return 'evening';
  return 'night';
}

/** Per course in the top 6, for a course the person isn't in. */
export const COURSE_CAP = 2;

export const REASONS = {
  lead: 'For right now',
  support: 'Here whenever you need it',
  fresh: 'Just added',
  popular: 'Popular this month',
  saved: 'One you saved',
  fallback: 'Something to try',
} as const;

// ------------------------------------------------------------------ types

export interface ScoreItem {
  id: string;
  kind: string;
  /** English title, for "Because you felt better after …". */
  title: string;
  order: number;
  premium: boolean;
  addedOn?: string | null;
  needs: string[];
  dayParts: string[];
  intensity?: string | null;
  calmingSafe?: boolean;
  support?: boolean;
}

export interface ScoreCourse {
  id: string;
  title: string;
  /** Item ids, one per day. */
  days: string[];
}

export interface ScoreCatalog {
  items: ScoreItem[];
  courses: ScoreCourse[];
}

export interface Signals {
  /** The server's clock, ISO 8601. */
  now: string;
  /** The person's wall clock, `YYYY-MM-DDTHH:mm`. */
  localTime: string;
  premium: boolean;
  goals?: string[];
  /** 0 awful … 4 great. */
  lastMood?: number | null;
  lastMoodAt?: string | null;
  opensByKind?: Record<string, number>;
  /** The course in progress and its next day (0-based). */
  course?: { id: string; day: number } | null;
  /** Finished sessions, resolved to item ids. */
  sessions?: { id: string; at: string }[];
  /** -1 worse, 0 the same, 1 better. */
  feelings?: { id: string; feeling: number; at: string }[];
  saved?: string[];
  /** Item id -> people who did it in the last 30 days. */
  popularity?: Record<string, number>;
  limit?: number;
}

/**
 * What the app renders for each code, and its arguments:
 *   lead, support, fresh, popular, saved, fallback: none
 *   course:     { course: course id, day: 1-based day }
 *   feltBetter: { title: item id }
 *   goal:       { need: a need name }
 *   dayPart:    { part: morning | afternoon | evening | night }
 */
export type ReasonKey =
  | 'lead'
  | 'support'
  | 'course'
  | 'feltBetter'
  | 'goal'
  | 'dayPart'
  | 'fresh'
  | 'popular'
  | 'saved'
  | 'fallback';

export interface Reason {
  /** English, for apps that predate reasonKey. */
  reason: string;
  reasonKey: ReasonKey;
  reasonArgs?: Record<string, string | number>;
}

export interface Suggestion extends Reason {
  id: string;
}

export interface Recommendations {
  items: Suggestion[];
  rules: typeof RULES;
}

// ---------------------------------------------------------------- helpers

/** Same as _stableHash in content_index.dart. */
function stableHash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) & 0x7fffffff;
  return h;
}

const LOCAL_TIME = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/;

function parseLocal(localTime: string): { day: number; hour: number } {
  const m = LOCAL_TIME.exec(localTime);
  if (!m) throw new Error('localTime must be YYYY-MM-DDTHH:mm');
  return { day: Math.floor(Date.UTC(+m[1], +m[2] - 1, +m[3]) / DAY), hour: +m[4] };
}

function daysSince(date: string | null | undefined, today: number): number | null {
  if (!date) return null;
  const t = Date.parse(`${date.slice(0, 10)}T00:00:00Z`);
  return Number.isNaN(t) ? null : today - Math.floor(t / DAY);
}

const clamp = (x: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, x));

/** Within `window` before now. Unparseable or future times count as now. */
function within(at: string | null | undefined, now: number, window: number): boolean {
  const t = at ? Date.parse(at) : NaN;
  return Number.isNaN(t) || now - t <= window;
}

/**
 * The check-in that triggers the safety rules: awful or low, in the last
 * 2 hours. A mood with no time is taken as recent; erring towards calm is
 * the safe side.
 */
export function isDistressed(s: Pick<Signals, 'lastMood' | 'lastMoodAt'>, now: number): boolean {
  return typeof s.lastMood === 'number' && s.lastMood <= 1 && within(s.lastMoodAt, now, SAFE_WINDOW);
}

/** Allowed straight after a distressed check-in. */
export function isCalmingSafe(item: ScoreItem): boolean {
  if (item.support) return true;
  return item.calmingSafe === true && item.intensity !== 'deep' && !item.needs.includes('good');
}

const reasonOf = (key: Exclude<ReasonKey, 'course' | 'feltBetter' | 'goal' | 'dayPart'>): Reason => ({
  reason: REASONS[key],
  reasonKey: key,
});

/** Premium as far as the caps (and the app) should see it. */
const lockedFor = (item: ScoreItem, premium: boolean) => !premium && item.premium && !item.support;

// ------------------------------------------------------------------ score

interface Term {
  name: 'felt' | 'goal' | 'mood' | 'dayPart' | 'fresh' | 'saved' | 'popular' | 'habit';
  value: number;
  /** Null when the term can't be put into words. */
  reason: Reason | null;
}

interface Scored {
  item: ScoreItem;
  score: number;
  reason: Reason;
  tie: number;
}

/** What the person's own history says about each need. */
interface Context {
  now: number;
  today: number;
  dayPart: DayPart;
  distressed: boolean;
  goals: Set<string>;
  moodNeeds: Set<string>;
  /** Need -> summed feeling (+1 better, -1 worse), clamped to ±1 after /2. */
  needWeight: Map<string, number>;
  /** Need -> the latest item that felt better and has it. */
  betterAfter: Map<string, ScoreItem>;
  recent: Set<string>;
  saved: Set<string>;
  popularity: Record<string, number>;
  topPopularity: number;
  opens: Record<string, number>;
  topOpens: number;
}

function context(catalog: ScoreCatalog, s: Signals): Context {
  const now = Date.parse(s.now);
  if (Number.isNaN(now)) throw new Error('now must be an ISO time');
  const { day: today, hour } = parseLocal(s.localTime);
  const byId = new Map(catalog.items.map((i) => [i.id, i]));

  const sums = new Map<string, number>();
  const betterAfter = new Map<string, ScoreItem>();
  // Newest first, so the first better-after title per need is the latest.
  const feelings = [...(s.feelings ?? [])].sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
  for (const f of feelings) {
    const item = byId.get(f.id);
    if (!item || f.feeling === 0 || !within(f.at, now, FEELINGS_WINDOW)) continue;
    const sign = f.feeling > 0 ? 1 : -1;
    for (const need of item.needs) {
      sums.set(need, (sums.get(need) ?? 0) + sign);
      if (sign > 0 && !betterAfter.has(need)) betterAfter.set(need, item);
    }
  }
  const needWeight = new Map([...sums].map(([need, sum]) => [need, clamp(sum / 2, -1, 1)]));

  const popularity = s.popularity ?? {};
  const opens = s.opensByKind ?? {};
  const distressed = isDistressed(s, now);
  return {
    now,
    today,
    dayPart: dayPartOf(hour),
    distressed,
    goals: new Set(s.goals ?? []),
    moodNeeds: new Set(distressed ? needsForMood(s.lastMood!) : []),
    needWeight,
    betterAfter,
    recent: new Set((s.sessions ?? []).filter((x) => within(x.at, now, RECENT_WINDOW)).map((x) => x.id)),
    saved: new Set(s.saved ?? []),
    popularity,
    topPopularity: Math.max(0, ...Object.values(popularity).filter(Number.isFinite)),
    opens,
    topOpens: Math.max(0, ...Object.values(opens).filter(Number.isFinite)),
  };
}

function terms(item: ScoreItem, c: Context): Term[] {
  const out: Term[] = [];
  const needs = NEEDS.filter((n) => item.needs.includes(n));

  // Need affinity: what helped (or didn't) before.
  let felt = 0;
  let bestNeed: string | null = null;
  for (const n of needs) {
    const w = c.needWeight.get(n) ?? 0;
    felt += w;
    if (w > 0 && c.betterAfter.has(n) && (bestNeed === null || w > c.needWeight.get(bestNeed)!)) bestNeed = n;
  }
  felt = clamp(felt, -2, 2) * WEIGHTS.felt;
  if (felt !== 0) {
    const after = bestNeed ? c.betterAfter.get(bestNeed) : undefined;
    out.push({
      name: 'felt',
      value: felt,
      reason: after
        ? {
            reason: `Because you felt better after ${after.title}`,
            reasonKey: 'feltBetter',
            reasonArgs: { title: after.id },
          }
        : null,
    });
  }

  // Need affinity: goals.
  const goalNeeds = needs.filter((n) => c.goals.has(n));
  if (goalNeeds.length) {
    out.push({
      name: 'goal',
      value: Math.min(2, goalNeeds.length) * WEIGHTS.goal,
      reason: {
        reason: `Because you're working on ${NEED_LABEL[goalNeeds[0]]}`,
        reasonKey: 'goal',
        reasonArgs: { need: goalNeeds[0] },
      },
    });
  }

  if (c.distressed) {
    const fit = needs.filter((n) => c.moodNeeds.has(n)).length;
    if (fit) out.push({ name: 'mood', value: fit * WEIGHTS.mood, reason: reasonOf('lead') });
  }

  if (item.dayParts.length) {
    const fits = item.dayParts.includes(c.dayPart);
    out.push({
      name: 'dayPart',
      value: fits ? WEIGHTS.dayPart : WEIGHTS.wrongDayPart,
      reason: { reason: DAY_PART_REASON[c.dayPart], reasonKey: 'dayPart', reasonArgs: { part: c.dayPart } },
    });
  }

  const age = daysSince(item.addedOn, c.today);
  if (age !== null && age >= 0 && age < FRESH_DAYS) {
    out.push({ name: 'fresh', value: WEIGHTS.fresh, reason: reasonOf('fresh') });
  }

  if (c.saved.has(item.id)) out.push({ name: 'saved', value: WEIGHTS.saved, reason: reasonOf('saved') });

  const count = c.popularity[item.id];
  if (c.topPopularity > 0 && Number.isFinite(count) && count > 0) {
    out.push({ name: 'popular', value: (count / c.topPopularity) * WEIGHTS.popular, reason: reasonOf('popular') });
  }

  const opened = c.opens[item.kind];
  if (c.topOpens > 0 && Number.isFinite(opened) && opened > 0) {
    out.push({ name: 'habit', value: (opened / c.topOpens) * WEIGHTS.habit, reason: null });
  }
  return out;
}

function score(item: ScoreItem, c: Context, day: number): Scored {
  let all = terms(item, c);
  let total = 0;
  let best: Term | null = null;
  // Support items are never ranked down.
  if (item.support) all = all.filter((t) => t.value > 0);
  for (const t of all) {
    total += t.value;
    // First term wins a tie, so the order in terms() is the priority.
    if (t.value > 0 && t.reason && (best === null || t.value > best.value)) best = t;
  }
  if (!item.support && c.recent.has(item.id)) total += WEIGHTS.recent;
  return {
    item,
    score: total,
    reason: best?.reason ?? reasonOf('fallback'),
    tie: (stableHash(item.id) + day * 7919) % 1009,
  };
}

function byRank(a: Scored, b: Scored): number {
  return b.score - a.score || a.tie - b.tie || a.item.order - b.item.order || (a.item.id < b.item.id ? -1 : 1);
}

// ------------------------------------------------------------- assemble

export function recommend(catalog: ScoreCatalog, s: Signals): Recommendations {
  const c = context(catalog, s);
  const limit = clamp(Math.floor(s.limit ?? DEFAULT_LIMIT), 1, MAX_LIMIT);
  const pool = c.distressed ? catalog.items.filter(isCalmingSafe) : catalog.items;
  const ranked = pool.map((item) => score(item, c, c.today)).sort(byRank);

  const coursesOf = new Map<string, string[]>();
  for (const course of catalog.courses) {
    for (const id of course.days) coursesOf.set(id, [...(coursesOf.get(id) ?? []), course.id]);
  }

  const picks: Suggestion[] = [];
  const picked = new Set<string>();
  const kinds = new Map<string, number>();
  const courses = new Map<string, number>();
  let premiumCount = 0;

  // Most popular items are also a day of one of the 7-day courses, so a
  // cap of 1 per course held back too many good matches. A course the
  // person isn't in is just a tag here: up to COURSE_CAP of its days may
  // show. The course they're in is different: its next day already leads
  // the list, and other days would skip ahead or repeat, so it gets only
  // that one (a day past the end means it's finished, not in progress).
  const current = s.course ? catalog.courses.find((x) => x.id === s.course!.id) : undefined;
  const nextDay =
    current && Number.isInteger(s.course!.day) && s.course!.day >= 0 ? current.days[s.course!.day] : undefined;
  const courseCap = (id: string) => (nextDay && id === current!.id ? 1 : COURSE_CAP);
  const window = Math.min(TOP, limit);
  const fits = (item: ScoreItem) =>
    item.support ||
    ((kinds.get(item.kind) ?? 0) < 2 &&
      (coursesOf.get(item.id) ?? []).every((id) => (courses.get(id) ?? 0) < courseCap(id)) &&
      (!lockedFor(item, s.premium) || premiumCount < 2));
  const add = (item: ScoreItem, reason: Reason) => {
    if (picked.has(item.id) || picks.length >= limit) return;
    picks.push({ id: item.id, ...reason });
    picked.add(item.id);
    if (item.support) return;
    kinds.set(item.kind, (kinds.get(item.kind) ?? 0) + 1);
    for (const id of coursesOf.get(item.id) ?? []) courses.set(id, (courses.get(id) ?? 0) + 1);
    if (lockedFor(item, s.premium)) premiumCount++;
  };

  // 1. Safety: a panic or grounding item first (one they can open, if
  //    there is one), then the support items.
  if (c.distressed) {
    const lead = ranked
      .filter((x) => !x.item.support && x.item.needs.includes('panic'))
      .sort((a, b) => Number(lockedFor(a.item, s.premium)) - Number(lockedFor(b.item, s.premium)) || byRank(a, b))[0];
    if (lead) add(lead.item, reasonOf('lead'));
    for (const x of [...ranked].filter((x) => x.item.support).sort((a, b) => a.item.order - b.item.order)) {
      add(x.item, reasonOf('support'));
    }
  }

  // 2. The course in progress.
  if (current && nextDay) {
    const day = s.course!.day;
    const item = pool.find((i) => i.id === nextDay);
    if (item) {
      add(item, {
        reason: `Day ${day + 1} of ${current.title}`,
        reasonKey: 'course',
        reasonArgs: { course: current.id, day: day + 1 },
      });
    }
  }

  // 3–4. By score, with the caps on the top window. Nothing is let past a
  // cap to fill the window; anything held back can follow it.
  for (const x of ranked) {
    if (picks.length >= window) break;
    if (!picked.has(x.item.id) && fits(x.item)) add(x.item, x.reason);
  }
  if (picks.length >= window) {
    for (const x of ranked) {
      if (picks.length >= limit) break;
      if (!picked.has(x.item.id)) add(x.item, x.reason);
    }
  }
  return { items: picks, rules: RULES };
}
