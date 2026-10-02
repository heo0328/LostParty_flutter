import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, serverTimestamp, runTransaction } from 'firebase/firestore';
import { occupancyCandidate } from './roster_occupancy_candidate.mjs';
import { seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn, approvePublicApplicationTxn,
  directRejoinAfterKickTxn, seedExpandedApprovedRoom, swapTwoDealersTxn, authUid, recruitmentId, playerId, characterId, cycleKey, raidId } from './party_group_cutover_rules_test.mjs';
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
  await check('direct join replaces old state without application', async () => {
    await prepare({ target: 'player-2', character: joinerCharacter });
    await createPublicRecruitmentTxn(db, { ownershipRevision: 3 });
    await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'recruitments', recruitmentId),
      { approvalPolicy: { mode: 'directJoin' } }));
    const before = await snapshot();
    await assertSucceeds(directRejoinAfterKickTxn(joiner, { ownershipRevision: 3 }));
    const after = await snapshot(); assertHistory(before, after);
    assert.equal(after.states[1][0].ownershipRevision, 3);
  });
  for (const change of ['ownership', 'occupancy']) {
    await check(`approval rejects intervening ${change} change atomically`, async () => {
      await prepare({ target: 'player-2', character: joinerCharacter });
      await createPublicRecruitmentTxn(db, { ownershipRevision: 3 });
      await applicationTxn(joiner, 'create', { ownershipRevision: 3 });
      await env.withSecurityRulesDisabled(async ctx => {
        const admin = ctx.firestore();
        if (change === 'occupancy') {
          await updateDoc(doc(admin, 'players', 'player-2', 'raidStates', `${joinerCharacter}_${raidId}`),
            { ownershipRevision: 3, recruitmentId: 'new-current-room' });
        } else {
          const ref = doc(admin, 'characters', joinerCharacter);
          const character = (await getDoc(ref)).data();
          await updateDoc(ref, { ownershipRevision: 5 });
          await updateDoc(doc(admin, 'gameAccounts', character.gameAccountId), { ownershipRevision: 5 });
        }
      });
      const before = await snapshot();
      await assertFails(approvePublicApplicationTxn(db, { ownershipRevision: 3 }));
      assert.deepEqual(await snapshot(), before);
    });
  }
  await check('maximum eight character change replaces prior generation state', async () => {
    await seed(3); await createPublicRecruitmentTxn(db, { ownershipRevision: 3 });
    await applicationTxn(joiner, 'create', { ownershipRevision: 3 });
    await approvePublicApplicationTxn(db, { ownershipRevision: 3 });
    await seedExpandedApprovedRoom(env, 8);
    const replacement = 'replacement-character';
    await env.withSecurityRulesDisabled(async ctx => {
      const admin = ctx.firestore();
      const current = (await getDoc(doc(admin, 'characters', joinerCharacter))).data();
      await setDoc(doc(admin, 'characters', replacement), { ...current });
      const ref = doc(admin, 'recruitments', recruitmentId);
      const room = (await getDoc(ref)).data();
      const last = (items, key) => [...items.filter(x => key(x) !== 'player-2'), ...items.filter(x => key(x) === 'player-2')];
      await updateDoc(ref, { partySlots: last(room.partySlots, x=>x.playerId),
        raidStateTargets: last(room.raidStateTargets, x=>x.playerId), memberPlayerIds: last(room.memberPlayerIds,x=>x) });
    });
    await oldState({ target: 'player-2', character: replacement, status: 'completed', claim: true });
    const before = await snapshot();
    await assertSucceeds(runTransaction(joiner, async tx => {
      const roomRef=doc(joiner,'recruitments',recruitmentId), memberRef=doc(joiner,'recruitments',recruitmentId,'members','player-2');
      const room=(await tx.get(roomRef)).data(); await tx.get(memberRef);
      const next=room.revision+1;
      tx.update(roomRef,{partySlots:room.partySlots.map(s=>s.playerId==='player-2'?{...s,characterId:replacement,ownershipRevision:3}:s),
        raidStateTargets:room.raidStateTargets.map(t=>t.playerId==='player-2'?{...t,stateId:`${replacement}_${raidId}`}:t),revision:next,updatedAt:serverTimestamp()});
      tx.update(memberRef,{characterId:replacement,ownershipRevision:3,characterChangedAt:serverTimestamp(),updatedAt:serverTimestamp()});
      tx.delete(doc(joiner,'players','player-2','raidStates',`${joinerCharacter}_${raidId}`));
      tx.set(doc(joiner,'players','player-2','raidStates',`${replacement}_${raidId}`),{
        schemaVersion:1,playerId:'player-2',characterId:replacement,raidId,recruitmentId,cycleKey,
        role:'support',status:'active',source:'party',revision:1,ownershipRevision:3,updatedAt:serverTimestamp()});
      const eventId=`characterChanged_${recruitmentId}_${next}`;
      tx.set(doc(joiner,'partyEvents',eventId),{schemaVersion:1,eventId,recruitmentId,type:'characterChanged',
        commandId:eventId,commandRevision:next,audiencePlayerIds:room.memberPlayerIds,actorPlayerId:'player-2',occurredAt:serverTimestamp()});
    }));
    const after=await snapshot(); assertHistory(before,after);
    assert.equal(after.room.partySlots[7].characterId,replacement);
    assert.equal(after.states[1].length,1);
  });
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
