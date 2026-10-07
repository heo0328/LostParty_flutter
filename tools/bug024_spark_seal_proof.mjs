// Isolated C feasibility. No production credentials, app writers, or deployed Rules.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';
import { authUid, playerId, recruitmentId, raidId, cycleKey, cycleWindow } from './party_group_cutover_rules_test.mjs';
process.env.BUG024_IMPORT_ONLY = '1';
process.env.BUG024_SPARK_EVENT = '1';
process.env.BUG024_RULES_FILE = 'coverage/bug024/spark-seal/candidate.rules';
const { env, db, admin, snapshot, seed, prepare, advance, denied, lifecycle, replacement, second } = await import('./bug024_preparation_proof.mjs');
const results = [];
const dir = 'coverage/bug024/spark-seal';
const guardKeys = ['guardSchemaVersion', 'guardRecruitmentId', 'guardRoomRevision', 'guardCycleKey', 'guardSlotIndex', 'guardCheckedAt'];
async function check(name, work) {
  try { await work(); results.push({ name, passed: true }); console.log(`PASS C ${name}`); }
  catch (e) { results.push({ name, passed: false, error: e.message }); console.error(`FAIL C ${name}: ${e.message}`); }
}
async function room() { return (await getDoc(doc(db, 'recruitments', recruitmentId))).data(); }
function stateRef(client, slot) { return doc(client, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`); }
function auditData(r, index, extra = {}) {
  const slot = r.partySlots[index];
  return { playerId: slot.playerId, characterId: slot.characterId, raidId, ownershipRevision: slot.ownershipRevision,
    guardSchemaVersion: 1, guardRecruitmentId: recruitmentId, guardRoomRevision: r.revision,
    guardCycleKey: cycleKey, guardSlotIndex: index, guardCheckedAt: serverTimestamp(), ...extra };
}
async function auditOne({ index = null, extra = {}, client = db } = {}) {
  const r = await room(); index ??= r.partySlots.findIndex(s => s.playerId === playerId);
  await setDoc(stateRef(client, r.partySlots[index]), auditData(r, index, extra), { merge: true });
}
function withoutGuard(data) { return Object.fromEntries(Object.entries(data).filter(([k]) => !guardKeys.includes(k))); }
async function auditAll() {
  const before = await snapshot(); const r = before.room;
  for (let index = 0; index < r.partySlots.length; index++) await auditOne({ index });
  const after = await snapshot();
  for (const key of ['room', 'listing', 'members', 'events', 'claims']) assert.deepEqual(after[key], before[key], key);
  for (let p = 0; p < before.states.length; p++) {
    for (const old of before.states[p]) {
      const next = after.states[p].find(s => s.id === old.id);
      assert.deepEqual(withoutGuard(next), withoutGuard(old), 'audit must preserve every existing state field');
    }
  }
}
async function setup(options) { await seed(options); await prepare(); }
function claimData() {
  const window = cycleWindow(cycleKey);
  return { schemaVersion: 1, playerId, characterId: replacement, raidId, cycleKey,
    difficultyId: 'normal', source: 'manual', cycleStartedAt: Timestamp.fromDate(window.startedAt),
    cycleEndsAt: Timestamp.fromDate(window.endsAt), completedAt: serverTimestamp(), updatedAt: serverTimestamp() };
}
function claimRef(client = db) { return doc(client, 'players', playerId, 'weeklyRaidClaims', `${cycleKey}_${replacement}_${raidId}`); }
try {
  await check('8-member repeated preparation, absent stub, atomic advance and complete', async () => {
    await seed({ actorLast: true }); const original = await snapshot();
    await prepare(); await prepare({ id: second }); await prepare();
    assert.deepEqual((await snapshot()).states, original.states);
    await auditAll();
    const stub = await admin(async adb => (await getDoc(doc(adb, 'players', playerId, 'raidStates', `${replacement}_${raidId}`))).data());
    assert.deepEqual(Object.keys(stub).sort(), ['playerId', 'characterId', 'raidId', 'ownershipRevision', ...guardKeys].sort());
    await advance(); await lifecycle(db, 'complete', { completionRole: true });
    const after = await snapshot();
    assert.equal(after.room.currentCycleStatus, 'completed');
    assert.deepEqual(after.events.filter(e => e.type === 'complete' && e.id === original.events.find(x => x.type === 'complete').id), original.events.filter(e => e.type === 'complete'));
  });
  for (const targetState of ['same', 'foreign', 'foreign-role', 'manual']) {
    await check(`8-member ${targetState} completed audit/advance/complete`, async () => {
      await setup({ targetState }); await auditAll(); await advance(); await lifecycle(db, 'complete', { completionRole: true });
    });
  }
  for (const targetState of ['current', 'active']) {
    await check(`reject audit ${targetState} state`, async () => { await setup({ targetState }); await denied(() => auditOne()); });
  }
  await check('reject malformed prior completed state', async () => {
    await setup({ targetState: 'foreign' });
    await admin(adb => updateDoc(doc(adb, 'players', playerId, 'raidStates', `${replacement}_${raidId}`), { source: 'unknown' }));
    await denied(() => auditOne());
  });
  await check('reject current Claim and Claim-delete plus audit', async () => {
    await setup();
    await admin(async adb => setDoc(claimRef(adb), { ...claimData(), ownershipRevision: 1 }));
    await denied(() => auditOne());
    await denied(async () => {
      const r = await room(); const i = r.partySlots.findIndex(s => s.playerId === playerId);
      const b = writeBatch(db); b.delete(claimRef()); b.set(stateRef(db, r.partySlots[i]), auditData(r, i), { merge: true }); await b.commit();
    });
  });
  await check('reject legacy occupancy before audit', async () => {
    await setup();
    await admin(adb => setDoc(doc(adb, 'players', playerId, 'activeRaidAssignments', `${replacement}_${raidId}`), {
      playerId, characterId: replacement, raidId, ownershipRevision: 1, recruitmentId: 'other-room', status: 'active', cycleKey }));
    await denied(() => auditOne());
  });
  for (const [name, extra] of Object.entries({ revision: { guardRoomRevision: 0 }, slot: { guardSlotIndex: 100 },
    generation: { ownershipRevision: 2 }, schema: { guardSchemaVersion: 2 }, record: { status: 'active' } })) {
    await check(`reject forged audit ${name}`, async () => { await setup(); await denied(() => auditOne({ extra })); });
  }
  await check('reject nonleader audit and private peer state read', async () => {
    await setup(); const client = env.authenticatedContext('stranger-auth').firestore();
    await denied(() => auditOne({ client }));
    const r = await room(); await assert.rejects(() => getDoc(stateRef(db, r.partySlots[1])), e => e.code === 'permission-denied');
  });
  await check('reject unaudited and partial/stale final transition', async () => {
    await setup(); await denied(() => advance()); await auditAll();
    await denied(() => advance({ omit: true })); await denied(() => advance({ staleRevision: true }));
  });
  await check('reject ownership transfer after all audits atomically', async () => {
    await setup(); await auditAll();
    await admin(adb => updateDoc(doc(adb, 'gameAccounts', `bug024-account-${playerId}`), { ownershipRevision: 2, ownerPlayerId: 'other-owner' }));
    await denied(() => advance());
  });
  await check('reject canonical current completion after audit', async () => {
    await setup({ targetState: 'same' }); await auditAll();
    await admin(adb => updateDoc(doc(adb, 'players', playerId, 'raidStates', `${replacement}_${raidId}`), { cycleKey }));
    await denied(() => advance());
  });
  await check('legacy Claim valid without seal, rejected with seal and seal delete', async () => {
    await setup(); await setDoc(claimRef(), claimData());
    await setup(); await auditOne(); await denied(() => setDoc(claimRef(), claimData()));
    await denied(async () => {
      const r = await room(); const slot = r.partySlots.find(s => s.playerId === playerId);
      const b = writeBatch(db); b.delete(stateRef(db, slot)); b.set(claimRef(), claimData()); await b.commit();
    });
  });
} finally {
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(`${dir}/results.json`, JSON.stringify(results, null, 2));
  const coverage = await fetch('http://127.0.0.1:8080/emulator/v1/projects/demo-party-group-cutover:ruleCoverage').then(r => r.text());
  fs.writeFileSync(`${dir}/ruleCoverage.json`, coverage);
  await env.cleanup();
}
assert.ok(results.every(r => r.passed), `${results.filter(r => !r.passed).length} C feasibility failures`);
console.log(`C: ${results.length} passed; isolated demo only`);
