// DE2-C demo only: state reconstruction and legacy ownership boundaries.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, deleteField, collection, getDocs } from 'firebase/firestore';
import { sharedTargetStatus } from './roster_target_rules_candidate.mjs';
import { seedRoom, lifecycle, inspectAll } from './roster_ownership_rules_proof.mjs';
import { authUid, recruitmentId, raidId, cycleKey, seedGroupLinkedRoom } from './party_group_cutover_rules_test.mjs';

let rules = sharedTargetStatus(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
function replaceOnce(from, to) {
  assert.equal(rules.split(from).length, 2, `unique hook: ${from}`);
  rules = rules.replace(from, to);
}
replaceOnce('    function validAtomicAdvanceRaidStateCreate(', `    function deCurrentOwnership(data) {
      let character = get(characterPath(data.characterId)).data;
      let account = get(/databases/$(database)/documents/gameAccounts/$(character.gameAccountId)).data;
      let generation = character.get('ownershipRevision', 0);
      return generation is int && generation >= 0
        && account.get('ownershipRevision', 0) is int
        && account.get('ownershipRevision', 0) == generation
        && character.ownerPlayerId == data.playerId
        && account.ownerPlayerId == data.playerId
        && data.get('ownershipRevision', 0) is int
        && data.get('ownershipRevision', 0) == generation;
    }

    function validAtomicAdvanceRaidStateCreate(`);
replaceOnce('&& newData.raidStateTargets == oldData.raidStateTargets',
  '&& newData.raidStateTargets == oldData.raidStateTargets\n        && newData.partySlots == oldData.partySlots');
replaceOnce('&& recruitment.partySlots[index].role == data.role;',
  "&& recruitment.partySlots[index].role == data.role\n        && recruitment.partySlots[index].get('ownershipRevision', 0) == data.get('ownershipRevision', 0);");
replaceOnce("&& recruitment.lastCommandType == 'advanceCycle'\n        && data.keys().hasOnly([",
  "&& recruitment.lastCommandType == 'advanceCycle'\n        && deCurrentOwnership(data)\n        && data.keys().hasOnly([");
replaceOnce("'source', 'revision', 'updatedAt'\n        ])",
  "'source', 'revision', 'updatedAt', 'ownershipRevision'\n        ])");
replaceOnce('return atomicIsLifecycleCommand(recruitment)\n        && newData.playerId == playerId',
  'return atomicIsLifecycleCommand(recruitment)\n        && deCurrentOwnership(oldData)\n        && newData.playerId == playerId');
replaceOnce("&& oldData.status == 'active'\n            && newData.status == 'completed'",
  "&& oldData.status == 'active'\n            && atomicAdvanceStateMatchesSlot(recruitment, oldData)\n            && newData.status == 'completed'");

const directory = new URL('../coverage/roster-legacy/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
  firestore: { rules, host: '127.0.0.1', port: 8080 } });
