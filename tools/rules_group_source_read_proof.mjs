import fs from 'node:fs';
import assert from 'node:assert/strict';
import {collection,doc,getDocs,getDoc,setDoc,deleteDoc,query,where,updateDoc} from 'firebase/firestore';
import {assertSucceeds} from '@firebase/rules-unit-testing';
import {assertRulesDenied} from './assert_rules_denied.mjs';
import {recruitmentId,playerId,raidId,disbandApprovedRoomTxn} from './party_group_cutover_rules_test.mjs';
process.env.GROUP_SOURCE_READ='1';
process.env.GROUP_SOURCE_PROJECT_ID=`demo-group-source-${Date.now()}`;
process.env.R1_LISTING='1';
process.env.RULES_AUDIT='1';
process.env.BUG024_IMPORT_ONLY='1';
process.env.BUG024_SPARK_EVENT='1';
process.env.BUG024_RULES_FILE='firestore.rules';
const {env,db,admin,snapshot,seed,prepare,denied,lifecycle}=await import('./bug024_preparation_proof.mjs');
const results=[];
const check=async(name,fn)=>{await fn();results.push(name);console.log('PASS '+name);};
const groupQuery=(client,gid)=>query(collection(client,'recruitments'),
  where('groupId','==',gid),where('visibility','==','group'),where('schemaVersion','==',2),
  where('status','==','active'),where('manualRecruitmentEnabled','==',true),where('hasAvailableSlot','==',true));
try {
 await seed({missingListing:true});
 const room=(await snapshot()).room;
 const gid=room.groupId;
 const member=env.authenticatedContext('group-only').firestore();
 const outsider=env.authenticatedContext('outsider').firestore();
 await admin(async adb=>{
   for(const id of ['group-only','outsider']){
     await setDoc(doc(adb,'authBindings',id),{playerId:id,status:'active'});
     await setDoc(doc(adb,'players',id),{status:'active'});
   }
   await setDoc(doc(adb,'groups',gid,'members','group-only'),{playerId:'group-only'});
   await updateDoc(doc(adb,'recruitments',recruitmentId),{manualRecruitmentEnabled:true,hasAvailableSlot:true});
 });
 await check('group nonparticipant queries source without a listing',async()=>assert.equal((await getDocs(groupQuery(member,gid))).size,1));
 await check('outsider source query denied',()=>assertRulesDenied(getDocs(groupQuery(outsider,gid))));
 await check('other group query denied',()=>assertRulesDenied(getDocs(groupQuery(member,'other-group'))));
 await check('unscoped source query denied',()=>assertRulesDenied(getDocs(collection(member,'recruitments'))));
 await check('anonymous query denied',()=>assertRulesDenied(getDocs(groupQuery(env.unauthenticatedContext().firestore(),gid))));
 await check('retired projection read/write denied',async()=>{
   await assertRulesDenied(getDoc(doc(member,'groups',gid,'raidListings',recruitmentId)));
   await assertRulesDenied(setDoc(doc(db,'groups',gid,'raidListings',recruitmentId),room));
 });
 await check('group leave revokes source query',async()=>{
   await admin(adb=>deleteDoc(doc(adb,'groups',gid,'members','group-only')));
   await assertRulesDenied(getDocs(groupQuery(member,gid)));
 });
 await check('rejoin restores source query',async()=>{
   await admin(adb=>setDoc(doc(adb,'groups',gid,'members','group-only'),{playerId:'group-only'}));
   await assertSucceeds(getDocs(groupQuery(member,gid)));
 });
 await check('inactive binding denies source query',async()=>{
   await admin(adb=>updateDoc(doc(adb,'authBindings','group-only'),{status:'inactive'}));
   await assertRulesDenied(getDocs(groupQuery(member,gid)));
 });
 await check('eight member preparation with no copy preserves completed states',async()=>{
   await seed({missingListing:true});const before=await snapshot();await prepare();
   const after=await snapshot();assert.deepEqual(after.states,before.states);assert.equal(after.listing,undefined);
 });
 for(const omit of ['room','member','event'])await check(`preparation missing ${omit} denied atomically`,async()=>{await seed({missingListing:true});await denied(()=>prepare({omit}));});
 for(const tamper of ['privilege','other-slot','complete-status'])await check(`preparation ${tamper} denied`,async()=>{await seed();await denied(()=>prepare({tamper}));});
 await check('stale revision denied',async()=>{await seed();await denied(()=>prepare({expectedRevision:1}));});
 await check('completed disband preserves eight completed states',async()=>{await seed({missingListing:true});const before=await snapshot();await disbandApprovedRoomTxn(db);assert.deepEqual((await snapshot()).states,before.states);});
 async function active(){await seed({missingListing:true});await admin(async adb=>{
   const r=(await getDoc(doc(adb,'recruitments',recruitmentId))).data();
   await updateDoc(doc(adb,'recruitments',recruitmentId),{currentCycleStatus:'active'});
   for(const slot of r.partySlots)await updateDoc(doc(adb,'players',slot.playerId,'raidStates',`${slot.characterId}_${raidId}`),{status:'active'});
 });}
 await check('eight member completion without copy',async()=>{await active();await lifecycle(db,'complete',{completionRole:true});});
 for(const tamper of ['omit-state','target-player','target-state'])await check(`completion ${tamper} denied atomically`,async()=>{await active();await denied(()=>lifecycle(db,'complete',{completionRole:true,tamper}));});
 await check('nonleader completion denied',async()=>{await active();await denied(()=>lifecycle(env.authenticatedContext('joiner-auth').firestore(),'complete',{completionRole:true,actorPlayerId:'player-2'}));});
} finally {await env.cleanup();fs.writeFileSync('coverage/rules-group-source/server-results.json',JSON.stringify(results,null,2));}
console.log(`Passed ${results.length} exact-source boundaries`);
