// DE2-D isolated server-boundary proof. Ownership changes are admin fixtures.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc,
  runTransaction, serverTimestamp } from 'firebase/firestore';
import { completedCleanupCandidate } from './roster_completed_cleanup_candidate.mjs';
import { seedRoom, lifecycle, inspectAll } from './roster_ownership_rules_proof.mjs';
import { authUid, playerId, recruitmentId, raidId, seedGroupLinkedRoom, removeApprovedMemberTxn } from './party_group_cutover_rules_test.mjs';

export async function runCleanupProof(rulesOverride = null, extension = null) {
const rules = rulesOverride ?? completedCleanupCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-cleanup/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
  firestore: { rules, host: '127.0.0.1', port: 8080 } });
const db = env.authenticatedContext(authUid).firestore();
const selfDb = env.authenticatedContext('joiner-auth').firestore();
const thirdDb = env.authenticatedContext('cleanup-third-auth').firestore();
let originalSlots;
const results = [];
async function check(name, action) {
  try { await action(); results.push({ name, passed: true }); console.log(`PASS CLEANUP: ${name}`); }
  catch (error) { results.push({ name, passed: false, error: error.message }); console.error(`FAIL CLEANUP: ${name}: ${error.message}`); }
}
async function snapshot() {
  const result = await inspectAll(env);
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    result.states = await Promise.all(originalSlots.map(async s =>
      (await getDoc(doc(admin, 'players', s.playerId, 'raidStates', `${s.characterId}_${raidId}`))).data() ?? null));
    for (const [key, parts] of [['events', ['partyEvents']], ['members', ['recruitments', recruitmentId, 'members']],
      ['groupMembers', ['groups', result.room.groupId, 'members']]]) {
      result[key] = (await getDocs(collection(admin, ...parts))).docs.map(d => ({ id: d.id, ...d.data() })).sort((a, b) => a.id.localeCompare(b.id));
    }
    result.group = (await getDoc(doc(admin, 'groups', result.room.groupId))).data();
  });
  return result;
}
async function seed({ returned = false, self = false, scenario = null, active = false } = {}) {
  await seedRoom(env, db);
  await seedGroupLinkedRoom(env, db, { includeJoinerGroupMember: true });
  originalSlots = (await inspectAll(env)).room.partySlots;
  await env.withSecurityRulesDisabled(async ctx => {
    for (const slot of originalSlots) {
      const gameAccountId = `de-account-${slot.playerId}`;
      await setDoc(doc(ctx.firestore(), 'gameAccounts', gameAccountId), { ownerPlayerId: slot.playerId, ownershipRevision: 1 });
      await updateDoc(doc(ctx.firestore(), 'characters', slot.characterId), { gameAccountId });
    }
  });
  // This must succeed under the candidate before cleanup failures are meaningful.
  if (!active) await assertSucceeds(lifecycle(db, 'complete', { ownershipSnapshot: true }));
  const targetIndex = originalSlots.findIndex(s => s.playerId === 'player-2');
  const target = originalSlots[targetIndex];
  const observedOwnershipRevision = returned ? 3 : 2;
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, 'authBindings', 'cleanup-third-auth'), { playerId: 'player-extra-1', status: 'active' });
    for (const ref of active ? [] : [doc(admin, 'characters', target.characterId), doc(admin, 'gameAccounts', `de-account-${target.playerId}`)]) {
      await updateDoc(ref, { ownerPlayerId: returned ? target.playerId : 'new-owner', ownershipRevision: observedOwnershipRevision });
    }
    if (scenario === 'other-state') await updateDoc(doc(admin, 'players', target.playerId, 'raidStates', `${target.characterId}_${raidId}`),
      { recruitmentId: 'newer-room', ownershipRevision: 9, status: 'active' });
    if (scenario === 'missing-state') await deleteDoc(doc(admin, 'players', target.playerId, 'raidStates', `${target.characterId}_${raidId}`));
  });
  const room = (await inspectAll(env)).room;
  return { commandId: 'cleanup-proof-command', expectedRevision: room.revision, targetIndex,
    actorIndex: 0, observedOwnershipRevision, actor: self ? target.playerId : playerId,
    targetPlayerId: target.playerId, targetCharacterId: target.characterId };
}
async function cleanup(client, request, tamper = null) {
  return runTransaction(client, async tx => {
    const ref = doc(client, 'recruitments', recruitmentId);
    const room = (await tx.get(ref)).data();
    const target = room.partySlots.find(s => s.playerId === request.targetPlayerId);
    const eventRef = doc(client, 'partyEvents', request.commandId);
    if (!target) {
      const event = (await tx.get(eventRef)).data();
      assert.ok(event && event.type === 'ownershipParticipantRemoved'
        && event.recruitmentId === recruitmentId && event.commandId === request.commandId
        && event.expectedRevision === request.expectedRevision
        && event.actorPlayerId === request.actor && event.targetPlayerId === request.targetPlayerId
        && event.targetCharacterId === request.targetCharacterId
        && event.observedOwnershipRevision === request.observedOwnershipRevision, 'retry operation mismatch');
      return 'already-applied';
    }
    const remaining = room.partySlots.filter(s => s.playerId !== target.playerId);
    if (tamper === 'remaining-slot') remaining[0] = { ...remaining[0], characterId: 'forged-character' };
    const composition = {
      partySlots: remaining, memberPlayerIds: remaining.map(s => s.playerId), memberCount: remaining.length,
      raidStateTargets: room.raidStateTargets.filter(s => s.playerId !== target.playerId),
      dealerCount: remaining.filter(s => s.role === 'dealer').length,
      supportCount: remaining.filter(s => s.role === 'support').length,
      nonGroupMemberCount: room.nonGroupMemberCount - (target.countedAsNonGroupMember ? 1 : 0), hasAvailableSlot: true,
    };
    const nextRevision = room.revision + 1;
    tx.update(ref, { ...composition, revision: nextRevision, updatedAt: serverTimestamp(),
      commandTargets: [], lastCommandType: 'cleanupCompletedOwnership', lastCommandId: request.commandId,
      lastCommandActorPlayerId: request.actor, lastCommandAt: serverTimestamp(), ownershipCleanup: {
        expectedRevision: request.expectedRevision, targetIndex: request.targetIndex,
        actorIndex: request.actorIndex, observedOwnershipRevision: request.observedOwnershipRevision,
      } });
    if (tamper !== 'omit-member') tx.delete(doc(client, 'recruitments', recruitmentId, 'members', target.playerId));
    if (tamper !== 'omit-listing') tx.update(doc(client, 'groups', room.groupId, 'raidListings', recruitmentId), {
      ...composition, sourceRevision: nextRevision, updatedAt: serverTimestamp(),
      ...(tamper === 'listing-count' ? { memberCount: 99 } : {}),
    });
    if (tamper !== 'omit-event') tx.set(eventRef, { schemaVersion: 1, eventId: request.commandId, commandId: request.commandId,
      recruitmentId, type: 'ownershipParticipantRemoved', commandRevision: nextRevision,
      expectedRevision: room.revision, actorPlayerId: request.actor, targetPlayerId: target.playerId,
      targetCharacterId: target.characterId, observedOwnershipRevision: request.observedOwnershipRevision,
      audiencePlayerIds: room.memberPlayerIds, occurredAt: serverTimestamp(),
      ...(tamper === 'event-target' ? { targetPlayerId: 'forged-player' } : {}),
    });
    const stateRef = doc(client, 'players', target.playerId, 'raidStates', `${target.characterId}_${raidId}`);
    if (tamper === 'delete-state') tx.delete(stateRef);
    if (tamper === 'change-state') tx.update(stateRef, { ownershipRevision: 99 });
    return 'applied';
  });
}
try {
  for (const self of [false, true]) await check(`preserve active ${self ? 'leave' : 'kick'}`, async () => {
    const request = await seed({ active: true, self }), before = await snapshot();
    await assertSucceeds(removeApprovedMemberTxn(self ? selfDb : db, request.actor));
    const after = await snapshot();
    assert.equal(after.room.memberCount, 7);
    assert.equal(after.states[request.targetIndex], null);
    assert.deepEqual(after.states.filter((_, i) => i !== request.targetIndex), before.states.filter((_, i) => i !== request.targetIndex));
    assert.deepEqual(after.groupMembers, before.groupMembers);
    assert.equal(after.listing.sourceRevision, after.room.revision);
  });
  for (const [name, options] of [['leader removal', {}], ['former self removal', { self: true }],
    ['returned owner removal', { returned: true }], ['preserve newer-room state', { scenario: 'other-state' }],
    ['preserve absent state', { scenario: 'missing-state' }]]) {
    await check(name, async () => {
      const request = await seed(options), before = await snapshot();
      const client = options.self ? selfDb : db;
      assert.equal(await assertSucceeds(cleanup(client, request)), 'applied');
      const after = await snapshot();
      assert.equal(after.room.memberCount, 7);
      assert.equal(after.members.length, before.members.length - 1);
      assert.deepEqual(after.states, before.states, 'all original states, including removed target, preserved');
      assert.deepEqual(after.events.filter(e => e.id !== request.commandId), before.events);
      assert.deepEqual(after.group, before.group);
      assert.deepEqual(after.groupMembers, before.groupMembers);
      assert.deepEqual(after.listing.partySlots, after.room.partySlots);
      assert.equal(after.listing.sourceRevision, after.room.revision);
      assert.equal(await cleanup(client, request), 'already-applied');
      assert.deepEqual(await snapshot(), after, 'retry makes no writes');
      await assert.rejects(cleanup(client, { ...request, observedOwnershipRevision: 99 }), /retry operation mismatch/);
      assert.deepEqual(await snapshot(), after);
      if (name === 'leader removal') {
        await assertSucceeds(lifecycle(db, 'advanceCycle', { ownershipSnapshot: true }));
        const next = await snapshot();
        assert.equal(next.room.memberCount, 7);
        assert.deepEqual(next.states[request.targetIndex], before.states[request.targetIndex]);
        assert.ok(next.states.filter((_, i) => i !== request.targetIndex).every(s => s.status === 'active'));
      }
    });
  }
  if (results.every(r => r.passed)) {
    for (const scenario of ['unchanged-owner', 'missing-character', 'missing-account', 'account-mismatch', 'null-owner', 'empty-owner', 'stale-leader',
      'stale-revision', 'stale-generation', 'third-party', 'leader-target', 'omit-member', 'omit-listing', 'omit-event',
      'listing-count', 'event-target', 'remaining-slot', 'delete-state', 'change-state']) {
      await check(`reject ${scenario} atomically`, async () => {
        const request = await seed({ self: ['delete-state', 'change-state'].includes(scenario) });
        await env.withSecurityRulesDisabled(async ctx => {
          const admin = ctx.firestore();
          const charRef = doc(admin, 'characters', request.targetCharacterId);
          const accountRef = doc(admin, 'gameAccounts', `de-account-${request.targetPlayerId}`);
          if (scenario === 'unchanged-owner') for (const ref of [charRef, accountRef]) await updateDoc(ref, { ownerPlayerId: request.targetPlayerId, ownershipRevision: 1 });
          if (scenario === 'missing-character') await deleteDoc(charRef);
          if (scenario === 'missing-account') await deleteDoc(accountRef);
          if (scenario === 'account-mismatch') await updateDoc(accountRef, { ownershipRevision: 3 });
          if (['null-owner', 'empty-owner'].includes(scenario)) for (const ref of [charRef, accountRef]) {
            await updateDoc(ref, { ownerPlayerId: scenario === 'null-owner' ? null : '' });
          }
          if (scenario === 'stale-leader') await updateDoc(doc(admin, 'characters', originalSlots[0].characterId), { ownerPlayerId: 'other', ownershipRevision: 2 });
        });
        if (scenario === 'stale-revision') request.expectedRevision--;
        if (scenario === 'stale-generation') request.observedOwnershipRevision--;
        if (scenario === 'third-party') request.actor = 'player-extra-1';
        if (scenario === 'leader-target') Object.assign(request, { targetIndex: 0, targetPlayerId: playerId, targetCharacterId: originalSlots[0].characterId });
        const before = await snapshot();
        const client = scenario === 'third-party' ? thirdDb : request.actor === 'player-2' ? selfDb : db;
        await assertSucceeds(getDoc(doc(client, 'recruitments', recruitmentId)));
        await assertFails(cleanup(client, request, scenario));
        assert.deepEqual(await snapshot(), before);
      });
    }
  } else console.log('SKIP CLEANUP: negative security claims gated on all positive cases');
  if (extension && results.every(r => r.passed)) await extension({ env, db, selfDb, thirdDb, seed, snapshot, cleanup, check, getSlots: () => originalSlots });
} finally {
  fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
  await env.cleanup();
}
if (results.some(r => !r.passed)) process.exitCode = 1;

return results;
}
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) await runCleanupProof();
