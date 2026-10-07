import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
const results = [];
for (const [name, script, extra] of [
  ['runtime-boundaries', 'tools/bug024_spark_seal_proof.mjs', { BUG024_RULES_FILE: 'firestore.rules', BUG024_RUNTIME: '1' }],
  ['completion-role', 'tools/party_completion_role_proof.mjs', { BUG024_RUNTIME: '1' }],
  ['character-placement', 'tools/party_group_cutover_rules_test.mjs', { PARTY_RULES_CASE: 'character-placement' }],
  ['manual-completion', 'tools/roster_manual_completion_proof.mjs', { ROSTER_COMPLEXITY_RULES_FILE: 'firestore.rules' }],
  ['personal-completion', 'tools/roster_personal_completion_proof.mjs', { ROSTER_COMPLEXITY_RULES_FILE: 'firestore.rules' }],
]) {
  const run = spawnSync(process.execPath, [script], { stdio: 'inherit', timeout: 600000, env: { ...process.env, ...extra } });
  results.push({ name, exitCode: run.status, error: run.error?.message });
}
fs.mkdirSync('coverage/bug024/runtime', { recursive: true });
fs.writeFileSync('coverage/bug024/runtime/suites.json', JSON.stringify(results, null, 2));
process.exitCode = results.every(r => r.exitCode === 0) ? 0 : 1;
