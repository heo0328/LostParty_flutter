import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';
import { manualCompletionCandidate } from './roster_manual_completion_candidate.mjs';
import { seedBase, authUid, playerId, characterId, cycleKey, cycleWindow, raidId } from './party_group_cutover_rules_test.mjs';

const rules = manualCompletionCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover', firestore: { rules, host: '127.0.0.1', port: 8080 } });
const db = env.authenticatedContext(authUid).firestore();
const statePath = `players/${playerId}/raidStates/${characterId}_${raidId}`;
const claimPath = `players/${playerId}/weeklyRaidClaims/${cycleKey}_${characterId}_${raidId}`;
const assignmentPath = `players/${playerId}/activeRaidAssignments/${characterId}_${raidId}`;
const paths = [statePath, claimPath, assignmentPath, 'recruitments/old-room', 'partyEvents/old-event'];
const window = cycleWindow(cycleKey);
const results = [];
const generation = value => value === 'missing' ? {} : { ownershipRevision: value };
function completion(value = 3) {
  return { schemaVersion: 1, playerId, characterId, raidId, difficultyId: 'hard', cycleKey,
    status: 'completed', source: 'manual', recruitmentId: null, revision: 1,
    cycleStartedAt: Timestamp.fromDate(window.startedAt), cycleEndsAt: Timestamp.fromDate(window.endsAt),
    completedAt: serverTimestamp(), updatedAt: serverTimestamp(), ...generation(value) };
}
async function seed(value = 3) {
  await env.clearFirestore(); await seedBase(env);
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore(), ref = doc(admin, 'characters', characterId);
    const c = (await getDoc(ref)).data();
    await setDoc(ref, { ...c, ...generation(value) });
    await setDoc(doc(admin, 'gameAccounts', c.gameAccountId), { ownerPlayerId: playerId, status: 'active', ...generation(value) });
  });
}
async function prior(value = 1, status = 'completed') {
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    const data = { ...completion(value), status, source: 'party', recruitmentId: 'old-room', revision: 7 };
    for (const path of [statePath, claimPath, assignmentPath]) await setDoc(doc(admin, path), data);
    for (const path of paths.slice(3)) await setDoc(doc(admin, path), { sentinel: 'preserve' });
  });
}
async function snapshot() {
  return env.withSecurityRulesDisabled(async ctx => Promise.all(paths.map(async path => (await getDoc(doc(ctx.firestore(), path))).data())));
}
async function check(name, work) {
  try { await work(); results.push({ name, passed: true }); console.log(`PASS MANUAL: ${name}`); }
  catch (error) { results.push({ name, passed: false, error: error.message }); console.error(`FAIL MANUAL: ${name}: ${error.message}`); }
}
try {
  for (const value of [3, 'missing']) await check(`current manual create and cancel generation ${value}`, async () => {
    await seed(value); await assertSucceeds(setDoc(doc(db, statePath), completion(value)));
    await assertSucceeds(deleteDoc(doc(db, statePath))); assert.equal((await snapshot())[0], undefined);
  });
  for (const status of ['active', 'completed']) await check(`replace prior ${status} preserving other records`, async () => {
    await seed(); await prior(1, status); const before = await snapshot();
    await assertSucceeds(setDoc(doc(db, statePath), completion()));
    const after = await snapshot(); assert.equal(after[0].ownershipRevision, 3); assert.deepEqual(after.slice(1), before.slice(1));
    await assertSucceeds(deleteDoc(doc(db, statePath))); assert.deepEqual((await snapshot()).slice(1), before.slice(1));
  });
  for (const value of [3, 4, null, -1, 1.5]) await check(`reject overwriting protected state ${value}`, async () => {
    await seed(); await prior(value, 'active'); const before = await snapshot();
    await assertFails(setDoc(doc(db, statePath), completion())); assert.deepEqual(await snapshot(), before);
  });
  for (const value of [1, 'missing', 4, null]) await check(`reject forged new completion generation ${value}`, async () => {
    await seed(); const before = await snapshot();
    await assertFails(setDoc(doc(db, statePath), completion(value))); assert.deepEqual(await snapshot(), before);
  });
  await check('cancel current legacy claim while preserving active state', async () => {
    await seed('missing'); await prior('missing', 'active'); const before = await snapshot();
    await assertSucceeds(deleteDoc(doc(db, claimPath))); const after = await snapshot();
    assert.equal(after[1], undefined); assert.deepEqual(after[0], before[0]); assert.deepEqual(after.slice(2), before.slice(2));
  });
  for (const path of [statePath, claimPath]) await check(`reject stale cancellation ${path}`, async () => {
    await seed(); await prior(); const before = await snapshot();
    await assertFails(deleteDoc(doc(db, path))); assert.deepEqual(await snapshot(), before);
  });
  await check('mixed current and prior cancellation fails atomically', async () => {
    await seed(); await prior(); await assertSucceeds(setDoc(doc(db, statePath), completion())); const before = await snapshot();
    const batch = writeBatch(db); batch.delete(doc(db, statePath)); batch.delete(doc(db, claimPath));
    await assertFails(batch.commit()); assert.deepEqual(await snapshot(), before);
  });
  await check('transfer after current completion rejects old owner cancellation', async () => {
    await seed(); await assertSucceeds(setDoc(doc(db, statePath), completion()));
    await env.withSecurityRulesDisabled(async ctx => {
      const admin = ctx.firestore(), ref = doc(admin, 'characters', characterId), c = (await getDoc(ref)).data();
      const changed = { ownerPlayerId: 'other-player', ownershipRevision: 4 };
      await updateDoc(ref, changed); await updateDoc(doc(admin, 'gameAccounts', c.gameAccountId), changed);
    });
    const before = await snapshot(); await assertFails(deleteDoc(doc(db, statePath))); assert.deepEqual(await snapshot(), before);
  });
} finally { await env.cleanup(); }
fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
if (results.some(r => !r.passed)) process.exitCode = 1;
