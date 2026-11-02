// npm run check: validate content/ and say what's wrong, file by file.
import { check, load } from './content.ts';

const { items, courses, backgrounds, errors } = check(load());
if (errors.length) {
  console.error(errors.join('\n'));
  console.error(`\n${errors.length} problem(s).`);
  process.exit(1);
}
console.log(
  `content/ is valid: ${items.length} items, ${courses.length} courses, ` +
    `${backgrounds.length} backgrounds.`,
);
