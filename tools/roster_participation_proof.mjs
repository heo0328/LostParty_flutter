import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { participationCandidate } from './roster_participation_candidate.mjs';
import { seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn, approvePublicApplicationTxn,
  seedExpandedApprovedRoom, swapTwoDealersTxn, authUid, recruitmentId, playerId, raidId } from './party_group_cutover_rules_test.mjs';
const rules = process.env.ROSTER_COMPLEXITY_RULES_FILE
  ? fs.readFileSync(process.env.ROSTER_COMPLEXITY_RULES_FILE, 'utf8')
  : participationCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover', firestore: { rules, host: '127.0.0.1', port: 8080 } });
const db = env.authenticatedContext(authUid).firestore(), joiner = env.authenticatedContext('joiner-auth').firestore();
const results = [];
async function check(name, work) {
  try { await work(); results.push({ name, passed: true }); console.log(`PASS PARTICIPATION: ${name}`); }
  catch (error) { results.push({ name, passed: false, error: error.message }); console.error(`FAIL PARTICIPATION: ${name}: ${error.message}`); }
}
async function seed(revision = 1) {
  await env.clearFirestore(); await seedBase(env); await seedJoiner(env);
  await env.withSecurityRulesDisabled(async ctx => {
    for (const character of (await getDocs(collection(ctx.firestore(), 'characters'))).docs) {
      const c = character.data();
      const ownership = { ownerPlayerId: c.ownerPlayerId, status: 'active', ...(revision == null ? {} : { ownershipRevision: revision }) };
      await setDoc(doc(ctx.firestore(), 'gameAccounts', c.gameAccountId), ownership);
      await updateDoc(character.ref, ownership);
    }
  });
}
async function snapshot() {
  let result;
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    const readCollection = async parts => (await getDocs(collection(admin, ...parts))).docs.map(d => ({ id: d.id, ...d.data() })).sort((a,b)=>a.id.localeCompare(b.id));
    result = { room: (await getDoc(doc(admin, 'recruitments', recruitmentId))).data(),
      members: await readCollection(['recruitments', recruitmentId, 'members']),
      applications: await readCollection(['recruitments', recruitmentId, 'applications']),
      events: await readCollection(['partyEvents']),
      states: await Promise.all([playerId, 'player-2'].map(p=>readCollection(['players', p, 'raidStates']))) };
  });
  assert.ok(result); return result;
}
try {
  let normal = false;
  await check('generation one create, application and approval', async () => {
    await seed(); await assertSucceeds(createPublicRecruitmentTxn(db, { ownershipRevision: 1 }));
    await assertSucceeds(applicationTxn(joiner, 'create', { ownershipRevision: 1 }));
    await assertSucceeds(approvePublicApplicationTxn(db, { ownershipRevision: 1 }));
    const after = await snapshot();
    assert.ok(after.room.partySlots.every(s => s.ownershipRevision === 1));
    assert.ok(after.members.every(m => m.ownershipRevision === 1));
    assert.ok(after.states.flat().every(s => s.ownershipRevision === 1));
    normal = true;
  });
  await check('legacy missing generation create and approval remains valid', async () => {
    await seed(null); await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(joiner, 'create'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    assert.equal((await snapshot()).room.memberCount, 2);
  });
  if (normal) {
    for (const revision of [null, 0, 2]) {
      await check(`reject new create snapshot ${revision}`, async () => {
        await seed(); const before = await snapshot();
        await assertFails(createPublicRecruitmentTxn(db, { ownershipRevision: revision }));
        assert.deepEqual(await snapshot(), before);
      });
      await check(`reject application snapshot ${revision}`, async () => {
        await seed(); await createPublicRecruitmentTxn(db, { ownershipRevision: 1 });
        const before = await snapshot();
        await assertFails(applicationTxn(joiner, 'create', { ownershipRevision: revision }));
        assert.deepEqual(await snapshot(), before);
      });
    }
    await check('A-B-A rejects old approval then accepts explicit current reapplication', async () => {
      await seed(); await createPublicRecruitmentTxn(db, { ownershipRevision: 1 });
      await applicationTxn(joiner, 'create', { ownershipRevision: 1 });
      await env.withSecurityRulesDisabled(async ctx => {
        const chars = (await getDocs(collection(ctx.firestore(), 'characters'))).docs;
        const character = chars.find(c => c.data().ownerPlayerId === 'player-2');
        await updateDoc(character.ref, { ownershipRevision: 3 });
        await updateDoc(doc(ctx.firestore(), 'gameAccounts', character.data().gameAccountId), { ownershipRevision: 3 });
      });
      const before = await snapshot();
      await assertFails(approvePublicApplicationTxn(db, { ownershipRevision: 3 }));
      assert.deepEqual(await snapshot(), before);
      await assertSucceeds(applicationTxn(joiner, 'withdraw'));
      await assertSucceeds(applicationTxn(joiner, 'create', { ownershipRevision: 3 }));
      await assertSucceeds(approvePublicApplicationTxn(db, { ownershipRevision: 3 }));
      assert.equal((await snapshot()).room.partySlots[1].ownershipRevision, 3);
    });
    await check('maximum eight slots preserve generations during valid member swap', async () => {
      await seed(); await createPublicRecruitmentTxn(db, { ownershipRevision: 1 });
      await applicationTxn(joiner, 'create', { ownershipRevision: 1 });
      await approvePublicApplicationTxn(db, { ownershipRevision: 1 });
      await seedExpandedApprovedRoom(env, 8);
      const before = await snapshot();
      await assertSucceeds(swapTwoDealersTxn(db));
      const after = await snapshot();
      assert.equal(after.room.revision, before.room.revision + 1);
      for (const slot of after.room.partySlots) {
        assert.equal(slot.ownershipRevision, before.room.partySlots.find(s => s.playerId === slot.playerId).ownershipRevision);
      }
      assert.equal(after.room.partySlots.find(s => s.playerId === 'player-extra-1').slotIndex, 2);
    });
    await check('maximum eight slots reject generation-only forgery without member write', async () => {
      await seed(); await createPublicRecruitmentTxn(db, { ownershipRevision: 1 });
      await applicationTxn(joiner, 'create', { ownershipRevision: 1 });
      await approvePublicApplicationTxn(db, { ownershipRevision: 1 });
      await seedExpandedApprovedRoom(env, 8);
      const before = await snapshot();
      await assertFails(updateDoc(doc(db, 'recruitments', recruitmentId), {
        partySlots: before.room.partySlots.map((slot, i) => i === 7 ? { ...slot, ownershipRevision: 99 } : slot),
        revision: before.room.revision + 1, updatedAt: serverTimestamp(),
      }));
      assert.deepEqual(await snapshot(), before);
    });
  }
} finally { await env.cleanup(); }
fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
if (results.some(r => !r.passed)) process.exitCode = 1;
