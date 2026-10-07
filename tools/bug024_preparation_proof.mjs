// Uses only a demo Emulator and the exact tracked deployment Rules.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, collection, getDocs, getDoc, setDoc, updateDoc, deleteDoc,
  runTransaction, serverTimestamp, increment, deleteField, Timestamp } from 'firebase/firestore';
import { authUid, playerId, recruitmentId, raidId, cycleKey, cycleWindow,
  seedGroupLinkedRoom } from './party_group_cutover_rules_test.mjs';
process.env.ROSTER_TRACKED_RULES = '1';
process.env.ROSTER_COMPLEXITY_RULES_FILE = 'firestore.rules';
const { seedRoom, lifecycle } = await import('./roster_ownership_rules_proof.mjs');
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
  firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync('firestore.rules', 'utf8') } });
const db = env.authenticatedContext(authUid).firestore();
const replacement = 'bug024replacement001';
const second = 'bug024replacement002';
const results = [];
async function admin(work) { return env.withSecurityRulesDisabled(ctx => work(ctx.firestore())); }
async function snapshot() {
  return admin(async adb => {
    const read = async (...parts) => (await getDocs(collection(adb, ...parts))).docs
      .map(d => ({ id: d.id, ...d.data() })).sort((a, b) => a.id.localeCompare(b.id));
    const room = (await getDoc(doc(adb, 'recruitments', recruitmentId))).data();
    return { room, members: await read('recruitments', recruitmentId, 'members'),
      events: await read('partyEvents'), listing: (await getDoc(doc(adb, 'groups', room.groupId, 'raidListings', recruitmentId))).data(),
      states: await Promise.all(room.memberPlayerIds.map(p => read('players', p, 'raidStates'))),
      claims: await Promise.all(room.memberPlayerIds.map(p => read('players', p, 'weeklyRaidClaims'))) };
  });
}
async function seed({ targetState = 'absent', missingListing = false } = {}) {
  await seedRoom(env, db);
  await seedGroupLinkedRoom(env, db);
  await admin(async adb => {
    const room = (await getDoc(doc(adb, 'recruitments', recruitmentId))).data();
    for (const slot of room.partySlots) {
      const cRef = doc(adb, 'characters', slot.characterId);
      const accountId = `bug024-account-${slot.playerId}`;
      await setDoc(doc(adb, 'gameAccounts', accountId), { ownerPlayerId: slot.playerId, status: 'active', ownershipRevision: 1 });
      await updateDoc(cRef, { gameAccountId: accountId });
      await updateDoc(doc(adb, 'recruitments', recruitmentId, 'members', slot.playerId), { ownershipRevision: 1 });
      await updateDoc(doc(adb, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`), { role: slot.role });
    }
    const c = (await getDoc(doc(adb, 'characters', room.partySlots[0].characterId))).data();
    for (const id of [replacement, second]) await setDoc(doc(adb, 'characters', id), {
      ...c, characterId: id, characterName: id, characterClassName: room.partySlots[0].classKey,
    });
  });
  await lifecycle(db, 'complete', { completionRole: true });
  await admin(async adb => {
    const room = (await getDoc(doc(adb, 'recruitments', recruitmentId))).data();
    if (targetState !== 'absent') {
      const original = (await getDoc(doc(adb, 'players', playerId, 'raidStates', `${room.partySlots[0].characterId}_${raidId}`))).data();
      const state = { ...original, characterId: replacement,
        recruitmentId: targetState.startsWith('foreign') ? 'another-room' : recruitmentId,
        difficultyId: targetState === 'foreign-role' ? 'hard' : original.difficultyId,
        role: targetState === 'foreign-role' ? 'support' : original.role,
        source: targetState === 'manual' ? 'manual' : 'party',
        status: targetState === 'active' ? 'active' : 'completed',
        cycleKey: targetState === 'current' ? cycleKey : original.cycleKey };
      if (targetState === 'manual') state.recruitmentId = null;
      await setDoc(doc(adb, 'players', playerId, 'raidStates', `${replacement}_${raidId}`), state);
    }
    if (missingListing) await deleteDoc(doc(adb, 'groups', room.groupId, 'raidListings', recruitmentId));
  });
}
async function prepare({ id = replacement, omit = null, tamper = null, expectedRevision = null, client = db } = {}) {
  return runTransaction(client, async tx => {
    const roomRef = doc(db, 'recruitments', recruitmentId);
    const before = (await tx.get(roomRef)).data();
    const memberRef = doc(db, 'recruitments', recruitmentId, 'members', playerId);
    const member = (await tx.get(memberRef)).data();
    const nextRevision = expectedRevision ?? before.revision + 1;
    const patch = { partySlots: before.partySlots.map(s => s.playerId === playerId ? { ...s, characterId: id } : s),
      raidStateTargets: before.raidStateTargets.map(t => t.playerId === playerId ? { ...t, stateId: `${id}_${raidId}` } : t),
      leaderCharacterNameSnapshot: id, leaderClassNameSnapshot: member.classNameSnapshot,
      revision: nextRevision, updatedAt: serverTimestamp(),
      commandTargets: [], lastCommandId: null, lastCommandType: null, lastCommandActorPlayerId: null, lastCommandAt: null };
    const memberPatch = { characterId: id, characterNameSnapshot: id, characterChangedAt: serverTimestamp(), updatedAt: serverTimestamp() };
    if (tamper === 'privilege') memberPatch.canApproveApplications = !member.canApproveApplications;
    if (tamper === 'other-slot') patch.partySlots[7] = { ...patch.partySlots[7], characterId: id };
    if (tamper === 'complete-status') patch.currentCycleStatus = 'active';
    if (omit !== 'room') tx.update(roomRef, patch);
    if (omit !== 'member') tx.update(memberRef, memberPatch);
    if (omit !== 'listing') tx.set(doc(db, 'groups', before.groupId, 'raidListings', recruitmentId), { ...before, ...patch });
    if (omit !== 'event') {
      const eventId = `characterChanged_${recruitmentId}_${nextRevision}`;
      tx.set(doc(db, 'partyEvents', eventId), { schemaVersion: 1, eventId, recruitmentId,
        type: 'characterChanged', commandId: eventId, commandRevision: nextRevision,
        audiencePlayerIds: before.memberPlayerIds, actorPlayerId: playerId, occurredAt: serverTimestamp() });
    }
    if (tamper === 'delete-old') tx.delete(doc(db, 'players', playerId, 'raidStates', `${member.characterId}_${raidId}`));
    if (tamper === 'delete-new') tx.delete(doc(db, 'players', playerId, 'raidStates', `${id}_${raidId}`));
    if (tamper === 'write-new') tx.set(doc(db, 'players', playerId, 'raidStates', `${id}_${raidId}`), { status: 'active' });
    if (tamper === 'delete-claim') tx.delete(doc(db, 'players', playerId, 'weeklyRaidClaims', `${before.currentCycleKey}_${id}_${raidId}`));
  });
}
async function advance({ omit = false, staleRevision = false } = {}) {
  return runTransaction(db, async tx => {
    const ref = doc(db, 'recruitments', recruitmentId);
    const room = (await tx.get(ref)).data();
    const window = cycleWindow(cycleKey);
    const eventId = `advanceCycle_${recruitmentId}_${room.revision}`;
    const patch = { status: 'active', currentCycleStatus: 'active', currentCycleKey: cycleKey, targetCycleKey: cycleKey,
      cycleStartedAt: Timestamp.fromDate(window.startedAt), cycleEndsAt: Timestamp.fromDate(window.endsAt),
      completedAt: null, completedByPlayerId: null, commandTargets: room.raidStateTargets,
      revision: room.revision + (staleRevision ? 0 : 1), lastCommandId: eventId, lastCommandType: 'advanceCycle',
      lastCommandActorPlayerId: playerId, lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp() };
    tx.update(ref, patch);
    tx.update(doc(db, 'groups', room.groupId, 'raidListings', recruitmentId), { ...room, ...patch, sourceRevision: patch.revision });
    for (const [index, slot] of room.partySlots.entries()) {
      if (omit && index === 7) continue;
      tx.set(doc(db, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`), {
        schemaVersion: 1, playerId: slot.playerId, characterId: slot.characterId,
        ownershipRevision: slot.ownershipRevision, raidId, difficultyId: room.difficultyId,
        recruitmentId, role: slot.role, source: 'party', status: 'active', cycleKey,
        revision: increment(1), updatedAt: serverTimestamp(), completedAt: deleteField(),
      }, { merge: true });
    }
    tx.set(doc(db, 'partyEvents', eventId), { schemaVersion: 1, eventId, recruitmentId,
      type: 'advanceCycle', commandId: eventId, commandRevision: patch.revision,
      audiencePlayerIds: room.memberPlayerIds, actorPlayerId: playerId, occurredAt: serverTimestamp() });
  });
}
async function denied(work) {
  const before = await snapshot();
  await assert.rejects(work, error => error.code === 'permission-denied');
  assert.deepEqual(await snapshot(), before, 'rejected operation must be atomic');
}
async function check(name, work) {
  try { await work(); results.push({ name, passed: true }); console.log(`PASS BUG024 ${name}`); }
  catch (e) { results.push({ name, passed: false, error: e.message }); console.error(`FAIL BUG024 ${name}: ${e.message}`); }
}
try {
  await check('8-member preparation preserves states/claims/completion event, repeated changes', async () => {
    await seed(); const before = await snapshot();
    await prepare(); await prepare({ id: second }); await prepare({ id: replacement });
    const after = await snapshot();
    assert.deepEqual(after.states, before.states); assert.deepEqual(after.claims, before.claims);
    assert.deepEqual(after.room.completedAt, before.room.completedAt);
    assert.deepEqual(after.events.filter(e => e.type === 'complete'), before.events.filter(e => e.type === 'complete'));
    assert.deepEqual(after.listing, after.room);
    await advance(); await lifecycle(db, 'complete', { completionRole: true });
  });
  for (const targetState of ['same', 'foreign', 'foreign-role', 'manual']) {
    await check(`prepare/advance/complete with ${targetState} prior completed state`, async () => {
      await seed({ targetState }); const before = await snapshot();
      await prepare(); assert.deepEqual((await snapshot()).states, before.states);
      await advance(); await lifecycle(db, 'complete', { completionRole: true });
    });
  }
  for (const omit of ['room', 'member', 'listing', 'event']) await check(`reject missing ${omit}`, async () => {
    await seed(); await denied(() => prepare({ omit }));
  });
  for (const tamper of ['privilege', 'other-slot', 'complete-status', 'delete-old', 'delete-new', 'write-new']) await check(`reject ${tamper}`, async () => {
    await seed({ targetState: 'same' }); await denied(() => prepare({ tamper }));
  });
  await check('reject missing listing without recreating it', async () => { await seed({ missingListing: true }); await denied(() => prepare()); });
  await check('reject occupied target', async () => { await seed({ targetState: 'active' }); await denied(() => prepare()); });
  await check('reject another player mutation', async () => {
    await seed(); await denied(() => prepare({ client: env.authenticatedContext('joiner-auth').firestore() }));
  });
  await check('reject source ownership lost', async () => {
    await seed(); await admin(async adb => {
      const room = (await getDoc(doc(adb, 'recruitments', recruitmentId))).data();
      await updateDoc(doc(adb, 'characters', room.partySlots[0].characterId), { ownershipRevision: 2 });
    }); await denied(() => prepare());
  });
  await check('reject stale preparation revision', async () => { await seed(); await denied(() => prepare({ expectedRevision: 1 })); });
  await check('reject current completed overwrite at advance', async () => { await seed({ targetState: 'current' }); await prepare(); await denied(() => advance()); });
  await check('reject target ownership lost at advance', async () => {
    await seed(); await prepare(); await admin(adb => updateDoc(doc(adb, 'characters', replacement), { ownershipRevision: 2 })); await denied(() => advance());
  });
  await check('reject other room occupancy acquired after preparation', async () => {
    await seed({ targetState: 'foreign' }); await prepare();
    await admin(adb => updateDoc(doc(adb, 'players', playerId, 'raidStates', `${replacement}_${raidId}`), { status: 'active' })); await denied(() => advance());
  });
  await check('reject partial/stale advance', async () => { await seed(); await prepare(); await denied(() => advance({ omit: true })); await denied(() => advance({ staleRevision: true })); });
} finally { await env.cleanup(); }
fs.mkdirSync('coverage/bug024', { recursive: true });
fs.writeFileSync('coverage/bug024/results.json', JSON.stringify(results, null, 2));
assert.ok(results.every(r => r.passed), `${results.filter(r => !r.passed).length} BUG024 failures`);
console.log(`BUG024: ${results.length} passed; demo Emulator only.`);
