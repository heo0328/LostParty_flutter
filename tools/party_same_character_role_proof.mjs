// Emulator-only atomic role update checks against the complete generated Rules.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, getDocs, collection, setDoc, updateDoc, writeBatch, serverTimestamp, Timestamp} from 'firebase/firestore';
import {seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn,
  approvePublicApplicationTxn, seedExpandedApprovedRoom, authUid, playerId,
  recruitmentId, raidId, seedGroupLinkedRoom} from './party_group_cutover_rules_test.mjs';
import {assertRulesDenied} from './assert_rules_denied.mjs';

const env = await initializeTestEnvironment({projectId:'demo-party-group-cutover',
  firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync('coverage/rules-localization/candidate.rules','utf8')}});
const results=[];
try {
  for (const scenario of ['leader','member','guard','prep','group','group-prep','omit-listing','omit-state','omit-member','omit-event',
    'wrong-actor','wrong-revision','forged-cycle','stale-owner','guard-tamper','full-eight',
    'omit-room','stale-state-owner','completed-room','state-member-role-mismatch']) {
    if(process.env.ROLE_CASES && !process.env.ROLE_CASES.split(',').includes(scenario)) continue;
    await env.clearFirestore();
    await seedBase(env); await seedJoiner(env);
    let before, member, state, target, stateId;
    const isMember = scenario === 'member' || scenario === 'full-eight';
    const prep = scenario === 'prep' || scenario === 'group-prep';
    const group = ['group','group-prep','omit-listing'].includes(scenario);
    await env.withSecurityRulesDisabled(async context => {
      const db=context.firestore();
      await createPublicRecruitmentTxn(db);
      if(group) await seedGroupLinkedRoom(env,db);
      if(isMember) {
        await applicationTxn(db,'create');
        await approvePublicApplicationTxn(db);
        if(scenario==='full-eight') await seedExpandedApprovedRoom(env,8);
      }
      before=(await getDoc(doc(db,'recruitments',recruitmentId))).data();
      target=isMember ? before.memberPlayerIds.find(id=>id!==playerId) : playerId;
      member=(await getDoc(doc(db,'recruitments',recruitmentId,'members',target))).data();
      stateId=`${member.characterId}_${raidId}`;
      const stateRef=doc(db,'players',target,'raidStates',stateId);
      state=(await getDoc(stateRef)).data();
      // Seed current account authority just like production, independently of UI.
      for(const character of (await getDocs(collection(db,'characters'))).docs) {
        const c=character.data();
        await setDoc(doc(db,'gameAccounts',c.gameAccountId),{status:'active',ownerPlayerId:c.ownerPlayerId,ownershipRevision:0});
      }
      if(prep) {
        Object.assign(before,{continueTogether:true,currentCycleStatus:'completed'});
        Object.assign(state,{status:'completed',completedAt:Timestamp.now()});
      }
      if(scenario==='guard' || scenario==='guard-tamper') Object.assign(state,{
        guardSchemaVersion:1,guardRecruitmentId:recruitmentId,guardRoomRevision:before.revision,
        guardCycleKey:before.currentCycleKey,guardCycleStartedAt:before.cycleStartedAt,
        guardCycleEndsAt:before.cycleEndsAt,guardSlotIndex:0,guardCheckedAt:Timestamp.now(),
      });
      Object.assign(member,{ownershipRevision:0});
      Object.assign(state,{role:member.role,ownershipRevision:0,difficultyId:before.difficultyId});
      if(scenario==='stale-state-owner') state.ownershipRevision=1;
      if(scenario==='completed-room') before.currentCycleStatus='completed';
      if(scenario==='state-member-role-mismatch') state.role=member.role==='dealer'?'support':'dealer';
      before.partySlots=before.partySlots.map(s=>({...s,ownershipRevision:0}));
      await setDoc(doc(db,'recruitments',recruitmentId),before);
      if(group) await setDoc(doc(db,'groups',before.groupId,'raidListings',recruitmentId),before);
      await setDoc(doc(db,'recruitments',recruitmentId,'members',target),member);
      await setDoc(stateRef,state);
      if(scenario==='stale-owner') {
        const c=(await getDoc(doc(db,'characters',member.characterId))).data();
        await updateDoc(doc(db,'gameAccounts',c.gameAccountId),{ownershipRevision:1});
      }
    });
    const db=env.authenticatedContext(scenario==='wrong-actor'?'stranger':isMember?'joiner-auth':authUid).firestore();
    const role=member.role==='dealer'?'support':'dealer';
    const slots=before.partySlots.map(s=>s.playerId===target?{...s,role}:s);
    const patch={partySlots:slots,dealerCount:slots.filter(s=>s.role==='dealer').length,
      supportCount:slots.filter(s=>s.role==='support').length,
      revision:before.revision+1,updatedAt:serverTimestamp()};
    const eventId=`characterChanged_${recruitmentId}_${patch.revision}`;
    const batch=writeBatch(db);
    if(scenario!=='omit-room') batch.update(doc(db,'recruitments',recruitmentId),patch);
    if(group && scenario!=='omit-listing') batch.set(doc(db,'groups',before.groupId,'raidListings',recruitmentId),{...before,...patch});
    if(scenario!=='omit-member') batch.update(doc(db,'recruitments',recruitmentId,'members',target),{
      role,characterChangedAt:serverTimestamp(),updatedAt:serverTimestamp()});
    if(!prep && scenario!=='omit-state') batch.update(doc(db,'players',target,'raidStates',stateId),{
      role,revision:state.revision+(scenario==='wrong-revision'?0:1),updatedAt:serverTimestamp(),
      ...(scenario==='forged-cycle'?{cycleKey:'2000-01-01'}:{}),
      ...(scenario==='guard-tamper'?{guardRoomRevision:999}:{}),
    });
    if(scenario!=='omit-event') batch.set(doc(db,'partyEvents',eventId),{
      schemaVersion:1,eventId,recruitmentId,type:'characterChanged',commandId:eventId,
      commandRevision:patch.revision,audiencePlayerIds:before.memberPlayerIds,
      actorPlayerId:target,occurredAt:serverTimestamp(),
      ...(prep?{previousCharacterId:member.characterId,nextCharacterId:member.characterId,
        nextOwnershipRevision:0,cycleKey:before.currentCycleKey}:{}),
    });
    // Composition is an app policy; the full-eight case checks server ownership
    // and atomicity at the maximum roster size, not local support capacity.
    const allowed=['leader','member','guard','prep','group','group-prep','full-eight'].includes(scenario);
    if(allowed) await batch.commit(); else await assertRulesDenied(batch.commit());
    await env.withSecurityRulesDisabled(async context=>{
      const db=context.firestore();
      const afterRoom=(await getDoc(doc(db,'recruitments',recruitmentId))).data();
      const afterMember=(await getDoc(doc(db,'recruitments',recruitmentId,'members',target))).data();
      const afterState=(await getDoc(doc(db,'players',target,'raidStates',stateId))).data();
      if(group) assert.deepEqual((await getDoc(doc(db,'groups',before.groupId,'raidListings',recruitmentId))).data(),afterRoom);
      if(!allowed) {
        assert.deepEqual(afterRoom,before); assert.deepEqual(afterMember,member); assert.deepEqual(afterState,state);
        assert.equal((await getDoc(doc(db,'partyEvents',eventId))).exists(),false);
      } else {
        assert.equal(afterMember.role,role);
        if(prep) assert.deepEqual(afterState,state);
        else assert.deepEqual({...afterState,role:state.role,revision:state.revision,updatedAt:state.updatedAt},state);
      }
    });
    results.push({scenario,allowed}); console.log(`PASS ${scenario}: ${allowed?'allowed':'denied, unchanged'}`);
  }
  fs.writeFileSync(process.env.ROLE_RESULTS || 'coverage/participation-role-rules-results.json',JSON.stringify(results,null,2));
} finally {await env.cleanup();}
