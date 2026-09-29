// DE2 feasibility only. Never deploys or edits tracked production Rules.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, runTransaction,
  serverTimestamp, Timestamp, increment, deleteField } from 'firebase/firestore';
import { seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn,
  approvePublicApplicationTxn, seedExpandedApprovedRoom, cycleWindow,
  offsetCycleKey, cycleKey, authUid, playerId, characterId, recruitmentId, raidId,
} from './party_group_cutover_rules_test.mjs';

const tracked = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const anchor = '&& atomicTargetStateMatches(\n            data,';
assert.equal(tracked.split(anchor).length, 2, 'production hook must be unique');
// Test-only candidate: one Character read per target, at the aggregate validator.
// Slot snapshots are fixture metadata; this is not a deployable schema migration.
const candidate = tracked.replace(anchor, `&& deOwnershipTargetCurrent(data, index)
          ${anchor}`).replace('    function atomicTargetMatchesTransition(data, index) {', `
    function deOwnershipTargetCurrent(data, index) {
      let slot = data.partySlots[index];
      let character = get(/databases/$(database)/documents/characters/$(slot.characterId)).data;
      return character.ownerPlayerId == slot.playerId
        && character.ownershipRevision == slot.ownershipRevision;
    }
    function atomicTargetMatchesTransition(data, index) {`);

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
        { cycleKey: pastKey });
    }
  });
}

async function lifecycle(db, type) {
  return runTransaction(db, async tx => {
    const ref = doc(db, 'recruitments', recruitmentId);
    const room = (await tx.get(ref)).data();
    const eventId = `${type}_${recruitmentId}_${room.revision}`;
    const patch = {
      commandTargets: room.raidStateTargets, revision: room.revision + 1,
      lastCommandId: eventId, lastCommandType: type, lastCommandActorPlayerId: playerId,
      lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
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
    for (const slot of room.partySlots) {
      tx.update(doc(db, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`), {
        status: type === 'complete' ? 'completed' : 'active', source: 'party',
        cycleKey: type === 'complete' ? room.currentCycleKey : cycleKey,
        revision: increment(1), updatedAt: serverTimestamp(),
        completedAt: type === 'complete' ? serverTimestamp() : deleteField(),
      });
    }
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type, commandId: eventId,
      commandRevision: room.revision + 1, audiencePlayerIds: room.memberPlayerIds,
      actorPlayerId: playerId, occurredAt: serverTimestamp(),
    });
  });
}

async function inspectAll(env) {
  return env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    const room = (await getDoc(doc(db, 'recruitments', recruitmentId))).data();
    const states = await Promise.all(room.partySlots.map(async slot =>
      (await getDoc(doc(db, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`))).data()));
    return { room, states };
  });
}

for (const [label, rules] of [['baseline', tracked], ['candidate', candidate]]) {
  const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
    firestore: { rules, host: '127.0.0.1', port: 8080 } });
  const db = env.authenticatedContext(authUid).firestore();
  try {
    for (const type of ['complete', 'advanceCycle']) {
      await seedRoom(env, db);
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
    }
    await seedRoom(env, db);
    const before = await inspectAll(env);
    const target = before.room.partySlots.at(-1);
    const targetRef = doc(db, 'players', target.playerId, 'raidStates', `${target.characterId}_${raidId}`);
    await assertFails(getDoc(targetRef));
    await assertFails(deleteDoc(targetRef));
    assert.deepEqual(await inspectAll(env), before);
    console.log(`PASS ${label}: private state read/delete remain protected`);
  } finally { await env.cleanup(); }
}
console.log('DE2 proof finished; no production Rules or data modified.');
