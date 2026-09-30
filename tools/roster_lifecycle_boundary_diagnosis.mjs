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
// Preserve the real request/write set; narrow only the recruitment update rule.
// The ternary preserves normal fixture setup and avoids unrelated fallback rules.
const aggregatePredicates = {
  directFull: 'validAtomicLifecycleUpdate(resource.data, request.resource.data)',
  noTargets: `atomicIsLifecycleCommand(request.resource.data)
    && atomicLifecycleActorAllowed(resource.data, request.resource.data)
    && atomicValidLifecycleShape(resource.data, request.resource.data)
    && atomicValidLifecycleState(resource.data, request.resource.data)
    && atomicValidIncompleteEndShape(resource.data, request.resource.data)
    && atomicValidGroupLifecycleCount(resource.data, request.resource.data)`,
  targetsOnly: 'atomicAllTargetsMatch(request.resource.data)',
  firstTarget: 'atomicTargetMatchesTransition(request.resource.data, 0)',
  lastTarget: 'atomicTargetMatchesTransition(request.resource.data, 7)',
  control: 'true',
};
function aggregateRules(expression) {
  const section = tracked.indexOf('    match /recruitments/{recruitmentId} {');
  assert.ok(section > 0);
  const start = tracked.indexOf('      allow update: if ', section);
  const end = tracked.indexOf('      allow delete: if false;', start);
  assert.ok(start > section && end > start);
  const original = tracked.slice(start, end).trim().replace(/^allow update: if /, '').replace(/;$/, '');
  return tracked.slice(0, start) + `      allow update: if
    request.resource.data.lastCommandType == 'advanceCycle'
      ? (${expression}) : (${original});\n` + tracked.slice(end);
}
const aggregateMode = process.argv.includes('--aggregate');
const ruleVariants = process.argv.includes('--confirm')
  ? { baseline: tracked, directFull: aggregateRules(aggregatePredicates.directFull), control: aggregateRules('true') }
  : aggregateMode
  ? Object.fromEntries(Object.entries(aggregatePredicates).map(([name, expression]) => [name, aggregateRules(expression)]))
  : Object.fromEntries(Object.entries(variants).map(([name, skips]) => [name,
    tracked.replace(marker, marker + '\n' + skips.map(key => bypasses[key]).join('\n'))]));
const results = {};
for (const [name, rules] of Object.entries(ruleVariants)) {
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
assert.equal(results[aggregateMode ? 'control' : 'bypassAllControl'], 'allowed', 'fixture/control must execute');
if (process.argv.includes('--confirm')) {
  assert.equal(results.baseline, 'expression-limit', 'baseline diagnosis changed');
  assert.equal(results.directFull, 'allowed', 'full lifecycle direct dispatch must pass');
}
console.log('BOUNDARY SUMMARY', JSON.stringify(results));
console.log('DIAGNOSTIC ONLY; no variant is authorized for deployment.');
