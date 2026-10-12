import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds } from '@firebase/rules-unit-testing';
import { assertRulesDenied as assertFails } from './assert_rules_denied.mjs';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp, runTransaction } from 'firebase/firestore';
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
const focused = process.env.PERSONAL_FOCUS === '1';
const dispatchOnly = process.env.PERSONAL_DISPATCH_ONLY === '1';
// Historical reproduction only: the old fixture reordered slots but not member IDs.
const legacyOrder = process.env.PERSONAL_LEGACY_ORDER === '1';
let beforeOperation;
async function seed(solo = false, memberLast = false) {
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
    if (legacyOrder || memberLast) await env.withSecurityRulesDisabled(async ctx => {
      const ref = doc(ctx.firestore(), 'recruitments', recruitmentId), room = (await getDoc(ref)).data();
      const last = (items, id) => [...items.filter(x => id(x) !== joinerId), ...items.filter(x => id(x) === joinerId)];
      await updateDoc(ref, { ...(!legacyOrder ? { memberPlayerIds: last(room.memberPlayerIds, x=>x) } : {}),
        partySlots: last(room.partySlots, x=>x.playerId),
        raidStateTargets: last(room.raidStateTargets, x=>x.playerId) });
    });
  }
  await seedGroupLinkedRoom(env, db, { includeJoinerGroupMember: !solo });
  if (!legacyOrder) {
    const room = (await snapshot()).room;
    assert.deepEqual(room.memberPlayerIds, room.partySlots.map(slot => slot.playerId));
    assert.deepEqual(room.memberPlayerIds, room.raidStateTargets.map(target => target.playerId));
  }
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
  if (process.env.PERSONAL_CASE_FILTER && !new RegExp(process.env.PERSONAL_CASE_FILTER).test(name)) return;
  if (dispatchOnly && !name.startsWith('dispatch ')) return;
  if (focused && !['normal leader completion preserves others', 'missing event rolls back completion'].includes(name)) return;
  beforeOperation = undefined;
  try { await work(); results.push({name,passed:true}); console.log(`PASS PERSONAL: ${name}`); }
  catch(error) {
    let unchanged;
    if (beforeOperation) {
      const after = await snapshot();
      try { assert.deepEqual(after, beforeOperation); unchanged = true; } catch { unchanged = false; }
    }
    results.push({name,passed:false,error:error.message, unchanged});
    console.error(`FAIL PERSONAL: ${name}: ${error.message}; unchanged=${unchanged}`);
  }
}
try {
  if (dispatchOnly) {
    for (const marker of ['personalComplete', 'cleanupCompletedLeaderOwnership']) {
      for (const current of [false, true]) await check(`dispatch ${marker} ${current ? 'forged current rejects' : 'stale permits independent recurrence'}`, async () => {
        await seed();
        await env.withSecurityRulesDisabled(async ctx => {
          const ref = doc(ctx.firestore(), 'recruitments', recruitmentId);
          await updateDoc(ref, { lastCommandType: marker, lastCommandAt: Timestamp.fromMillis(0) });
          await setDoc(doc(ctx.firestore(), 'groups', 'group-room-1', 'raidListings', recruitmentId), (await getDoc(ref)).data());
        });
        const before = await snapshot(); beforeOperation = before;
        const operation = runTransaction(db, async tx => {
          const ref = doc(db, 'recruitments', recruitmentId), room = (await tx.get(ref)).data();
          const patch = { continueTogether: !room.continueTogether, revision: room.revision + 1, updatedAt: serverTimestamp(),
            ...(current ? { lastCommandAt: serverTimestamp() } : {}) };
          tx.update(ref, patch);
          tx.set(doc(db, 'groups', 'group-room-1', 'raidListings', recruitmentId), { ...room, ...patch });
        });
        if (current) {
          await assertFails(operation); assert.deepEqual(await snapshot(), before);
        } else {
          await assertSucceeds(operation);
          const after = await snapshot();
          assert.equal(after.room.continueTogether, !before.room.continueTogether);
          assert.equal(after.room.revision, before.room.revision + 1);
          assert.equal(after.room.lastCommandType, marker);
          assert.deepEqual(after.room.lastCommandAt, before.room.lastCommandAt);
          assert.deepEqual(after.listings, [{ id: recruitmentId, ...after.room }]);
          for (const key of ['members', 'states', 'events', 'group', 'groupMembers']) assert.deepEqual(after[key], before[key]);
        }
      });
    }
  }
  if (process.env.DEPTH_BOUNDARIES === '1') {
    for (const kind of ['other-player', 'inactive-binding']) await check(`depth rejects ${kind}`, async () => {
      await seed();
      if (kind === 'inactive-binding') await env.withSecurityRulesDisabled(ctx =>
        updateDoc(doc(ctx.firestore(), 'authBindings', authUid), { status: 'inactive' }));
      const before = await snapshot();
      await assertFails(completeActiveMemberTxn(db, kind === 'other-player' ? joinerId : playerId,
        kind === 'other-player' ? joinerCharacter : characterId));
      assert.deepEqual(await snapshot(), before);
    });
    await check('group close rejects absent recruitment without writing counter', async () => {
      await seed(true);
      await env.withSecurityRulesDisabled(ctx => deleteDoc(doc(ctx.firestore(), 'recruitments', recruitmentId)));
      const before = await snapshot();
      await assertFails(updateDoc(doc(db, 'groups', 'group-room-1'), {
        activeRecruitmentCount: 0, lastRecruitmentId: recruitmentId,
        revision: before.group.revision + 1, updatedAt: serverTimestamp(),
      }));
      assert.deepEqual(await snapshot(), before);
    });
  }
  for (const kind of ['member','leader','solo']) await check(`normal ${kind} completion preserves others`, async()=>{
    await seed(kind==='solo', kind==='member'); const before=await snapshot(), actor=kind==='member'?joinerId:playerId;
    beforeOperation = before;
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
    beforeOperation = before;
    await assertFails(completeActiveMemberTxn(db,playerId,characterId,{omitWrites:[missing]})); assert.deepEqual(await snapshot(),before);
  });
} finally { await env.cleanup(); }
fs.writeFileSync(new URL('results.json',directory),JSON.stringify(results,null,2));
if(results.some(r=>!r.passed)) process.exitCode=1;
