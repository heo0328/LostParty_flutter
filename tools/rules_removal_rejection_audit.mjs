// Read-only demo diagnosis: distinguish policy rejection from evaluation exhaustion.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { prioritizeMemberRemoval } from './roster_complexity_candidate.mjs';
import { seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn,
  approvePublicApplicationTxn, seedGroupLinkedRoom, seedPersistedAdvanceCycleMarker,
  repositionApprovedMemberTxn, kickApprovedMemberTxn, authUid } from './party_group_cutover_rules_test.mjs';

const baseline = fs.readFileSync('firestore.rules', 'utf8').replace(/\r\n/g, '\n');
assert.equal(createHash('sha256').update(baseline).digest('hex'),
  '6a4a4b52cf566f9c119d9de3c3876c411c336da24ee62b9bca5fd1be97bd1da9');
const directory = 'coverage/rules-audit/removal-rejections';
fs.mkdirSync(directory, { recursive: true });
fs.mkdirSync('coverage/roster-leader', { recursive: true });
fs.writeFileSync('coverage/roster-leader/manifest.json', JSON.stringify({ diagnostic: 'removal-rejections' }));
process.env.RULES_AUDIT = '1';
const results = [];
async function coverage(name) {
  const response = await fetch('http://127.0.0.1:8080/emulator/v1/projects/demo-party-group-cutover:ruleCoverage');
  assert.ok(response.ok);
  fs.writeFileSync(`${directory}/${name}.json`, await response.text());
}
for (const [variant, rules] of Object.entries({ baseline, candidate: prioritizeMemberRemoval(baseline) })) {
  const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
    firestore: { rules, host: '127.0.0.1', port: 8080 } });
  try {
    const db = env.authenticatedContext(authUid).firestore();
    const joiner = env.authenticatedContext('joiner-auth').firestore();
    for (const scenario of ['unconsumed-marker', 'forged-listing']) {
      await env.clearFirestore();
      await seedBase(env); await seedJoiner(env);
      await assertSucceeds(createPublicRecruitmentTxn(db));
      await assertSucceeds(applicationTxn(joiner, 'apply'));
      await assertSucceeds(approvePublicApplicationTxn(db));
      if (scenario === 'unconsumed-marker') await seedPersistedAdvanceCycleMarker(env);
      else await seedGroupLinkedRoom(env, db, { includeJoinerGroupMember: true });
      const name = `${variant}-${scenario}`;
      await coverage(`${name}-before`);
      const offset = fs.statSync('firestore-debug.log').size;
      await assertFails(scenario === 'unconsumed-marker'
        ? repositionApprovedMemberTxn(db, 2, 2, { skipMarkerConsumption: true })
        : kickApprovedMemberTxn(db, { listingOverrides: { memberCount: 99 } }));
      await coverage(`${name}-after`);
      const log = fs.readFileSync('firestore-debug.log').subarray(offset).toString('utf8');
      fs.writeFileSync(`${directory}/${name}.log`, log);
      const row = { variant, scenario, rejected: true,
        budgetExceeded: log.includes('maximum of 1000'),
        sha256: createHash('sha256').update(rules).digest('hex') };
      results.push(row); console.log(JSON.stringify(row));
    }
  } finally { await env.cleanup(); }
}
fs.writeFileSync(`${directory}/results.json`, JSON.stringify(results, null, 2));
