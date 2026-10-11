import fs from 'node:fs';
import assert from 'node:assert/strict';
import {doc, setDoc, updateDoc, serverTimestamp} from 'firebase/firestore';
import {authUid, playerId, recruitmentId} from './party_group_cutover_rules_test.mjs';
process.env.BUG024_IMPORT_ONLY = '1';
process.env.BUG024_SPARK_EVENT = '1';
const {env, db, admin, snapshot, seed, prepare, denied, replacement, second} = await import('./bug024_preparation_proof.mjs');
const results = [];
async function check(name, work) {
  try { await work(); results.push({name, passed:true}); }
  catch(e) { results.push({name, passed:false, error:e.message}); }
  console.log(JSON.stringify(results.at(-1)));
}
try {
  await check('8-member repeated preparation preserves private records', async()=>{
    await seed({actorLast:true}); const before=await snapshot();
    await prepare(); await prepare({id:second}); await prepare({id:replacement});
    const after=await snapshot();
    for(const key of ['states','claims']) assert.deepEqual(after[key],before[key]);
    assert.deepEqual(after.listing,after.room);
  });
  for(const omit of ['room','member','listing','event']) await check(`missing ${omit}`,async()=>{
    await seed(); await denied(()=>prepare({omit}));
  });
  for(const tamper of ['privilege','other-permission','other-slot','complete-status','delete-old','delete-new','write-new'])
    await check(tamper,async()=>{await seed({targetState:'same'});await denied(()=>prepare({tamper}));});
  await check('inactive binding',async()=>{
    await seed();await admin(adb=>updateDoc(doc(adb,'authBindings',authUid),{status:'inactive'}));
    await denied(()=>prepare());
  });
  await check('member identity cannot be changed',async()=>{
    await seed();await denied(()=>updateDoc(doc(db,'recruitments',recruitmentId,'members',playerId),{playerId:'forged'}));
  });
  await check('event cannot be reused or written alone',async()=>{
    await seed();await prepare();const state=await snapshot();
    const event=state.events.find(e=>e.type==='characterChanged');assert.ok(event);
    const {id,...data}=event;
    await denied(()=>setDoc(doc(db,'partyEvents',id),data));
    await seed();await denied(()=>setDoc(doc(db,'partyEvents',id),{...data,occurredAt:serverTimestamp()}));
  });
} finally {
  fs.writeFileSync('coverage/rules-prep-dedup/results.json',JSON.stringify(results,null,2));
  await env.cleanup();
}
assert.ok(results.every(r=>r.passed),'Preparation regression failed');
