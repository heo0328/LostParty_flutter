import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';
import { personalCompletionCandidate } from './roster_personal_completion_candidate.mjs';
import { manualCompletionCandidate } from './roster_manual_completion_candidate.mjs';
import { seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn, approvePublicApplicationTxn,
  seedExpandedApprovedRoom, seedGroupLinkedRoom, completeActiveMemberTxn,
  authUid, playerId, characterId, recruitmentId, raidId } from './party_group_cutover_rules_test.mjs';
const baseline = process.env.LEADER_PROOF_SCOPE === 'personal-baseline';
const rules = process.env.ROSTER_COMPLEXITY_RULES_FILE
  ? fs.readFileSync(process.env.ROSTER_COMPLEXITY_RULES_FILE, 'utf8')
  : (baseline ? manualCompletionCandidate : personalCompletionCandidate)(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover', firestore: { rules, host: '127.0.0.1', port: 8080 } });
const db = env.authenticatedContext(authUid).firestore(), joiner = env.authenticatedContext('joiner-auth').firestore();
const joinerId = 'player-2', joinerCharacter = 'charqrstuvwxyzabcdef';
const results = [];
async function seed(solo = false) {
  await env.clearFirestore(); await seedBase(env); await seedJoiner(env);
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    for (const c of (await getDocs(collection(admin, 'characters'))).docs) {
      const ownership = { ownerPlayerId: c.data().ownerPlayerId, status: 'active', ownershipRevision: 3 };
      await updateDoc(c.ref, ownership); await setDoc(doc(admin, 'gameAccounts', c.data().gameAccountId), ownership);
    }
  });
  await createPublicRecruitmentTxn(db, { ownershipRevision: 3 });
  if (!solo) {
    await applicationTxn(joiner, 'create', { ownershipRevision: 3 });
    await approvePublicApplicationTxn(db, { ownershipRevision: 3 });
    await seedExpandedApprovedRoom(env, 8);
    await env.withSecurityRulesDisabled(async ctx => {
      const ref = doc(ctx.firestore(), 'recruitments', recruitmentId), room = (await getDoc(ref)).data();
      const last = (items, id) => [...items.filter(x => id(x) !== joinerId), ...items.filter(x => id(x) === joinerId)];
      await updateDoc(ref, { partySlots: last(room.partySlots, x=>x.playerId),
        raidStateTargets: last(room.raidStateTargets, x=>x.playerId) });
    });
  }
  await seedGroupLinkedRoom(env, db, { includeJoinerGroupMember: !solo });
}
async function snapshot() {
  let result;
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore(), read = async path => (await getDocs(collection(admin, path))).docs.map(d=>({id:d.id,...d.data()})).sort((a,b)=>a.id.localeCompare(b.id));
    const members = await read(`recruitments/${recruitmentId}/members`);
    result = { room: (await getDoc(doc(admin,'recruitments',recruitmentId))).data(), members,
      group: (await getDoc(doc(admin,'groups','group-room-1'))).data(),
      listings: await read('groups/group-room-1/raidListings'), groupMembers: await read('groups/group-room-1/members'),
      events: await read('partyEvents'),
      states: await Promise.all([playerId,joinerId,...Array.from({length:6},(_,i)=>`player-extra-${i+1}`)].map(p=>read(`players/${p}/raidStates`))) };
  });
  assert.ok(result); return result;
}
async function check(name, work) {
  try { await work(); results.push({name,passed:true}); console.log(`PASS PERSONAL: ${name}`); }
  catch(error) { results.push({name,passed:false,error:error.message}); console.error(`FAIL PERSONAL: ${name}: ${error.message}`); }
}
try {
  for (const kind of ['member','leader','solo']) await check(`normal ${kind} completion preserves others`, async()=>{
    await seed(kind==='solo'); const before=await snapshot(), actor=kind==='member'?joinerId:playerId;
    await assertSucceeds(completeActiveMemberTxn(kind==='member'?joiner:db, actor, kind==='member'?joinerCharacter:characterId));
    const after=await snapshot(), index=kind==='member'?1:0;
    assert.equal(after.states[index][0].status,'completed'); assert.equal(after.states[index][0].ownershipRevision,3);
    assert.equal(after.members.some(m=>m.playerId===actor),false);
    assert.deepEqual(after.states.filter((_,i)=>i!==index),before.states.filter((_,i)=>i!==index));
    assert.deepEqual(after.groupMembers,before.groupMembers);
    if(kind==='solo') { assert.equal(after.room.status,'disbanded'); assert.equal(after.listings.length,0); assert.equal(after.group.activeRecruitmentCount,0); }
    else { assert.equal(after.room.memberCount,7); if(kind==='leader') assert.equal(after.room.leaderPlayerId,joinerId); }
  });
  for (const part of baseline ? [] : ['state','member','slot','authority','successor']) await check(`reject stale ${part} atomically`,async()=>{
    await seed();
    await env.withSecurityRulesDisabled(async ctx=>{
      const admin=ctx.firestore();
      if(part==='state') await updateDoc(doc(admin,'players',playerId,'raidStates',`${characterId}_${raidId}`),{ownershipRevision:1});
      if(part==='member') await updateDoc(doc(admin,'recruitments',recruitmentId,'members',playerId),{ownershipRevision:1});
      if(part==='slot') { const ref=doc(admin,'recruitments',recruitmentId), room=(await getDoc(ref)).data(); await updateDoc(ref,{partySlots:room.partySlots.map(s=>s.playerId===playerId?{...s,ownershipRevision:1}:s)}); }
      if(['authority','successor'].includes(part)) { const ref=doc(admin,'characters',part==='successor'?joinerCharacter:characterId), c=(await getDoc(ref)).data(); await updateDoc(ref,{ownershipRevision:5}); await updateDoc(doc(admin,'gameAccounts',c.gameAccountId),{ownershipRevision:5}); }
    });
    const before=await snapshot(); await assertFails(completeActiveMemberTxn(db,playerId,characterId)); assert.deepEqual(await snapshot(),before);
  });
  for (const missing of baseline ? [] : ['room','member','state','event','listing','successor','group']) await check(`missing ${missing} rolls back completion`,async()=>{
    await seed(missing==='group'); const before=await snapshot();
    await assertFails(completeActiveMemberTxn(db,playerId,characterId,{omitWrites:[missing]})); assert.deepEqual(await snapshot(),before);
  });
} finally { await env.cleanup(); }
fs.writeFileSync(new URL('results.json',directory),JSON.stringify(results,null,2));
if(results.some(r=>!r.passed)) process.exitCode=1;
