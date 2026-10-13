import fs from 'node:fs';
import assert from 'node:assert/strict';
import {doc,deleteDoc} from 'firebase/firestore';
import {assertRulesDenied} from './assert_rules_denied.mjs';
import {removeApprovedMemberTxn,playerId,recruitmentId} from './party_group_cutover_rules_test.mjs';
process.env.GROUP_SOURCE_READ='1';
process.env.R1_LISTING='1';process.env.RULES_AUDIT='1';process.env.RULES_A1='1';
process.env.ROSTER_TRACKED_RULES='1';process.env.ROSTER_COMPLEXITY_RULES_FILE='firestore.rules';
const {runCleanupProof}=await import('./roster_completed_cleanup_proof.mjs');
const results=await runCleanupProof(null,async({env,db,seed,snapshot,cleanup,check})=>{
 const seedWithoutCopy=async options=>{
  const request=await seed(options);const before=await snapshot();
  await env.withSecurityRulesDisabled(ctx=>deleteDoc(doc(ctx.firestore(),'groups',before.room.groupId,'raidListings',recruitmentId)));
  return request;
 };
 await check('eight-member ownership cleanup without copy and duplicate receipt',async()=>{
  const request=await seedWithoutCopy();const before=await snapshot();
  await cleanup(db,request);const after=await snapshot();
  assert.equal(after.room.memberCount,7);assert.deepEqual(after.states,before.states);
  assert.equal(await cleanup(db,request),'already-applied');assert.deepEqual(await snapshot(),after);
 });
 for(const tamper of ['omit-member','omit-event','event-target','remaining-slot','delete-state','change-state']){
  await check(`cleanup ${tamper} denied atomically`,async()=>{
   const request=await seedWithoutCopy();const before=await snapshot();
   await assertRulesDenied(cleanup(db,request,tamper));assert.deepEqual(await snapshot(),before);
  });
 }
 await check('eight-member active removal without copy',async()=>{
  await seedWithoutCopy({active:true});await removeApprovedMemberTxn(db,playerId);
  const after=await snapshot();assert.equal(after.room.memberCount,7);assert.equal(after.states[1],null);
 });
},{skipRegression:true});
fs.writeFileSync('coverage/rules-group-source/cleanup-results.json',JSON.stringify(results,null,2));
