// DE2 feasibility only. Never deploys or edits tracked production Rules.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, runTransaction,
  serverTimestamp, Timestamp, increment, deleteField } from 'firebase/firestore';
import { seedGroupLinkedRoom, disbandApprovedRoomTxn, removeApprovedMemberTxn, seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn,
  approvePublicApplicationTxn, seedExpandedApprovedRoom, cycleWindow,
  offsetCycleKey, cycleKey, authUid, playerId, characterId, recruitmentId, raidId,
} from './party_group_cutover_rules_test.mjs';

const currentTracked = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const tracked = currentTracked.startsWith('// roster-reauth-integrated-v1')
  ? fs.readFileSync(new URL('./fixtures/roster_reauth_preintegration.rules', import.meta.url), 'utf8').replace(/\r\n/g, '\n')
  : currentTracked;
const anchor = 'return atomicIsLifecycleCommand(recruitment)\n        && newData.playerId == playerId';
assert.equal(tracked.split(anchor).length, 2, 'production hook must be unique');
// Second candidate: each updated state checks only its own Character. The
// aggregate-wide variant failed the 8-member expression budget in CI 36581337818.
// Missing-state creation and schema migration are deliberately not implemented.
const ownershipCandidate = tracked.replace(anchor, `return atomicIsLifecycleCommand(recruitment)
        && deOwnershipStateCurrent(playerId, oldData)
        && newData.playerId == playerId`).replace('    function validAtomicRaidStateUpdate(', `
    function deOwnershipStateCurrent(playerId, state) {
      let character = get(/databases/$(database)/documents/characters/$(state.characterId)).data;
      return character.ownerPlayerId == playerId
        && character.ownershipRevision == state.ownershipRevision;
    }
    function validAtomicRaidStateUpdate(`);

// DE2-B: target maps contain exactly playerId/stateId. Replace eight repeated
// function calls per state with exact map membership; preserve the <=8 bound.
const includesStart = ownershipCandidate.indexOf('    function atomicCommandIncludes(');
const includesEnd = ownershipCandidate.indexOf('    function atomicAdvanceStateMatchesSlotAt(', includesStart);
assert.ok(includesStart >= 0 && includesEnd > includesStart);
const directTargets = ownershipCandidate.slice(0, includesStart) + `
    function atomicCommandIncludes(data, playerId, stateId) {
      return data.commandTargets.size() <= 8
        && data.commandTargets.hasAny([{'playerId': playerId, 'stateId': stateId}]);
    }

` + ownershipCandidate.slice(includesEnd);
const slotStart = directTargets.indexOf('    function atomicAdvanceStateMatchesSlot(recruitment, data) {');
const slotEnd = directTargets.indexOf('    function validAtomicAdvanceRaidStateCreate(', slotStart);
assert.ok(slotStart >= 0 && slotEnd > slotStart);
const slotCandidate = directTargets.slice(0, slotStart) + `
    function atomicAdvanceStateMatchesSlot(recruitment, data) {
      let slots = recruitment.partySlots;
      let count = slots.size();
      let index = count > 0 && slots[0].playerId == data.playerId ? 0
        : count > 1 && slots[1].playerId == data.playerId ? 1
        : count > 2 && slots[2].playerId == data.playerId ? 2
        : count > 3 && slots[3].playerId == data.playerId ? 3
        : count > 4 && slots[4].playerId == data.playerId ? 4
        : count > 5 && slots[5].playerId == data.playerId ? 5
        : count > 6 && slots[6].playerId == data.playerId ? 6
        : count > 7 && slots[7].playerId == data.playerId ? 7 : -1;
      return index >= 0 && count <= 8
        && slots[index].characterId == data.characterId
        && slots[index].role == data.role;
    }

` + directTargets.slice(slotEnd);
// Different approach after lookup-only candidates failed: bypass unrelated
// validators using discriminators already required inside those validators.
const candidate = slotCandidate
  .replace('allow update: if validPersonalRaidStateCompletion(',
    "allow update: if (request.resource.data.source == 'manual' && validPersonalRaidStateCompletion(")
  .replace(') || validAtomicRaidStateUpdate(', ') ) || validAtomicRaidStateUpdate(')
  .replace('allow update: if (personalCompletionCommandMarker(request.resource.data)',
    'allow update: if (atomicIsLifecycleCommand(request.resource.data) && validAtomicLifecycleUpdate(resource.data, request.resource.data)) || (personalCompletionCommandMarker(request.resource.data)')
  .replace('allow create: if validAtomicMembershipPartyEvent(request.resource.data)',
    "allow create: if ((request.resource.data.type == 'complete' || request.resource.data.type == 'advanceCycle') && validAtomicLifecyclePartyEvent(request.resource.data)) || validAtomicMembershipPartyEvent(request.resource.data)");

