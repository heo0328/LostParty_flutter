import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { occupancyCandidate } from './roster_occupancy_candidate.mjs';
import { seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn, approvePublicApplicationTxn,
  seedExpandedApprovedRoom, swapTwoDealersTxn, authUid, recruitmentId, playerId, characterId, cycleKey, raidId } from './party_group_cutover_rules_test.mjs';
const rules = occupancyCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover', firestore: { rules, host: '127.0.0.1', port: 8080 } });
const db = env.authenticatedContext(authUid).firestore(), joiner = env.authenticatedContext('joiner-auth').firestore();
const results = [];
async function check(name, work) {
  try { await work(); results.push({ name, passed: true }); console.log(`PASS OCCUPANCY: ${name}`); }
  catch (error) { results.push({ name, passed: false, error: error.message }); console.error(`FAIL OCCUPANCY: ${name}: ${error.message}`); }
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
      events: await readCollection(['partyEvents']), rooms: await readCollection(['recruitments']),
      claims: await Promise.all([playerId, 'player-2'].map(p=>readCollection(['players', p, 'weeklyRaidClaims']))),
      states: await Promise.all([playerId, 'player-2'].map(p=>readCollection(['players', p, 'raidStates']))) };
  });
  assert.ok(result); return result;
}
const joinerCharacter = 'charqrstuvwxyzabcdef';
async function oldState({ target = playerId, character = characterId, generation = 1, status = 'active', claim = false } = {}) {
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    const data = { schemaVersion: 1, playerId: target, characterId: character, raidId,
      recruitmentId: 'old-room', cycleKey, role: 'dealer', status, source: 'party', revision: 7,
      ...(generation === 'missing' ? {} : { ownershipRevision: generation }) };
    await setDoc(doc(admin, 'players', target, 'raidStates', `${character}_${raidId}`), data);
    await setDoc(doc(admin, 'recruitments', 'old-room'), { status: 'active', historySentinel: 'preserve' });
    await setDoc(doc(admin, 'partyEvents', 'old-history'), { historySentinel: 'preserve' });
    if (claim) await setDoc(doc(admin, 'players', target, 'weeklyRaidClaims', `${cycleKey}_${character}_${raidId}`), data);
  });
}
async function prepare(options = {}) { await seed(3); await oldState(options); }
function assertHistory(before, after) {
  assert.deepEqual(after.rooms.find(r=>r.id==='old-room'), before.rooms.find(r=>r.id==='old-room'));
  assert.deepEqual(after.events.find(r=>r.id==='old-history'), before.events.find(r=>r.id==='old-history'));
  assert.deepEqual(after.claims,before.claims);
}
try {
  for (const missing of ['room', 'member', 'state', 'event']) {
    await check(`missing ${missing} rejects the entire replacement`, async () => {
      await prepare(); const before = await snapshot();
      await assertFails(createPublicRecruitmentTxn(db, { ownershipRevision: 3, omitWrites: [missing] }));
      assert.deepEqual(await snapshot(), before);
    });
  }
  for (const status of ['active', 'completed']) {
    await check(`replace old ${status} through new recruitment and preserve history`, async () => {
      await prepare({ status, claim: status === 'completed' }); const before = await snapshot();
      await assertSucceeds(createPublicRecruitmentTxn(db, { ownershipRevision: 3 }));
      const after = await snapshot(); assertHistory(before, after);
      assert.equal(after.states[0][0].ownershipRevision,3);
      assert.equal(after.states[0][0].recruitmentId,recruitmentId);
    });
  }
  await check('legacy missing generation can be replaced after transfer', async () => {
    await prepare({ generation: 'missing', status: 'completed', claim: true });
    const before = await snapshot();
    await assertSucceeds(createPublicRecruitmentTxn(db, { ownershipRevision: 3 }));
    assertHistory(before,await snapshot());
  });
  for (const generation of [3,4,null,-1,1.5]) {
    await check(`preserve current or invalid state generation ${generation}`, async () => {
      await prepare({ generation }); const before = await snapshot();
      await assertFails(createPublicRecruitmentTxn(db, { ownershipRevision: 3 }));
      assert.deepEqual(await snapshot(),before);
    });
  }
  for (const generation of [3,null]) {
    await check(`current or invalid weekly claim ${generation} still blocks new use`, async () => {
      await prepare({ status: 'completed', claim: true });
      await env.withSecurityRulesDisabled(async ctx => updateDoc(doc(ctx.firestore(), 'players', playerId,
        'weeklyRaidClaims', `${cycleKey}_${characterId}_${raidId}`), { ownershipRevision: generation }));
      const before = await snapshot();
      await assertFails(createPublicRecruitmentTxn(db, { ownershipRevision: 3 }));
      assert.deepEqual(await snapshot(),before);
    });
  }
  await check('application preserves old state; approval atomically replaces it without private read', async () => {
    await prepare({ target: 'player-2', character: joinerCharacter, status: 'completed', claim: true });
    await createPublicRecruitmentTxn(db, { ownershipRevision: 3 });
    const before = await snapshot();
    await assertFails(getDoc(doc(db, 'players', 'player-2', 'raidStates', `${joinerCharacter}_${raidId}`)));
    await assertSucceeds(applicationTxn(joiner, 'create', { ownershipRevision: 3 }));
    assert.deepEqual((await snapshot()).states,before.states);
    await assertSucceeds(approvePublicApplicationTxn(db, { ownershipRevision: 3 }));
    const after = await snapshot(); assertHistory(before,after);
    assert.equal(after.states[1][0].ownershipRevision,3);
  });
  await check('standalone replacement cannot reuse an existing room and event', async () => {
    await seed(3); await createPublicRecruitmentTxn(db, { ownershipRevision: 3 });
    const desired=(await snapshot()).states[0][0]; delete desired.id;
    await oldState(); const before=await snapshot();
    await assertFails(setDoc(doc(db,'players',playerId,'raidStates',`${characterId}_${raidId}`),desired));
    assert.deepEqual(await snapshot(),before);
  });
  await check('competing new recruitments cannot both replace the same old generation', async () => {
    await prepare(); const before=await snapshot();
    const results=await Promise.allSettled(['race-one','race-two'].map(id=>createPublicRecruitmentTxn(db,{id,ownershipRevision:3})));
    assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
    assert.ok(results.filter(r=>r.status==='rejected').every(r=>['permission-denied','aborted'].includes(r.reason.code)));
    const after=await snapshot(); assertHistory(before,after);
    assert.equal(after.rooms.filter(r=>r.id.startsWith('race-')).length,1);
    assert.equal(after.events.filter(e=>e.id.startsWith('partyCreated_race-')).length,1);
  });
} finally { await env.cleanup(); }
fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
if (results.some(r => !r.passed)) process.exitCode = 1;
