// npm run translate -- <id|--all> --to fr,de,es,zh-Hans [--dry-run]
//
// Drafts the missing translations of one item, course or background, or of
// everything with --all, and writes them with `reviewed: false`. Needs
// ANTHROPIC_API_KEY unless it's a dry run. See src/translator.ts.
import { parseArgs } from 'node:util';
import { translate } from './translator.ts';

const usage = 'Usage: npm run translate -- <id|--all> --to fr,de,es,zh-Hans [--dry-run]';
const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    all: { type: 'boolean', default: false },
    to: { type: 'string' },
    'dry-run': { type: 'boolean', default: false },
  },
});
const target = values.all ? '--all' : positionals[0];
if (!target || !values.to || (values.all && positionals.length)) {
  console.error(usage);
  process.exit(2);
}
const dryRun = values['dry-run'];
try {
  const jobs = await translate({
    target,
    locales: values.to.split(','),
    apiKey: process.env.ANTHROPIC_API_KEY,
    dryRun,
  });
  if (jobs.length && !dryRun) {
    console.log(
      `\n${jobs.length} draft(s) written with reviewed: false. Run npm run check, ` +
        'then have a fluent reader review them (content/README.md).',
    );
  }
} catch (e) {
  console.error((e as Error).message);
  process.exit(1);
}