async function seedRoom(env, db) {
  await env.clearFirestore();
  await seedBase(env);
  await seedJoiner(env);
  await assertSucceeds(createPublicRecruitmentTxn(db));
  await assertSucceeds(applicationTxn(env.authenticatedContext('joiner-auth').firestore(), 'create'));
  await assertSucceeds(approvePublicApplicationTxn(db));
  await seedExpandedApprovedRoom(env, 8);
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    const ref = doc(admin, 'recruitments', recruitmentId);
    const room = (await getDoc(ref)).data();
    const pastKey = offsetCycleKey(cycleKey, -7);
    const window = cycleWindow(pastKey);
    await updateDoc(ref, {
      continueTogether: true, currentCycleKey: pastKey, targetCycleKey: pastKey,
      cycleStartedAt: Timestamp.fromDate(window.startedAt),
      cycleEndsAt: Timestamp.fromDate(window.endsAt),
      partySlots: room.partySlots.map(slot => ({ ...slot, ownershipRevision: 1 })),
    });
    for (const slot of room.partySlots) {
      await setDoc(doc(admin, 'characters', slot.characterId), {
        ownerPlayerId: slot.playerId, ownershipRevision: 1, status: 'active',
      }, { merge: true });
      await updateDoc(doc(admin, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`),
        { cycleKey: pastKey, difficultyId: 'normal', ownershipRevision: 1 });
    }
  });
}

async function lifecycle(db, type, { tamper = null, actorPlayerId = playerId, ownershipSnapshot = false } = {}) {
  return runTransaction(db, async tx => {
    const ref = doc(db, 'recruitments', recruitmentId);
    const room = (await tx.get(ref)).data();
    const eventId = `${type}_${recruitmentId}_${room.revision}`;
    const patch = {
      commandTargets: room.raidStateTargets, revision: room.revision + 1,
      lastCommandId: eventId, lastCommandType: type, lastCommandActorPlayerId: actorPlayerId,
      lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    if (tamper === 'slot-revision') patch.partySlots = room.partySlots.map((slot, index) =>
      index === room.partySlots.length - 1 ? { ...slot, ownershipRevision: 3 } : slot);
    if (tamper === 'target-player') patch.commandTargets = room.raidStateTargets.map((target, index) =>
      index === room.raidStateTargets.length - 1 ? { ...target, playerId: 'forged-player' } : target);
    if (tamper === 'target-state') patch.commandTargets = room.raidStateTargets.map((target, index) =>
      index === room.raidStateTargets.length - 1 ? { ...target, stateId: room.raidStateTargets[0].stateId } : target);
    if (type === 'advanceCycle') {
      const window = cycleWindow(cycleKey);
      Object.assign(patch, { status: 'active', currentCycleStatus: 'active',
        currentCycleKey: cycleKey, targetCycleKey: cycleKey,
        cycleStartedAt: Timestamp.fromDate(window.startedAt), cycleEndsAt: Timestamp.fromDate(window.endsAt),
        completedAt: null, completedByPlayerId: null });
    } else {
      Object.assign(patch, { status: 'active', currentCycleStatus: 'completed',
        completedAt: serverTimestamp(), completedByPlayerId: playerId });
    }
    tx.update(ref, patch);
    if (room.groupId) {
      tx.update(doc(db, 'groups', room.groupId, 'raidListings', recruitmentId), {
        ...(type === 'advanceCycle' ? { ...room, ...patch } : {}),
        recruitmentId, status: patch.status, sourceRevision: room.revision + 1,
        updatedAt: serverTimestamp(),
      });
    }
    for (const slot of room.partySlots) {
      const isLast = slot === room.partySlots.at(-1);
      if (isLast && tamper === 'omit-state') continue;
      const stateRef = doc(db, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`);
      const statePatch = {
        ...(ownershipSnapshot && Object.hasOwn(slot, 'ownershipRevision') ? { ownershipRevision: slot.ownershipRevision } : {}),
        status: type === 'complete' ? 'completed' : 'active', source: 'party',
        cycleKey: type === 'complete' ? room.currentCycleKey : cycleKey,
        revision: increment(1), updatedAt: serverTimestamp(),
        completedAt: type === 'complete' ? serverTimestamp() : deleteField(),
        ...(isLast && tamper === 'role' ? { role: slot.role === 'support' ? 'dealer' : 'support' } : {}),
        ...(isLast && tamper === 'character' ? { characterId: 'forged-character' } : {}),
        ...(isLast && tamper === 'state-status' ? { status: type === 'complete' ? 'active' : 'completed' } : {}),
        ...(isLast && tamper === 'state-cycle' ? { cycleKey: offsetCycleKey(cycleKey, -14) } : {}),
        ...(isLast && tamper === 'state-recruitment' ? { recruitmentId: 'another-recruitment' } : {}),
        ...(isLast && tamper === 'revision-forged' ? { ownershipRevision: 3 } : {}),
        ...(isLast && tamper === 'revision-decreased' ? { ownershipRevision: 0 } : {}),
        ...(isLast && tamper === 'revision-deleted' ? { ownershipRevision: deleteField() } : {}),
      };
      if (type === 'advanceCycle') {
        // Match runtime _advanceRaidState + set(merge:true), not just update.
        tx.set(stateRef, { schemaVersion: 1, playerId: slot.playerId,
          characterId: slot.characterId, raidId: room.raidId, difficultyId: room.difficultyId,
          recruitmentId, role: slot.role, ...statePatch }, { merge: true });
      } else tx.update(stateRef, statePatch);
    }
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: type === 'complete' ? 2 : 1, eventId, recruitmentId, type, commandId: eventId,
      commandRevision: room.revision + 1, audiencePlayerIds: room.memberPlayerIds,
      actorPlayerId, occurredAt: serverTimestamp(),
      ...(type === 'complete' ? {
        raidId: room.raidId, difficultyId: room.difficultyId, cycleKey: room.currentCycleKey,
        completionTargets: room.partySlots.map(slot => ({ playerId: slot.playerId, characterId: slot.characterId })),
      } : {}),
    });
  });
}

