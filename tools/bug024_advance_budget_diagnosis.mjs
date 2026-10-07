// Demo-only counterfactuals: never generate the deployment file.
// Shared empty paths preserve the check expressions while reducing distinct reads.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
const original = fs.readFileSync('coverage/rules-executable/review/readable.rules', 'utf8');
const assignment = '/databases/$(database)/documents/players/$(playerId)/activeRaidAssignments/$(assignmentId);';
const claim = '/databases/$(database)/documents/players/$(playerId)/weeklyRaidClaims/$(weeklyRaidClaimId(cycleKey, characterId, raidId));';
assert.equal(original.split(assignment).length, 2);
assert.equal(original.split(claim).length, 2);
const results = [];
for (const [name, shareAssignments, shareClaims] of [
  ['tracked-equivalent', false, false], ['shared-assignments', true, false],
  ['shared-claims', false, true], ['shared-both', true, true]]) {
  const dir = `coverage/bug024/budget/${name}`;
  fs.mkdirSync(dir, { recursive: true });
  let source = original;
  if (shareAssignments) source = source.replace(assignment,
    '/databases/$(database)/documents/players/__budget__/activeRaidAssignments/empty;');
  if (shareClaims) source = source.replace(claim,
    '/databases/$(database)/documents/players/__budget__/weeklyRaidClaims/empty;');
  const filename = path.resolve(`${dir}/diagnostic-only.rules`);
  fs.writeFileSync(filename, source);
  const run = spawnSync(process.execPath, ['tools/bug024_preparation_proof.mjs'], {
    encoding: 'utf8', timeout: 180000, env: { ...process.env,
      BUG024_DIAGNOSIS: '1', BUG024_RULES_FILE: filename, BUG024_EVIDENCE_DIR: dir }});
  fs.writeFileSync(`${dir}/console.log`, (run.stdout || '') + (run.stderr || ''));
  const evidence = fs.existsSync(`${dir}/results.json`)
    ? JSON.parse(fs.readFileSync(`${dir}/results.json`, 'utf8')) : [];
  results.push({ name, exitCode: run.status, evidence });
  console.log(JSON.stringify({ name, passed: run.status === 0,
    error: evidence.find(e => !e.passed)?.error || run.error?.message }));
}
fs.writeFileSync('coverage/bug024/budget/results.json', JSON.stringify(results, null, 2));
// A diagnostic outcome is evidence, not a production safety approval.
