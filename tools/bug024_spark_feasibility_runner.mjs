// Separate outcomes: published regression baseline and unpromoted Spark input.
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
const directory = 'coverage/bug024/spark';
const baseline = `${directory}/published-baseline.rules`;
const results = [];
for (const [name, script, env] of [
  ['published-completion-and-advance', 'tools/party_completion_role_proof.mjs', { COMPLETION_RULES_FILE: baseline }],
  ['published-character-placement', 'tools/party_group_cutover_rules_test.mjs', { PARTY_RULES_FILE: baseline, PARTY_RULES_CASE: 'character-placement' }],
  ['spark-distributed-preparation', 'tools/bug024_preparation_proof.mjs', {
    BUG024_RULES_FILE: `${directory}/preparation-distributed.rules`, BUG024_SPARK_EVENT: '1', BUG024_EVIDENCE_DIR: `${directory}/proof` }],
]) {
  const result = spawnSync(process.execPath, [script], { stdio: 'inherit', timeout: 600000,
    env: { ...process.env, ...env } });
  results.push({ name, exitCode: result.status, error: result.error?.message });
}
fs.writeFileSync(`${directory}/suites.json`, JSON.stringify(results, null, 2));
process.exitCode = results.every(result => result.exitCode === 0) ? 0 : 1;
