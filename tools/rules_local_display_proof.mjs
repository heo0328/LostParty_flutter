import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,writeBatch,Timestamp,serverTimestamp} from 'firebase/firestore';
import {assertRulesDenied} from './assert_rules_denied.mjs';
const directory='coverage/rules-localization',file=process.env.PARTY_RULES_FILE||`${directory}/candidate.rules`;
const rules=fs.readFileSync(file,'utf8'),sha256=createHash('sha256').update(rules).digest('hex'),results=[];
const env=await initializeTestEnvironment({projectId:'demo-party-group-cutover',firestore:{host:'127.0.0.1',port:8080,rules}});
const now=Timestamp.fromMillis(Date.now()-60000),expiry=Timestamp.fromMillis(Date.now()+24*3600000);
const paths=['players/p/groupRelations/g','groups/g/applicantStats/p','groups/g/blockedPlayers/p','groups/g/joinRelations/p','groups/g/members/p'];
async function seed(kind='application',status='pending',member=false){await env.clearFirestore();await env.withSecurityRulesDisabled(async ctx=>{
  const db=ctx.firestore(),b=writeBatch(db);
  for(const p of ['p','leader','outsider']){b.set(doc(db,`authBindings/${p}`),{playerId:p,status:'active'});b.set(doc(db,`players/${p}`),{status:'active'});}
  b.set(doc(db,'groups/g'),{status:'active',name:'original',leaderPlayerId:'leader',memberCount:member?2:1});
  b.set(doc(db,'groups/g/members/leader'),{playerId:'leader',role:'leader'});
  b.set(doc(db,paths[3]),{targetPlayerId:'p',kind,status,characterNameSnapshot:'original',itemLevelSnapshot:1600,
    combatPowerSnapshot:100,applicationAttempt:1,revision:2,expiresAt:expiry});
  if(member)b.set(doc(db,paths[4]),{playerId:'p',joinedBy:member,revision:3,displayCharacterNameSnapshot:'original'});
  await b.commit();
});}
function projection(kind='applied',status='pending'){return {schemaVersion:1,groupId:'g',playerId:'p',relation:kind,requestStatus:status,
  groupNameSnapshot:'local group',displayCharacterNameSnapshot:'local name',expiresAt:kind==='member'?null:expiry,
  sourceRevision:kind==='member'?3:2,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};}
async function snapshot(){let result;await env.withSecurityRulesDisabled(async ctx=>{result=await Promise.all(paths.map(async p=>(await getDoc(doc(ctx.firestore(),p))).data()??null));});return result;}
function write(path,data,actor='p'){const db=actor===null?env.unauthenticatedContext().firestore():env.authenticatedContext(actor).firestore(),b=writeBatch(db);b.set(doc(db,path),data);return b.commit();}
async function deny(work){const before=await snapshot();await assertRulesDenied(work());assert.deepEqual(await snapshot(),before);}
async function check(name,work){if(process.env.DISPLAY_CHECK_FILTER&&!name.includes(process.env.DISPLAY_CHECK_FILTER))return;
  try{await work();results.push({name,passed:true});}catch(e){results.push({name,passed:false,error:e.message});throw e;}
  finally{fs.writeFileSync(`${directory}/display${process.env.DISPLAY_CHECK_FILTER?'-filtered':''}-results.json`,JSON.stringify({sha256,results},null,2));}}
