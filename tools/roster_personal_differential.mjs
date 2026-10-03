import fs from 'node:fs';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { removeRepeatedPersonalCompletion } from './roster_complexity_candidate.mjs';

const baseline = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8').replace(/\r\n/g, '\n');
const candidate = removeRepeatedPersonalCompletion(baseline);
const directory = new URL('../coverage/roster-complexity/personal/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
const results = [];
for (const [name, rules] of Object.entries({ baseline, candidate })) {
  const file = new URL(`${name}.rules`, directory);
  fs.writeFileSync(file, rules);
  const run = spawnSync(process.execPath, ['tools/roster_personal_completion_proof.mjs'], {
    encoding: 'utf8', timeout: 300000,
    env: { ...process.env, LEADER_PROOF_SCOPE: '', ROSTER_COMPLEXITY_RULES_FILE: fileURLToPath(file) },
  });
  fs.writeFileSync(new URL(`${name}.log`, directory), (run.stdout ?? '') + (run.stderr ?? ''));
  const outcomes = JSON.parse(fs.readFileSync(new URL('../coverage/roster-leader/results.json', import.meta.url), 'utf8'));
  results.push({ name, bytes: Buffer.byteLength(rules), sha256: createHash('sha256').update(rules).digest('hex'), outcomes });
  fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
  assert.equal(run.status, 0, `${name} personal completion failure`);
  assert.equal(outcomes.length, 15);
  console.log(`${name}: ${outcomes.length} personal completion boundaries passed`);
}
assert.deepEqual(results[0].outcomes, results[1].outcomes);
