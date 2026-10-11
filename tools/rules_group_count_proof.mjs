import assert from 'node:assert/strict';
import fs from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, runTransaction, serverTimestamp, increment, updateDoc,
  setDoc, Timestamp, collection, getDocs } from 'firebase/firestore';
import { seedBase, seedGroupLinkedRoom, createPublicRecruitmentTxn,
  completeActiveMemberTxn, authUid, playerId, characterId, recruitmentId } from './party_group_cutover_rules_test.mjs';
import { assertRulesDenied } from './assert_rules_denied.mjs';

process.env.RULES_AUDIT = '1';
assert.equal(process.env.R1_LISTING, '1');
assert.ok(process.env.PARTY_RULES_FILE);
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
  firestore: { host: '127.0.0.1', port: 8080,
    rules: fs.readFileSync(process.env.PARTY_RULES_FILE, 'utf8') } });
const db = env.authenticatedContext(authUid).firestore();
const source = doc(db, 'recruitments', recruitmentId);
const group = doc(db, 'groups', 'group-room-1');
const listing = doc(db, 'groups', 'group-room-1', 'raidListings', recruitmentId);
async function visibility(next, omitGroup = false) {
  await runTransaction(db, async tx => {
    const before = (await tx.get(source)).data();
    const count = (await tx.get(group)).data();
    const activeRecruitmentCount = count.activeRecruitmentCount + (next === 'group' ? 1 : -1);
    const patch = { visibility: next, groupActiveRecruitmentCountAfter: activeRecruitmentCount,
      revision: before.revision + 1, updatedAt: serverTimestamp() };
    tx.update(source, patch);
    if (!omitGroup) tx.update(group, { activeRecruitmentCount, lastRecruitmentId: recruitmentId,
      revision: count.revision + 1, updatedAt: serverTimestamp() });
    if (next === 'public') tx.delete(listing);
    else tx.set(listing, { ...before, ...patch });
  });
}
async function admin(work) {
  let result;
  await env.withSecurityRulesDisabled(async ctx => { result = await work(ctx.firestore()); });
  return result;
}
async function snapshot() {
  return admin(async db => {
    const paths = ['recruitments', 'partyEvents', 'groups',
      'groups/group-room-1/raidListings', `recruitments/${recruitmentId}/members`,
      `players/${playerId}/raidStates`];
    return Promise.all(paths.map(async path => (await getDocs(collection(db, path))).docs
      .map(d => ({ id: d.id, ...d.data() })).sort((a, b) => a.id.localeCompare(b.id))));
  });
}
async function seed({ count = 1, recurring = false, expired = false } = {}) {
  await env.clearFirestore();
  await seedBase(env);
  await admin(async db => {
    await updateDoc(doc(db, 'characters', characterId), { ownershipRevision: 1 });
    await updateDoc(doc(db, 'gameAccounts', 'account-1'), { ownershipRevision: 1 });
  });
  await createPublicRecruitmentTxn(db, { ownershipRevision: 1 });
  await seedGroupLinkedRoom(env, db, { activeRecruitmentCount: count });
  await admin(async db => {
    const ref = doc(db, source.path);
    const room = (await getDoc(ref)).data();
    for (const target of room.raidStateTargets) await updateDoc(
      doc(db, 'players', target.playerId, 'raidStates', target.stateId),
      { difficultyId: room.difficultyId, role: 'dealer' });
    await updateDoc(ref, { continueTogether: recurring,
      ...(expired ? { cycleEndsAt: Timestamp.fromMillis(Date.now() - 60000) } : {}) });
    await setDoc(doc(db, listing.path), (await getDoc(ref)).data());
  });
}
async function lifecycle(type, { forceClose = false, omitGroup = false } = {}) {
  await runTransaction(db, async tx => {
    const room = (await tx.get(source)).data();
    const closes = forceClose || (room.visibility === 'group' && room.status === 'active'
      && (type !== 'complete' || !room.continueTogether));
    const groupBefore = closes ? (await tx.get(group)).data() : null;
    const eventId = `${type}_${recruitmentId}_${room.revision}`;
    const targetless = type === 'incompleteEnd' || (type === 'disband' && room.currentCycleStatus === 'completed');
    const patch = { revision: room.revision + 1, commandTargets: targetless ? [] : room.raidStateTargets,
      lastCommandId: eventId, lastCommandType: type, lastCommandActorPlayerId: playerId,
      lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp(),
      ...(type === 'complete' ? { status: room.continueTogether ? 'active' : 'completed',
        currentCycleStatus: 'completed' } : { status: type === 'disband' ? 'disbanded' : 'incompleteEnded',
        manualRecruitmentEnabled: false, hasAvailableSlot: false }),
      ...(type === 'incompleteEnd' ? { currentCycleStatus: 'incompleteEnded' } : {}),
      ...(closes ? { groupActiveRecruitmentCountAfter: groupBefore.activeRecruitmentCount - 1 } : {}) };
    tx.update(source, patch);
    if (closes && !omitGroup) tx.update(group, {
      activeRecruitmentCount: groupBefore.activeRecruitmentCount - 1,
      lastRecruitmentId: recruitmentId, revision: groupBefore.revision + 1, updatedAt: serverTimestamp() });
    if (room.visibility === 'group') {
      if (patch.status !== 'active') tx.delete(listing);
      else tx.set(listing, { ...room, ...patch });
    }
    if (!targetless) for (const slot of room.partySlots) {
      const ref = doc(db, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${room.raidId}`);
      if (type === 'disband') tx.delete(ref);
      else tx.update(ref, { status: 'completed', completedAt: serverTimestamp(), role: slot.role,
        revision: increment(1), updatedAt: serverTimestamp() });
    }
    tx.set(doc(db, 'partyEvents', eventId), { schemaVersion: type === 'disband' ? 1 : 2,
      eventId, recruitmentId, type: type === 'incompleteEnd' ? 'partyIncompleteEnded' : type,
      commandId: eventId, commandRevision: room.revision + 1, audiencePlayerIds: room.memberPlayerIds,
      actorPlayerId: playerId, occurredAt: serverTimestamp(),
      ...(type !== 'disband' ? { raidId: room.raidId, difficultyId: room.difficultyId,
        cycleKey: room.currentCycleKey, completionTargets: room.partySlots.map(slot =>
          ({ playerId: slot.playerId, characterId: slot.characterId })) } : {}) });
  });
}
let passed = 0;
const pass = name => { passed++; console.log(`PASS COUNT: ${name}`); };
async function denied(name, action) {
  const before = await snapshot();
  await assertRulesDenied(action());
  assert.deepEqual(await snapshot(), before);
  pass(name);
}
try {
  for (const type of ['complete', 'disband', 'incompleteEnd', 'personalComplete']) {
    await seed({ expired: type === 'incompleteEnd' });
    await visibility('public');
    const before = (await getDoc(group)).data();
    assert.equal(before.activeRecruitmentCount, 0);
    if (type === 'personalComplete') await completeActiveMemberTxn(db, playerId, characterId);
    else await lifecycle(type);
    assert.deepEqual((await getDoc(group)).data(), before);
    assert.equal((await getDoc(listing)).exists(), false);
    pass(`public ${type} preserves closed group count`);
  }
  for (const type of ['complete', 'disband', 'incompleteEnd']) {
    await seed({ count: 3, expired: type === 'incompleteEnd' });
    await denied(`group ${type} requires count write`, () => lifecycle(type, { omitGroup: true }));
    await lifecycle(type);
    assert.equal((await getDoc(group)).data().activeRecruitmentCount, 2);
    pass(`group ${type} uses current count`);
    await seed({ count: 3, expired: type === 'incompleteEnd' });
    await visibility('public');
    await denied(`public ${type} rejects double decrement`, () => lifecycle(type, { forceClose: true }));
  }
  await seed({ count: 3 });
  await completeActiveMemberTxn(db, playerId, characterId);
  assert.equal((await getDoc(group)).data().activeRecruitmentCount, 2);
  pass('personal last member uses current count instead of old snapshot');
  for (const recurring of [false, true]) {
    await seed({ recurring });
    await lifecycle('complete');
    assert.equal((await getDoc(group)).data().activeRecruitmentCount, recurring ? 1 : 0);
    await lifecycle('disband');
    assert.equal((await getDoc(group)).data().activeRecruitmentCount, 0);
    pass(`completed ${recurring ? 'recurring' : 'single-use'} disband closes at most once`);
  }
  for (const audience of ['group', 'public']) {
    await seed({ recurring: true });
    if (audience === 'public') await visibility('public');
    await lifecycle('complete');
    await admin(async db => {
      for (const path of [`characters/${characterId}`, 'gameAccounts/account-1'])
        await updateDoc(doc(db, path), { ownerPlayerId: 'new-owner', ownershipRevision: 2 });
    });
    const before = await snapshot();
    await lifecycle('disband');
    const after = await snapshot();
    assert.deepEqual(after[4], before[4], 'cleanup preserves member snapshot');
    assert.deepEqual(after[5], before[5], 'cleanup preserves completed state');
    assert.equal((await getDoc(group)).data().activeRecruitmentCount, 0);
    pass(`${audience} last-owner cleanup preserves completion and count`);
  }
  await seed({ count: 3 });
  await denied('visibility cannot omit group decrement', () => visibility('public', true));
  await visibility('public');
  await denied('visibility cannot omit group increment', () => visibility('group', true));
  await visibility('group');
  assert.equal((await getDoc(group)).data().activeRecruitmentCount, 3);
  await lifecycle('disband');
  assert.equal((await getDoc(group)).data().activeRecruitmentCount, 2);
  pass('group-public-group opens and closes once');
  await denied('group count cannot replay a closed source', () => runTransaction(db, async tx => {
    const before = (await tx.get(group)).data();
    tx.update(group, { activeRecruitmentCount: before.activeRecruitmentCount - 1,
      revision: before.revision + 1, lastRecruitmentId: recruitmentId, updatedAt: serverTimestamp() });
  }));
  console.log(`group-count-confirmed: ${passed}`);
} finally { await env.cleanup(); }
