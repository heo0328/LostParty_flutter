// Intentionally permissive DIAGNOSTIC variants, NEVER production candidates.
// Keeps the actual eight-state atomic write set while bypassing selected Rules
// boundaries. Passing a variant is localization evidence, not security approval.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { seedRoom, lifecycle, inspectAll } from './roster_ownership_rules_proof.mjs';
import { authUid, cycleKey, seedGroupLinkedRoom } from './party_group_cutover_rules_test.mjs';

const tracked = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const marker = '  match /databases/{database}/documents {';
assert.equal(tracked.split(marker).length, 2);
const bypasses = {
  aggregate: 'match /recruitments/{id} { allow update: if true; }',
  states: 'match /players/{player}/raidStates/{id} { allow create, update: if true; }',
  event: 'match /partyEvents/{id} { allow create: if true; }',
  listing: 'match /groups/{group}/raidListings/{id} { allow update: if true; }',
};
const variants = {
  baseline: [],
  skipAggregate: ['aggregate'],
  skipStates: ['states'],
  skipEvent: ['event'],
  skipListing: ['listing'],
  onlyAggregate: ['states', 'event', 'listing'],
  onlyStates: ['aggregate', 'event', 'listing'],
  onlyEvent: ['aggregate', 'states', 'listing'],
  onlyListing: ['aggregate', 'states', 'event'],
  bypassAllControl: Object.keys(bypasses),
};
const results = {};
for (const [name, skips] of Object.entries(variants)) {
  const rules = tracked.replace(marker, marker + '\n' + skips.map(key => bypasses[key]).join('\n'));
  const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
    firestore: { rules, host: '127.0.0.1', port: 8080 } });
  try {
    const db = env.authenticatedContext(authUid).firestore();
    await seedRoom(env, db);
    await seedGroupLinkedRoom(env, db);
    const before = await inspectAll(env);
    let error;
    try { await lifecycle(db, 'advanceCycle'); }
    catch (caught) { error = caught; }
    const after = await inspectAll(env);
    if (error) {
      assert.deepEqual(after, before, 'rejected transaction changed data');
      results[name] = /maximum of 1000 expressions/.test(error.message) ? 'expression-limit' : error.message;
    } else {
      assert.equal(after.room.currentCycleKey, cycleKey);
      assert.equal(after.room.revision, before.room.revision + 1);
      assert.equal(after.states.length, 8);
      assert.ok(after.states.every(state => state.status === 'active' && state.cycleKey === cycleKey));
      assert.equal(after.listing.sourceRevision, after.room.revision);
      results[name] = 'allowed';
    }
    console.log(`BOUNDARY ${name}: ${results[name]}`);
  } finally { await env.cleanup(); }
}
assert.equal(results.bypassAllControl, 'allowed', 'fixture/control must execute');
console.log('BOUNDARY SUMMARY', JSON.stringify(results));
console.log('DIAGNOSTIC ONLY; no variant is authorized for deployment.');
