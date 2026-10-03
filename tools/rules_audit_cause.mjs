import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { integratedBaseline } from './roster_complexity_candidate.mjs';
import { seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn, approvePublicApplicationTxn,
  seedPersistedAdvanceCycleMarker, repositionApprovedMemberTxn, kickApprovedMemberTxn, authUid } from './party_group_cutover_rules_test.mjs';
const gitRules=ref=>execFileSync('git',['show',`${ref}:firestore.rules`],{encoding:'utf8'}).replace(/\r\n/g,'\n');
const variants={operating:gitRules('68f0508'),integrated:integratedBaseline(),backupEquivalent:gitRules('4453f53'),current:fs.readFileSync('firestore.rules','utf8')};
const results=[];fs.mkdirSync('coverage/rules-audit',{recursive:true});
process.env.RULES_AUDIT='1';
for(const [name,rules] of Object.entries(variants)){
  const row={name,sha256:createHash('sha256').update(rules).digest('hex'),phase:'setup'};
  const env=await initializeTestEnvironment({projectId:'demo-party-group-cutover',firestore:{rules,host:'127.0.0.1',port:8080}});
  try{
    await env.clearFirestore();await seedBase(env);await seedJoiner(env);
    const db=env.authenticatedContext(authUid).firestore(),joiner=env.authenticatedContext('joiner-auth').firestore();
    await assertSucceeds(createPublicRecruitmentTxn(db));await assertSucceeds(applicationTxn(joiner,'apply'));await assertSucceeds(approvePublicApplicationTxn(db));
    await seedPersistedAdvanceCycleMarker(env);
    await assertFails(repositionApprovedMemberTxn(db,2,2,{skipMarkerConsumption:true}));
    await assertSucceeds(repositionApprovedMemberTxn(db));
    await seedPersistedAdvanceCycleMarker(env);row.phase='kick';
    await assertSucceeds(kickApprovedMemberTxn(db));row.passed=true;
  }catch(e){row.passed=false;row.error=e.message;}finally{await env.cleanup();}
  results.push(row);console.log(JSON.stringify(row));
}
fs.writeFileSync('coverage/rules-audit/cause-results.json',JSON.stringify(results,null,2));
// Diagnostic comparison expects a known failure; no change to functional expectations.
assert.equal(results.length,4);
