import assert from 'node:assert/strict';
import { test } from 'node:test';
import { removeRepeatedPositionValidation, deduplicateCleanup, dispatchCleanupEvents, rulesFunction, preserveExistingSlots, integratedBaseline } from './roster_complexity_candidate.mjs';

const baseline = integratedBaseline();
const deduplicated = deduplicateCleanup(baseline);
const dispatched = dispatchCleanupEvents(deduplicated);
const repaired = preserveExistingSlots(baseline);
const aliases = new Map([
  ['deLeaderOwnershipChanged', 'deOwnershipChanged'], ['dePeerOwnershipChanged', 'deOwnershipChanged'],
  ['deLeaderCleanupStateUnchanged', 'deCleanupStateUnchanged'], ['dePeerCleanupStateUnchanged', 'deCleanupStateUnchanged'],
  ['dePeerCleanupComposition', 'deCleanupComposition'],
]);
const names = source => [...source.matchAll(/    function (\w+)\(/g)].map(m => m[1]);
const canonicalize = body => {
  for (const [from, to] of aliases) body = body.replaceAll(`${from}(`, `${to}(`);
  return body;
};

test('deduplication preserves all non-composition function bodies and every allow', () => {
  for (const name of names(baseline)) {
    if (aliases.has(name) || name === 'deLeaderCleanupComposition') continue;
    assert.equal(rulesFunction(deduplicated, name).body, canonicalize(rulesFunction(baseline, name).body), name);
  }
  assert.deepEqual([...deduplicated.matchAll(/allow\s[\s\S]*?;/g)].map(m => m[0]),
    [...baseline.matchAll(/allow\s[\s\S]*?;/g)].map(m => m[0]));
  assert.equal(names(baseline).length - names(deduplicated).length, 5);
});

test('leader composition retains every equality including leader snapshots', () => {
  const atoms = body => body.replace(/return|;|\s/g, '').split('&&').sort();
  const expanded = rulesFunction(deduplicated, 'deLeaderCleanupComposition').body.replace(
    'deCleanupComposition(data, room)', rulesFunction(deduplicated, 'deCleanupComposition').body.replace('return', '').replace(';', ''));
  assert.deepEqual(atoms(expanded), atoms(rulesFunction(baseline, 'deLeaderCleanupComposition').body));
});

test('source drift in a duplicated guard fails rather than dropping a condition', () => {
  const old = rulesFunction(baseline, 'dePeerOwnershipChanged');
  assert.throws(() => deduplicateCleanup(baseline.replace(old.text, old.text.replace('observed is int', 'observed is string'))));
});

test('event dispatch changes only partyEvents create, keeps every validator intact', () => {
  for (const name of names(deduplicated)) assert.equal(rulesFunction(dispatched, name).body, rulesFunction(deduplicated, name).body);
  const before = [...deduplicated.matchAll(/allow\s[\s\S]*?;/g)].map(m => m[0]);
  const after = [...dispatched.matchAll(/allow\s[\s\S]*?;/g)].map(m => m[0]);
  assert.equal(before.length, after.length);
  assert.equal(before.filter((v, i) => v !== after[i]).length, 1);
  assert.ok(after.find((v, i) => v !== before[i]).includes('dePeerCleanupEventCreate'));
});

test('cleanup event types are disjoint from membership and lifecycle event domains', () => {
  const membership = rulesFunction(baseline, 'atomicIsMembershipEventType').body;
  const lifecycle = rulesFunction(baseline, 'atomicIsLifecycleCommand').body
    + rulesFunction(baseline, 'atomicLifecycleEventType').body;
  for (const type of ['ownershipPeerRemoved', 'ownershipLeaderRemoved', 'ownershipParticipantRemoved']) {
    assert.ok(!membership.includes(`'${type}'`));
    assert.ok(!lifecycle.includes(`'${type}'`));
  }
});

test('static helper call graph is acyclic and remains within depth 20', () => {
  // Source-level conservative bound, not a Firestore runtime expression count.
  for (const source of [baseline, repaired, deduplicateCleanup(repaired), dispatchCleanupEvents(deduplicateCleanup(repaired))]) {
    const all = new Set(names(source));
    const depth = (name, stack = []) => {
      assert.ok(!stack.includes(name), `recursive helper ${name}`);
      const calls = [...rulesFunction(source, name).body.matchAll(/\b(\w+)\(/g)]
        .map(m => m[1]).filter(n => all.has(n));
      return 1 + Math.max(0, ...calls.map(n => depth(n, [...stack, name])));
    };
    const maximum = Math.max(...[...all].map(n => depth(n)));
    console.log(`source bytes=${Buffer.byteLength(source)}, functions=${all.size}, helper depth=${maximum}`);
    assert.ok(maximum <= 20, `helper depth ${maximum}`);
  }
});

test('preservation fast path changes only aggregate generation helper and retains all fallback checks', () => {
  for (const name of names(baseline)) {
    if (name !== 'deChangedSlotGenerations') assert.equal(rulesFunction(repaired, name).body, rulesFunction(baseline, name).body);
  }
  const body = rulesFunction(repaired, 'deChangedSlotGenerations').body;
  assert.ok(body.includes('after.partySlots.size() <= 8'));
  assert.ok(body.includes('before.partySlots.hasAll(after.partySlots)'));
  for (let i = 0; i < 8; i++) assert.ok(body.includes(`deChangedSlotGenerationAt(before, after, ${i})`));
  assert.deepEqual([...repaired.matchAll(/allow\s[\s\S]*?;/g)].map(m => m[0]),
    [...baseline.matchAll(/allow\s[\s\S]*?;/g)].map(m => m[0]));
});

 test('position fallback is redundant only while validator implies fast-path shape', () => {
  const baseline = dispatchCleanupEvents(deduplicateCleanup(preserveExistingSlots(integratedBaseline())));
  const candidate = removeRepeatedPositionValidation(baseline);
  for (const name of names(baseline)) assert.equal(rulesFunction(candidate,name).body,rulesFunction(baseline,name).body);
  const before=[...baseline.matchAll(/allow\s[\s\S]*?;/g)].map(m=>m[0]);
  const after=[...candidate.matchAll(/allow\s[\s\S]*?;/g)].map(m=>m[0]);
  assert.equal(before.filter((x,i)=>x!==after[i]).length,1);
  const changed=after.find((x,i)=>x!==before[i]);
  assert.equal(changed.split('validMemberPositionChange(').length,2);
  const original=rulesFunction(baseline,'validMemberPositionChange');
  assert.throws(()=>removeRepeatedPositionValidation(baseline.replace(original.text, original.text.replace("'partyIndex', 'slotIndex', 'updatedAt'", "'partyIndex', 'slotIndex', 'updatedAt', 'role'"))));
});
