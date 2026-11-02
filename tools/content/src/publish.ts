// npm run publish -- --env staging|production [--dry-run]
//
// Checks content/, prepares media, and uploads media, the versioned
// catalogue and latest.json to R2, in that order. A dry run prints the plan
// and writes the would-be files to tools/content/.out/<env>/, with no
// network and no credentials. See README.md and docs/backend-design.md §8.
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { credentialsFromEnv, envNames, envs, type EnvName, minApp, s3Endpoint } from './config.ts';
import { check, load, repoRoot } from './content.ts';
import { describe, execute, plan, uploads } from './publisher.ts';
import { r2Store, type Store } from './store.ts';
import { prepareFile } from './transcode.ts';

const toolDir = resolve(import.meta.dirname, '..');

function fail(msg: string): never {
  console.error(msg);
  process.exit(1);
}

const { values } = parseArgs({
  options: { env: { type: 'string' }, 'dry-run': { type: 'boolean', default: false } },
});
const envName = values.env as EnvName | undefined;
if (!envName || !envNames.includes(envName)) {
  fail(`Usage: npm run publish -- --env ${envNames.join('|')} [--dry-run]`);
}
const env = envs[envName];
const dryRun = values['dry-run'];

const { items, courses, backgrounds, errors } = check(load());
if (errors.length) {
  console.error(errors.join('\n'));
  fail(`\n${errors.length} problem(s); nothing published.`);
}

let store: Store | null = null;
if (!dryRun) {
  try {
    store = r2Store(s3Endpoint, credentialsFromEnv());
  } catch (e) {
    fail((e as Error).message);
  }
}

const cacheDir = join(toolDir, '.cache');
const p = await plan({
  items,
  courses,
  backgrounds,
  env,
  minApp,
  store,
  prepare: (src) =>
    prepareFile(join(repoRoot, src.path), src.role, {
      cacheDir,
      warn: (m) => console.warn(`warning: ${m}`),
    }),
});
console.log(describe(p, dryRun).join('\n'));

if (dryRun) {
  const out = join(toolDir, '.out', env.name);
  rmSync(out, { recursive: true, force: true });
  for (const o of uploads(p)) {
    const file = join(out, o.bucket, o.key);
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, o.body);
  }
  console.log(`Dry run: nothing uploaded. Would-be files are in ${relative(process.cwd(), out) || '.'}/`);
} else if (!p.unchanged) {
  const done = await execute(p, store!, console.log);
  console.log(`Published v${p.version} to ${env.name}: ${done.length} object(s) uploaded.`);
}
