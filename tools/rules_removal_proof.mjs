import { memberRemovalBaseline } from './roster_complexity_candidate.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { prioritizeMemberRemoval } from './roster_complexity_candidate.mjs';
import { targetScanCandidate } from './rules_target_scan_candidate.mjs';
import { scopeFunctions } from './rules_scope_candidate.mjs';
import { doc, getDoc, updateDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { seedBase,seedJoiner,createPublicRecruitmentTxn,applicationTxn,approvePublicApplicationTxn,
 seedPersistedAdvanceCycleMarker,repositionApprovedMemberTxn,kickApprovedMemberTxn,verifyMemberRemovalListings,authUid,
 seedExpandedApprovedRoom, removeApprovedMemberTxn, recruitmentId, playerId } from './party_group_cutover_rules_test.mjs';
const source=memberRemovalBaseline();
const rules=process.env.RULES_TARGET_SCAN === '1' ? scopeFunctions(targetScanCandidate(source)).source : prioritizeMemberRemoval(source);
const dir='coverage/rules-audit/removal';fs.mkdirSync(dir,{recursive:true});fs.mkdirSync('coverage/roster-leader',{recursive:true});
fs.writeFileSync(`${dir}/candidate.rules`,rules);
fs.writeFileSync('coverage/roster-leader/manifest.json',JSON.stringify({sha256:createHash('sha256').update(rules).digest('hex')}));
process.env.RULES_AUDIT='1';
const env=await initializeTestEnvironment({projectId:'demo-party-group-cutover',firestore:{rules,host:'127.0.0.1',port:8080}});
try{
 await env.clearFirestore();await seedBase(env);await seedJoiner(env);
 const db=env.authenticatedContext(authUid).firestore(),joiner=env.authenticatedContext('joiner-auth').firestore();
 await createPublicRecruitmentTxn(db);await applicationTxn(joiner,'apply');await approvePublicApplicationTxn(db);
 console.log('PHASE reject unconsumed marker');
 await seedPersistedAdvanceCycleMarker(env);await assertFails(repositionApprovedMemberTxn(db,2,2,{skipMarkerConsumption:true}));
 console.log('PHASE normal reposition');await repositionApprovedMemberTxn(db);
 console.log('PHASE post-cycle kick');await seedPersistedAdvanceCycleMarker(env);await assertSucceeds(kickApprovedMemberTxn(db));
 console.log('PASS REMOVAL: original post-cycle kick');
 await verifyMemberRemovalListings(env,db,joiner);
 if(process.env.RULES_TARGET_SCAN === '1') {
   await env.clearFirestore();await seedBase(env);await seedJoiner(env);
   await createPublicRecruitmentTxn(db);await applicationTxn(joiner,'apply');await approvePublicApplicationTxn(db);
   await seedExpandedApprovedRoom(env,8);
   await assertFails(removeApprovedMemberTxn(joiner,'player-2',{targetPlayerId:'player-extra-1'}));
   await assertFails(deleteDoc(doc(joiner,'recruitments',recruitmentId,'members','player-2')));
   await assertSucceeds(removeApprovedMemberTxn(joiner,'player-2'));
   assert.equal((await getDoc(doc(db,'recruitments',recruitmentId))).data().memberCount,7);
   console.log('PASS REMOVAL: maximum-eight self leave; foreign kick and member-only deletion rejected');
   await seedPersistedAdvanceCycleMarker(env);
   const ref=doc(db,'recruitments',recruitmentId), before=(await getDoc(ref)).data();
   await assertSucceeds(updateDoc(ref,{continueTogether:!before.continueTogether,revision:before.revision+1,updatedAt:serverTimestamp()}));
   console.log('PASS REMOVAL: recurrence setting preserves previous lifecycle marker');
 }
}finally{await env.cleanup();}
for(const script of ['roster_personal_completion_proof','roster_peer_cleanup_proof','roster_last_member_proof','group_leave_rules_test']){
 const run=spawnSync(process.execPath,[`tools/${script}.mjs`],{encoding:'utf8',timeout:300000,env:{...process.env,RULES_BUDGET_AUDIT:'1',ROSTER_TRACKED_RULES:'1',LEADER_PROOF_SCOPE:'',ROSTER_COMPLEXITY_RULES_FILE:path.resolve(`${dir}/candidate.rules`)}});
 const output=(run.stdout??'')+(run.stderr??'');fs.writeFileSync(`${dir}/${script}.log`,output);
 assert.equal(run.status,0,script);
 console.log(script+' passed');
}
