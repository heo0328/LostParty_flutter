import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, writeBatch, Timestamp } from 'firebase/firestore';
import { orphanCleanupCandidate } from './roster_orphan_cleanup_candidate.mjs';
import { seedBase, authUid, playerId, characterId, cycleKey, raidId } from './party_group_cutover_rules_test.mjs';
const rules = orphanCleanupCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover', firestore: { rules, host: '127.0.0.1', port: 8080 } });
const db = env.authenticatedContext(authUid).firestore();
const statePath = `players/${playerId}/raidStates/${characterId}_${raidId}`;
const assignmentPath = `players/${playerId}/activeRaidAssignments/${characterId}_${raidId}`;
const paths = [statePath, assignmentPath, 'recruitments/orphan', 'recruitments/new-room', `players/${playerId}/weeklyRaidClaims/history`, 'partyEvents/history'];
const results = [];
async function admin(work) { await env.withSecurityRulesDisabled(ctx => work(ctx.firestore())); }
async function seed(generation = 3, parent = null) {
  await env.clearFirestore(); await seedBase(env);
  await admin(async db => {
    const ref = doc(db, 'characters', characterId), c = (await getDoc(ref)).data();
    const ownership = generation === 'missing' ? {} : { ownershipRevision: generation };
    await setDoc(ref, { ...c, ...ownership });
    await setDoc(doc(db, 'gameAccounts', c.gameAccountId), { status: 'active', ownerPlayerId: playerId, ...ownership });
    const data = { schemaVersion: 1, playerId, characterId, raidId, cycleKey,
      status: 'active', source: 'party', recruitmentId: 'orphan', revision: 7,
      updatedAt: Timestamp.fromMillis(1000), ...ownership };
    for (const path of paths.slice(0, 2)) await setDoc(doc(db, path), data);
    if (parent) await setDoc(doc(db, paths[2]), { raidId, status: parent, currentCycleStatus: 'active', continueTogether: true });
    for (const path of paths.slice(4)) await setDoc(doc(db, path), { sentinel: 'preserve' });
  });
}
async function snapshot() {
  let result;
  await admin(async db => { result = await Promise.all(paths.map(async path => (await getDoc(doc(db, path))).data())); });
  return result;
}
function cleanup() { const batch = writeBatch(db); batch.delete(doc(db, statePath)); batch.delete(doc(db, assignmentPath)); return batch.commit(); }
async function check(name, work) {
  try { await work(); results.push({ name, passed: true }); console.log(`PASS ORPHAN: ${name}`); }
  catch (error) { results.push({ name, passed: false, error: error.message }); console.error(`FAIL ORPHAN: ${name}: ${error.message}`); }
}
async function denyAfter(change) { await seed(); await admin(change); const before = await snapshot(); await assertFails(cleanup()); assert.deepEqual(await snapshot(), before); }
try {
  for (const parent of [null, 'completed', 'disbanded', 'incompleteEnded']) await check(`current orphan cleanup parent ${parent}`, async () => {
    await seed(3, parent); const before = await snapshot(); await assertSucceeds(cleanup());
    const after = await snapshot(); assert.deepEqual(after.slice(0, 2), [undefined, undefined]); assert.deepEqual(after.slice(2), before.slice(2));
  });
  await check('legacy generation zero cleanup', async () => { await seed('missing'); await assertSucceeds(cleanup()); assert.deepEqual((await snapshot()).slice(0, 2), [undefined, undefined]); });
  for (const value of [1, 4, null, -1]) await check(`reject stale or malformed record ${value}`, () => denyAfter(async db => {
    await updateDoc(doc(db, statePath), { ownershipRevision: value });
  }));
  await check('reject stale assignment atomically', () => denyAfter(db => updateDoc(doc(db, assignmentPath), { ownershipRevision: 1 })));
  await check('reject transfer and A B A old generation', () => denyAfter(async db => {
    const ref = doc(db, 'characters', characterId), c = (await getDoc(ref)).data();
    for (const target of [ref, doc(db, 'gameAccounts', c.gameAccountId)]) await updateDoc(target, { ownershipRevision: 5 });
  }));
  await check('reject previous owner', () => denyAfter(async db => {
    const ref = doc(db, 'characters', characterId), c = (await getDoc(ref)).data();
    for (const target of [ref, doc(db, 'gameAccounts', c.gameAccountId)]) await updateDoc(target, { ownerPlayerId: 'new-owner', ownershipRevision: 4 });
  }));
  await check('reject replacement current active room preserving old assignment', () => denyAfter(async db => {
    await setDoc(doc(db, paths[3]), { raidId, status: 'active', currentCycleStatus: 'active', continueTogether: true });
    await updateDoc(doc(db, statePath), { recruitmentId: 'new-room', revision: 1 });
  }));
  await check('reject parent raid mismatch', () => denyAfter(db => setDoc(doc(db, paths[2]), { raidId: 'other', status: 'completed' })));
  await check('reject unknown inactive authority', () => denyAfter(db => updateDoc(doc(db, 'characters', characterId), { status: 'inactive' })));
} finally { await env.cleanup(); }
fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
if (results.some(r => !r.passed)) process.exitCode = 1;
