import fs from 'node:fs';
import assert from 'node:assert/strict';
import {doc,getDoc,setDoc,updateDoc,deleteDoc,writeBatch,serverTimestamp,Timestamp} from 'firebase/firestore';
import {assertRulesDenied} from './assert_rules_denied.mjs';
import {recruitmentId,raidId,cycleKey,cycleWindow,disbandApprovedRoomTxn} from './party_group_cutover_rules_test.mjs';
process.env.GROUP_SOURCE_READ='1';process.env.GROUP_SOURCE_PROJECT_ID=`demo-group-source-extra-${Date.now()}`;
process.env.R1_LISTING='1';process.env.RULES_AUDIT='1';process.env.BUG024_IMPORT_ONLY='1';
process.env.BUG024_SPARK_EVENT='1';process.env.BUG024_RULES_FILE='firestore.rules';
const {env,db,admin,snapshot,seed,prepare,advance,denied}=await import('./bug024_preparation_proof.mjs');
const results=[];const check=async(name,fn)=>{if(process.env.L1_EXTRA_FILTER&&!new RegExp(process.env.L1_EXTRA_FILTER).test(name))return;await fn();results.push(name);console.log('PASS '+name);};
async function auditAll(){
 const room=(await snapshot()).room;const window=cycleWindow(cycleKey);
 for(const [index,slot] of room.partySlots.entries())await setDoc(doc(db,'players',slot.playerId,'raidStates',`${slot.characterId}_${raidId}`),{
   playerId:slot.playerId,characterId:slot.characterId,raidId,ownershipRevision:slot.ownershipRevision,
   guardSchemaVersion:1,guardRecruitmentId:recruitmentId,guardRoomRevision:room.revision,
   guardCycleKey:cycleKey,guardCycleStartedAt:Timestamp.fromDate(window.startedAt),
   guardCycleEndsAt:Timestamp.fromDate(window.endsAt),guardSlotIndex:index,guardCheckedAt:serverTimestamp(),
 },{merge:true});
}
try{
 await check('eight-member advance without listing',async()=>{await seed({missingListing:true});await prepare();await auditAll();await advance();assert.equal((await snapshot()).room.currentCycleStatus,'active');});
 await check('partial advance rejected atomically',async()=>{await seed();await prepare();await auditAll();await denied(()=>advance({omit:true}));});
 await check('stale advance rejected atomically',async()=>{await seed();await prepare();await auditAll();await denied(()=>advance({staleRevision:true}));});
 // Group qualification of preparation is an existing app gate. The before
 // Rules also permit this source-authorized writer; compare separately.
 await check('active eight-member disband releases states without listing',async()=>{await seed({missingListing:true});await admin(async adb=>{
   const room=(await getDoc(doc(adb,'recruitments',recruitmentId))).data();
   await updateDoc(doc(adb,'recruitments',recruitmentId),{currentCycleStatus:'active'});
   for(const s of room.partySlots)await updateDoc(doc(adb,'players',s.playerId,'raidStates',`${s.characterId}_${raidId}`),{status:'active'});
 });await disbandApprovedRoomTxn(db);assert.ok((await snapshot()).states.every(s=>s.length===0));});
 await check('old client projection write rejects entire recurrence batch',async()=>{await seed();const before=await snapshot();const room=before.room;
   const patch={continueTogether:!room.continueTogether,revision:room.revision+1,updatedAt:serverTimestamp()};
   const batch=writeBatch(db);batch.update(doc(db,'recruitments',recruitmentId),patch);batch.set(doc(db,'groups',room.groupId,'raidListings',recruitmentId),{...room,...patch});
   await assertRulesDenied(batch.commit());assert.deepEqual(await snapshot(),before);
 });
}finally{await env.cleanup();fs.writeFileSync('coverage/rules-group-source/lifecycle-results.json',JSON.stringify(results,null,2));}
console.log(`Passed ${results.length} additional boundaries`);