const db = env.authenticatedContext(authUid).firestore();
const failures = [];
async function check(name, action) {
  try { await action(); console.log(`PASS LEGACY: ${name}`); return true; }
  catch (error) { failures.push(name); console.error(`FAIL LEGACY: ${name}: ${error.message}`); return false; }
}
async function snapshot() {
  const result = await inspectAll(env);
  await env.withSecurityRulesDisabled(async ctx => {
    const events = await getDocs(collection(ctx.firestore(), 'partyEvents'));
    result.events = events.docs.map(d => ({ id: d.id, ...d.data() })).sort((a, b) => a.id.localeCompare(b.id));
  });
  return result;
}
async function seed({ missing = false, legacy = false } = {}) {
  await seedRoom(env, db);
  await seedGroupLinkedRoom(env, db);
  const { room } = await inspectAll(env);
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    for (const slot of room.partySlots) {
      const gameAccountId = `de-account-${slot.playerId}`;
      await setDoc(doc(admin, 'gameAccounts', gameAccountId), { ownerPlayerId: slot.playerId,
        ...(legacy ? {} : { ownershipRevision: 1 }) });
      await updateDoc(doc(admin, 'characters', slot.characterId), { gameAccountId,
        ownershipRevision: legacy ? deleteField() : 1 });
      if (legacy) await updateDoc(doc(admin, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`),
        { ownershipRevision: deleteField() });
    }
    if (legacy) await updateDoc(doc(admin, 'recruitments', recruitmentId), {
      partySlots: room.partySlots.map(({ ownershipRevision, ...slot }) => slot),
    });
    if (missing) {
      const slot = room.partySlots.at(-1);
      await deleteDoc(doc(admin, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`));
    }
  });
  return room.partySlots.at(-1);
}
async function advance(options = {}) { return lifecycle(db, 'advanceCycle', { ownershipSnapshot: true, ...options }); }
try {
  for (const [name, options, type] of [
    ['current mixed create/update advance', { missing: true }, 'advanceCycle'],
    ['current complete', {}, 'complete'],
    ['legacy zero mixed advance', { missing: true, legacy: true }, 'advanceCycle'],
  ]) await check(name, async () => {
    await seed(options);
    const before = await snapshot();
    await assertSucceeds(lifecycle(db, type, { ownershipSnapshot: true }));
    const after = await snapshot();
    assert.equal(after.room.revision, before.room.revision + 1);
    assert.equal(after.states.length, 8);
    assert.ok(after.states.every(s => s.status === (type === 'complete' ? 'completed' : 'active')));
    if (type === 'advanceCycle') assert.ok(after.states.every(s => s.cycleKey === cycleKey));
    assert.equal(after.listing.sourceRevision, after.room.revision);
    assert.equal(after.events.length, before.events.length + 1);
  });
  if (!failures.length) {
    for (const scenario of ['transfer', 'returned', 'missing-character', 'missing-account', 'account-mismatch',
      'null-generation', 'negative-generation', 'string-generation', 'missing-snapshot', 'slot-revision',
      'revision-forged', 'revision-decreased', 'revision-deleted']) {
      await check(`missing create rejects ${scenario} atomically`, async () => {
        const slot = await seed({ missing: true });
        await env.withSecurityRulesDisabled(async ctx => {
          const admin = ctx.firestore();
          const charRef = doc(admin, 'characters', slot.characterId);
          const accountRef = doc(admin, 'gameAccounts', `de-account-${slot.playerId}`);
          if (scenario === 'missing-character') await deleteDoc(charRef);
          if (scenario === 'missing-account') await deleteDoc(accountRef);
          if (scenario === 'account-mismatch') await updateDoc(accountRef, { ownershipRevision: 2 });
          if (['transfer', 'returned'].includes(scenario)) for (const ref of [charRef, accountRef]) {
            await updateDoc(ref, { ownerPlayerId: scenario === 'transfer' ? 'new-owner' : slot.playerId,
              ownershipRevision: scenario === 'transfer' ? 2 : 3 });
          }
          const bad = { 'null-generation': null, 'negative-generation': -1, 'string-generation': '1' };
          if (Object.hasOwn(bad, scenario)) await updateDoc(charRef, { ownershipRevision: bad[scenario] });
          if (scenario === 'missing-snapshot') {
            const { room } = await inspectAll(env);
            await updateDoc(doc(admin, 'recruitments', recruitmentId), {
              partySlots: room.partySlots.map(({ ownershipRevision, ...item }) => item),
            });
          }
        });
        const before = await snapshot();
        await assertFails(advance({ tamper: scenario }));
        assert.deepEqual(await snapshot(), before);
      });
    }
    for (const tamper of ['revision-forged', 'revision-decreased', 'revision-deleted']) {
      await check(`existing state rejects ${tamper} atomically`, async () => {
        await seed();
        const before = await snapshot();
        await assertFails(advance({ tamper }));
        assert.deepEqual(await snapshot(), before);
      });
    }
  } else console.log('SKIP LEGACY negatives: positive ownership boundary failed');
} finally { await env.cleanup(); }
assert.deepEqual(failures, [], 'DE2-C proof not accepted; production unchanged');