try{
 for(const [name,kind,status,member,actor,view,viewStatus] of [
  ['request','application','pending',false,'p','applied','pending'],
  ['invitation','invitation','pending',false,'leader','invited','pending'],
  ['initial','application','accepted','created','p','member',null],
  ['accepted invitation','invitation','accepted','invitation','p','member','accepted'],
  ['leader approval','application','accepted','application','leader','member','accepted'],
  ['join code','application','rejected','joinCode','p','member',null],
 ])await check(`display decoupled ${name}`,async()=>{await seed(kind,status,member);await write(paths[0],projection(view,viewStatus),actor);});
 for(const [field,value] of [['schemaVersion',2],['groupId','other'],['playerId','other'],['sourceRevision',99],
  ['requestStatus','accepted'],['expiresAt',now],['updatedAt',now],['createdAt','bad'],['groupNameSnapshot',7],
  ['displayCharacterNameSnapshot','a'.repeat(257)],['extra',true]])await check(`projection rejects ${field}`,async()=>{
    await seed();await deny(()=>write(paths[0],{...projection(),[field]:value}));});
 for(const actor of ['outsider',null])await check(`projection rejects actor ${actor}`,async()=>{await seed();await deny(()=>write(paths[0],projection(),actor));});
 for(const path of ['groups/g',paths[3]])await check(`projection rejects absent ${path}`,async()=>{
  await seed();await env.withSecurityRulesDisabled(async ctx=>{const b=writeBatch(ctx.firestore());b.delete(doc(ctx.firestore(),path));await b.commit();});
  await deny(()=>write(paths[0],projection()));
 });
 const stats=()=>({schemaVersion:1,groupId:'g',playerId:'p',applicationCount:1,lastCharacterNameSnapshot:'local',
   lastItemLevelSnapshot:1700,lastCombatPowerSnapshot:200,createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
 await check('stats display copies need not equal relation',async()=>{await seed();await write(paths[1],stats());});
 for(const [field,value] of [['applicationCount',2],['playerId','other'],['groupId','other'],['lastItemLevelSnapshot','bad'],['updatedAt',now]])
 await check(`stats rejects ${field}`,async()=>{await seed();await deny(()=>write(paths[1],{...stats(),[field]:value}));});
 await check('stats rejects wrong actor',async()=>{await seed();await deny(()=>write(paths[1],stats(),'leader'));});
 await check('stats rejects nonpending relation',async()=>{await seed('application','rejected');await deny(()=>write(paths[1],stats()));});
 const block=()=>({schemaVersion:1,groupId:'g',playerId:'p',blockedByPlayerId:'leader',reason:'applicationRejected',
  characterNameSnapshot:'local',applicationCountSnapshot:1,itemLevelSnapshot:1800,combatPowerSnapshot:300,
  createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
 async function blockSeed(){await seed('application','blocked');await env.withSecurityRulesDisabled(async ctx=>{
  const b=writeBatch(ctx.firestore());b.set(doc(ctx.firestore(),paths[1]),{applicationCount:1});await b.commit();});}
 await check('block display copies decoupled but real count retained',async()=>{await blockSeed();await write(paths[2],block(),'leader');});
 for(const [field,value] of [['applicationCountSnapshot',99],['blockedByPlayerId','p'],['playerId','other'],['reason','bad'],['combatPowerSnapshot','bad']])
 await check(`block rejects ${field}`,async()=>{await blockSeed();await deny(()=>write(paths[2],{...block(),[field]:value},'leader'));});
 await check('block rejects nonleader',async()=>{await blockSeed();await deny(()=>write(paths[2],block()));});
 async function applicationSeed(){await seed();await env.withSecurityRulesDisabled(async ctx=>{
   const b=writeBatch(ctx.firestore());b.delete(doc(ctx.firestore(),paths[3]));await b.commit();});}
 function apply(omit=''){
   const db=env.authenticatedContext('p').firestore(),b=writeBatch(db),t=serverTimestamp();
   if(omit!=='request')b.set(doc(db,paths[3]),{schemaVersion:1,groupId:'g',targetPlayerId:'p',kind:'application',status:'pending',
     requestedByPlayerId:'p',characterIdSnapshot:'c',characterNameSnapshot:'original',serverNameSnapshot:'server',
     characterClassNameSnapshot:'class',itemLevelSnapshot:1600,combatPowerSnapshot:100,gemValidationSnapshot:null,
     applicationAttempt:1,revision:1,createdAt:t,expiresAt:expiry,decidedAt:null,updatedAt:t});
   if(omit!=='stats')b.set(doc(db,paths[1]),stats());
   if(omit!=='projection')b.set(doc(db,paths[0]),{...projection(),sourceRevision:1});
   return b.commit();
 }
 await check('real application batch accepts local informational copies',async()=>{await applicationSeed();await apply();});
 for(const omit of ['request','stats','projection'])await check(`application atomically rejects missing ${omit}`,async()=>{
   await applicationSeed();await deny(()=>apply(omit));
 });
 for(const [kind,status,member,actor] of [
   ['invitation','rejected',false,'p'],['invitation','cancelled',false,'leader'],
   ['invitation','accepted','invitation','p'],['application','rejected',false,'leader'],
   ['application','accepted','application','leader'],['application','accepted','joinCode','p'],
 ])await check(`dispatch preserves ${kind} ${status} ${member}`,async()=>{
   await seed(kind,'pending',member);const db=env.authenticatedContext(actor).firestore(),b=writeBatch(db),t=serverTimestamp();
   b.update(doc(db,paths[3]),{status,revision:3,decidedAt:t,updatedAt:t});
   b.set(doc(db,paths[0]),{...projection(member?'member':kind==='invitation'?'invited':'applied',status),sourceRevision:3});
   await b.commit();
 });
 await check('dispatch rejects decision by outsider atomically',async()=>{
   await seed();await deny(()=>{const db=env.authenticatedContext('outsider').firestore(),b=writeBatch(db);
     b.update(doc(db,paths[3]),{status:'rejected',revision:3,decidedAt:serverTimestamp(),updatedAt:serverTimestamp()});
     b.set(doc(db,paths[0]),{...projection('applied','rejected'),sourceRevision:3});return b.commit();});
 });
 for(const [kind,previous,allowed] of [
   ['invitation','new',true],['invitation','rejected',true],
   ['application','rejected',true],['application','expired',true],
   ['invitation','pending',false],['application','pending',false],
 ])await check(`remaining ${kind} ${previous}`,async()=>{
   await seed(kind,previous==='expired'?'pending':previous);
   await env.withSecurityRulesDisabled(async ctx=>{
     const db=ctx.firestore(),b=writeBatch(db);
     if(previous==='new')b.delete(doc(db,paths[3]));
     if(previous==='expired')b.update(doc(db,paths[3]),{expiresAt:now});
     if(kind==='application')b.set(doc(db,paths[1]),{...stats(),applicationCount:1,createdAt:now,updatedAt:now});
     await b.commit();
   });
   const work=()=>{
     const actor=kind==='invitation'?'leader':'p',db=env.authenticatedContext(actor).firestore(),b=writeBatch(db),t=serverTimestamp();
     const attempt=kind==='application'?2:previous==='new'?0:1, revision=previous==='new'?1:3;
     b.set(doc(db,paths[3]),{schemaVersion:1,groupId:'g',targetPlayerId:'p',kind,status:'pending',
       requestedByPlayerId:actor,characterIdSnapshot:'c',characterNameSnapshot:'original',serverNameSnapshot:'server',
       characterClassNameSnapshot:'class',itemLevelSnapshot:1600,combatPowerSnapshot:100,gemValidationSnapshot:null,
       applicationAttempt:attempt,revision,createdAt:t,expiresAt:expiry,decidedAt:null,updatedAt:t});
     b.set(doc(db,paths[0]),{...projection(kind==='invitation'?'invited':'applied'),sourceRevision:revision});
     if(kind==='application')b.set(doc(db,paths[1]),{...stats(),applicationCount:2,createdAt:now});
     return b.commit();
   };
   if(allowed)await work();else await deny(work);
 });
 for(const omitBlock of [false,true])await check(`remaining blocked omit=${omitBlock}`,async()=>{
   await seed();await env.withSecurityRulesDisabled(async ctx=>{
     const db=ctx.firestore();const b=writeBatch(db);b.set(doc(db,paths[1]),{applicationCount:1});await b.commit();
   });
   const work=()=>{const db=env.authenticatedContext('leader').firestore(),b=writeBatch(db),t=serverTimestamp();
     b.update(doc(db,paths[3]),{status:'blocked',revision:3,decidedAt:t,updatedAt:t});
     b.set(doc(db,paths[0]),{...projection('applied','blocked'),sourceRevision:3});
     if(!omitBlock)b.set(doc(db,paths[2]),block());return b.commit();};
   if(omitBlock)await deny(work);else await work();
 });
 console.log(`${results.length} display/authority checks passed`);
}finally{await env.cleanup();}
