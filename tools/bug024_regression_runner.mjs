// Runs every required suite even when an earlier suite fails.
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
const results = [];
for (const [name, script, extra] of [
  ['bug024', 'tools/bug024_preparation_proof.mjs', {}],
  ['completion-role', 'tools/party_completion_role_proof.mjs', {}],
  ['character-placement', 'tools/party_group_cutover_rules_test.mjs', { PARTY_RULES_CASE: 'character-placement' }],
]) {
  const run = spawnSync(process.execPath, [script], {
    stdio: 'inherit', timeout: 600000, env: { ...process.env, ...extra } });
  results.push({ name, exitCode: run.status, error: run.error?.message });
}
fs.mkdirSync('coverage/bug024', { recursive: true });
fs.writeFileSync('coverage/bug024/suites.json', JSON.stringify(results, null, 2));
process.exitCode = results.every(r => r.exitCode === 0) ? 0 : 1;
