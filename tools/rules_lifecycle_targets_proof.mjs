// Predicate isolation complements the exact full-source lifecycle regression.
// It exercises the actual Rules bodies from both revisions, not a JS replica.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {initializeTestEnvironment, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc,deleteDoc,writeBatch} from 'firebase/firestore';
import {assertRulesDenied} from './assert_rules_denied.mjs';
import {rulesFunction} from './roster_complexity_candidate.mjs';

const before=execFileSync('git',['show','6e7bd11:firestore.rules'],{encoding:'utf8'});
const after=fs.readFileSync('firestore.rules','utf8');
const results=[];
const names=['atomicRaidStatePath','atomicTargetStateMatches','atomicTargetMatchesTransition',
  'atomicAllTargetsMatch','atomicExpectedTargetStateMatches','atomicExpectedTargetMatches','atomicAllExpectedTargetsMatch'];
for(const [label,source] of [['before',before],['after',after]]) {
  const functions=names.filter(name=>source.includes(`function ${name}(`))
    .map(name=>rulesFunction(source,name).text).join('\n');
  const rules=`rules_version = '2'; service cloud.firestore { match /databases/{database}/documents {
    ${functions}
    match /probes/{id} { allow create: if atomicAllTargetsMatch(request.resource.data); }
    match /players/{player}/raidStates/{state} { allow write: if true; }
  } }`;
  const env=await initializeTestEnvironment({projectId:`demo-lifecycle-targets-${label}`,
    firestore:{host:'127.0.0.1',port:8080,rules}});
  const db=env.authenticatedContext('actor').firestore();
  const cases=[
    ['complete8','complete',8,true],['advance8','advanceCycle',8,true],['disband8','disband',8,true],
    ['last-status','complete',8,false,'status'],['last-cycle','advanceCycle',8,false,'cycleKey'],
    ['last-room','complete',8,false,'recruitmentId'],['last-absent','advanceCycle',8,false,'absent'],
    ['disband-retained','disband',8,false,'retained'],['over-capacity','complete',9,false],
    ['empty-complete','complete',0,false],['empty-advance','advanceCycle',0,false],
    ['empty-incomplete','incompleteEnd',0,true],['empty-completed-disband','disband',0,true],
    ['empty-active-disband','disband',0,false,'active'],['nonempty-incomplete','incompleteEnd',8,false],
    ['unknown-command','forged',8,false],
  ];
  try {
    for(const [name,type,count,allowed,tamper] of cases) {
      await env.clearFirestore();
      const targets=Array.from({length:count},(_,i)=>({playerId:`p${i}`,stateId:`s${i}`}));
      await env.withSecurityRulesDisabled(async ctx=>{
        for(const [i,target] of targets.entries()) await setDoc(doc(ctx.firestore(),
          'players',target.playerId,'raidStates',target.stateId),{
          recruitmentId:tamper==='recruitmentId'&&i===7?'other':'room',
          cycleKey:tamper==='cycleKey'&&i===7?'other':'cycle',
          status:tamper==='status'&&i===7?'active':type==='complete'?'completed':'active',
        });
      });
      const batch=writeBatch(db);
      if(type==='disband') for(const [i,target] of targets.entries()) {
        if(tamper==='retained'&&i===7) continue;
        batch.delete(doc(db,'players',target.playerId,'raidStates',target.stateId));
      }
      if(tamper==='absent') batch.delete(doc(db,'players','p7','raidStates','s7'));
      batch.set(doc(db,'probes',name),{lastCommandType:type,commandTargets:targets,
        recruitmentId:'room',currentCycleKey:'cycle',currentCycleStatus:tamper==='active'?'active':'completed'});
      if(allowed) await assertSucceeds(batch.commit()); else await assertRulesDenied(batch.commit());
      results.push({label,name,allowed,passed:true});
    }
  } finally {await env.cleanup();}
}
fs.mkdirSync('coverage/rules-lifecycle-targets',{recursive:true});
fs.writeFileSync('coverage/rules-lifecycle-targets/predicate-results.json',JSON.stringify(results,null,2));
assert.equal(results.length,32);
console.log('Actual before/after Rules predicate boundary decisions agree; 8-target writes/deletes included.');
