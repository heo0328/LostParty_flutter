// Emit the native helper; do not regenerate the former 50-slot OR tree.
import fs from 'node:fs';
process.stdout.write(fs.readFileSync(
  new URL('./removed_active_group_id.rules.txt', import.meta.url), 'utf8',
));