async function inspectAll(env) {
  let result;
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    const room = (await getDoc(doc(db, 'recruitments', recruitmentId))).data();
    const states = await Promise.all(room.partySlots.map(async slot =>
      (await getDoc(doc(db, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`))).data()));
    const listing = room.groupId
      ? (await getDoc(doc(db, 'groups', room.groupId, 'raidListings', recruitmentId))).data() : null;
    result = { room, states, listing };
  });
  return result;
}

async function runProof() {
const failures = [];
async function check(name, action) {
  try { await action(); }
  catch (error) {
    failures.push(name);
    console.error(`PROOF FAILURE ${name}:`, error.message);
  }
}
for (const [label, rules] of [['baseline', tracked], ['candidate', candidate]]) {
  const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
    firestore: { rules, host: '127.0.0.1', port: 8080 } });
  const db = env.authenticatedContext(authUid).firestore();
  try {
    for (const type of ['complete', 'advanceCycle']) {
      await check(`${label} ${type}`, async () => {
      await seedRoom(env, db);
      if (label === 'baseline' && type === 'advanceCycle') {
        const before = await inspectAll(env);
        try { await lifecycle(db, type); console.log('BASELINE observation: 8-member advance now succeeds'); }
        catch (error) {
          assert.match(error.message, /maximum of 1000 expressions/, 'unexpected baseline failure');
          assert.deepEqual(await inspectAll(env), before);
          console.log('BASELINE KNOWN LIMIT: 8-member advance expression budget; not a passing production flow');
        }
        return;
      }
      await assertSucceeds(lifecycle(db, type));
      console.log(`PASS ${label}: valid 8-member ${type}`);
      for (const returned of [false, true]) {
        await seedRoom(env, db);
        const before = await inspectAll(env);
        // Last target tests the maximum traversal; A->B->A retains A with epoch 3.
        const target = before.room.partySlots.at(-1);
        await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'characters', target.characterId), {
          ownerPlayerId: returned ? target.playerId : 'new-owner', ownershipRevision: returned ? 3 : 2,
        }));
        if (label === 'baseline') await assertSucceeds(lifecycle(db, type));
        else {
          await assertFails(lifecycle(db, type));
          assert.deepEqual(await inspectAll(env), before, 'rejected lifecycle must preserve all states');
        }
        console.log(`PASS ${label}: ${type} ${returned ? 'A-B-A' : 'ownership changed'} ${label === 'baseline' ? 'currently allowed' : 'rejected atomically'}`);
      }
      });
    }
    if (label === 'candidate') {
      for (const tamper of ['role', 'character', 'omit-state', 'target-player', 'target-state']) {
        await check(`candidate advance tamper ${tamper}`, async () => {
          await seedRoom(env, db);
          const before = await inspectAll(env);
          await assertFails(lifecycle(db, 'advanceCycle', { tamper }));
          assert.deepEqual(await inspectAll(env), before);
          console.log(`PASS candidate: advance rejects ${tamper} atomically`);
        });
      }
      for (const type of ['complete', 'advanceCycle']) {
        await check(`candidate group ${type}`, async () => {
          await seedRoom(env, db);
          await seedGroupLinkedRoom(env, db);
          await assertSucceeds(lifecycle(db, type));
          const after = await inspectAll(env);
          assert.equal(after.listing.sourceRevision, after.room.revision);
          assert.equal(after.listing.status, after.room.status);
          if (type === 'advanceCycle') assert.deepEqual(after.listing.partySlots, after.room.partySlots);
          console.log(`PASS candidate: group 8-member ${type} and listing`);
        });
      }
      await check('candidate 8-member disband', async () => {
        await seedRoom(env, db);
        await assertSucceeds(disbandApprovedRoomTxn(db));
        const after = await inspectAll(env);
        assert.equal(after.room.status, 'disbanded');
        assert.ok(after.states.every(state => state === undefined));
        console.log('PASS candidate: shared target helper preserves 8-member disband');
      });
    }
    await check(`${label} active cleanup and private access`, async () => {
    await seedRoom(env, db);
    const before = await inspectAll(env);
    const target = before.room.partySlots.at(-1);
    const targetRef = doc(db, 'players', target.playerId, 'raidStates', `${target.characterId}_${raidId}`);
    await assertFails(getDoc(targetRef));
    await assertFails(deleteDoc(targetRef));
    assert.deepEqual(await inspectAll(env), before);
    console.log(`PASS ${label}: private state read/delete remain protected`);
    await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'characters', target.characterId), {
      ownerPlayerId: 'new-owner', ownershipRevision: 2,
    }));
    await assertSucceeds(removeApprovedMemberTxn(db, playerId, { targetPlayerId: target.playerId }));
    const removed = await inspectAll(env);
    assert.equal(removed.room.memberCount, 7);
    assert.equal(removed.room.partySlots.some(s => s.playerId === target.playerId), false);
    console.log(`PASS ${label}: existing leader can remove stale active member without private read`);
    });

    await check(`${label} replacement state protection`, async () => {
    await seedRoom(env, db);
    const preserved = await inspectAll(env);
    const moved = preserved.room.partySlots.at(-1);
    await env.withSecurityRulesDisabled(async ctx => {
      const admin = ctx.firestore();
      await setDoc(doc(admin, 'recruitments', 'newer-room'), {
        ...preserved.room, recruitmentId: 'newer-room',
      });
      await updateDoc(doc(admin, 'players', moved.playerId, 'raidStates', `${moved.characterId}_${raidId}`),
        { recruitmentId: 'newer-room', revision: 99 });
    });
    const beforeConflict = await inspectAll(env);
    await assertFails(removeApprovedMemberTxn(db, playerId, { targetPlayerId: moved.playerId }));
    assert.deepEqual(await inspectAll(env), beforeConflict);
    console.log(`PASS ${label}: different-room state blocks old removal atomically`);
    });

    await check(`${label} completed cleanup boundary`, async () => {
    await seedRoom(env, db);
    await assertSucceeds(lifecycle(db, 'complete'));
    const completed = await inspectAll(env);
    await assertFails(removeApprovedMemberTxn(db, playerId, { targetPlayerId: completed.room.partySlots.at(-1).playerId }));
    assert.deepEqual(await inspectAll(env), completed);
    console.log(`PASS ${label}: completed recurring-room removal needs a separate command`);
    });

    await check(`${label} new owner namespace`, async () => {
    await seedRoom(env, db);
    const oldUserState = await inspectAll(env);
    await env.withSecurityRulesDisabled(async ctx => {
      const admin = ctx.firestore();
      await setDoc(doc(admin, 'authBindings', 'new-owner-auth'), {
        schemaVersion: 1, playerId: 'new-owner', status: 'active', linkedAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
      await setDoc(doc(admin, 'players', 'new-owner'), { schemaVersion: 1, status: 'active' });
      await updateDoc(doc(admin, 'characters', characterId), { ownerPlayerId: 'new-owner', ownershipRevision: 2 });
      await setDoc(doc(admin, 'playerGameAccounts', 'new-owner_account-1'), {
        schemaVersion: 1, playerId: 'new-owner', gameAccountId: 'account-1', status: 'active',
        representativeCharacterId: characterId, updatedAt: Timestamp.now(),
      });
    });
    const newDb = env.authenticatedContext('new-owner-auth').firestore();
    await assertSucceeds(createPublicRecruitmentTxn(newDb, {
      id: 'new-owner-room', ownerPlayerId: 'new-owner', ownerCharacterId: characterId,
    }));
    assert.deepEqual(await inspectAll(env), oldUserState, 'new owner create must not mutate old room or state');
    console.log(`PASS ${label}: same Character new Player creates separate room while old state remains`);
    });
  } finally { await env.cleanup(); }
}
assert.deepEqual(failures, [], 'feasibility gates failed; do not treat partial PASS as full acceptance');
console.log('DE2 proof finished; no production Rules or data modified.');

}
export { seedRoom, lifecycle, inspectAll, ownershipCandidate };
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await runProof();
}
