// Compare the same authorization requests against both complete local sources.
// Adds a read-only probe match ONLY to emulator inputs, never deployment Rules.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc} from 'firebase/firestore';
const dir = 'coverage/rules-auth-direct';
const names = ['hasActiveBinding','currentPlayerId','isActiveOperator','isCurrentPlayerActive',
  'isCurrentGroupMember','isActiveGroupLeader','canApproveApplications'];
const probes = {
  binding: 'hasActiveBinding()', player: 'isCurrentPlayerActive()', operator: 'isActiveOperator()',
  member: "isCurrentGroupMember('g')", leader: "isActiveGroupLeader('g')",
  approval: "canApproveApplications('r')", identity: "currentPlayerId() == 'p'",
  fallback: 'hasActiveBinding() || true',
};
const cases = [
  {name:'active', expect:[1,1,1,1,1,1,1,1]},
  {name:'anonymous', anonymous:true, expect:[0,0,0,0,0,0,0,1]},
  {name:'missing binding', binding:null, expect:[0,0,0,0,0,0,0,1]},
  {name:'inactive binding', binding:{playerId:'p',status:'inactive'}, expect:[0,0,0,0,0,1,1,1]},
  // Approval helper historically relies on its caller's active binding guard.
  {name:'inactive player', player:{status:'inactive'}, expect:[1,0,0,1,0,1,1,1]},
  {name:'missing operator', operator:null, check:['operator'], expect:[0]},
  {name:'inactive operator', operator:{status:'inactive'}, check:['operator'], expect:[0]},
  {name:'missing player', player:null, check:['operator','player','leader'], expect:[0,0,0]},
  {name:'nonmember and nonleader', member:null, group:{leaderPlayerId:'other'}, check:['member','leader'], expect:[0,0]},
  {name:'delegated approval', room:{leaderPlayerId:'other'}, expect:[1,1,1,1,1,1,1,1]},
  {name:'no approval delegation', room:{leaderPlayerId:'other'}, recruitmentMember:{canApproveApplications:false}, check:['approval'], expect:[0]},
  {name:'missing approval member', room:{leaderPlayerId:'other'}, recruitmentMember:null, check:['approval'], expect:[0]},
];
const results=[];
for (const [label, path] of [['before',`${dir}/before-readable.rules`],['after','coverage/rules-localization/readable.rules']]) {
  const source=fs.readFileSync(path,'utf8');
  const rootEnd=source.lastIndexOf('\n  }'); assert.ok(rootEnd>0);
  const probeMatch=Object.entries(probes).map(([key,condition])=>
    `match /authDirectProbe/${key} { allow get: if ${condition}; }`).join('\n');
  const rules=source.slice(0,rootEnd)+'\n'+probeMatch+source.slice(rootEnd);
  const env=await initializeTestEnvironment({projectId:'demo-party-group-cutover',firestore:{host:'127.0.0.1',port:8080,rules}});
  try {
    for (const c of cases) {
      await env.clearFirestore();
      const rows={binding:['authBindings/u',{status:'active',playerId:'p'}], player:['players/p',{status:'active'}],
        operator:['operatorAssignments/p',{status:'active'}],member:['groups/g/members/p',{role:'member'}],
        group:['groups/g',{leaderPlayerId:'p'}],room:['recruitments/r',{leaderPlayerId:'p'}],
        recruitmentMember:['recruitments/r/members/p',{canApproveApplications:true}]};
      await env.withSecurityRulesDisabled(async ctx=>{
        for (const [key,[document,normal]] of Object.entries(rows)) {
          const value=key in c ? c[key] : normal;
          if(value!==null) await setDoc(doc(ctx.firestore(),document),value);
        }
      });
      const db=(c.anonymous?env.unauthenticatedContext():env.authenticatedContext('u')).firestore();
      const keys=c.check??Object.keys(probes);
      for(let i=0;i<keys.length;i++) {
        await (c.expect[i]?assertSucceeds:assertFails)(getDoc(doc(db,'authDirectProbe',keys[i])));
      }
      results.push({label,name:c.name,passed:true,requests:keys.length});
      console.log(`PASS ${label}: ${c.name}`);
    }
  } finally { await env.cleanup(); }
  if(label==='after') {
    const functions=[...source.matchAll(/function\s+(\w+)\s*\(/g)].map(m=>m[1]);
    const {rulesFunction}=await import('./roster_complexity_candidate.mjs');
    for(const n of names){const body=rulesFunction(source,n).text.split('{').slice(1).join('{');
      assert.equal(functions.some(f=>new RegExp(`\\b${f}\\s*\\(`).test(body)),false,`${n} must not call user functions`);}
  }
  fs.writeFileSync(`${dir}/${label}-tested-sha.json`,JSON.stringify({path,sha256:createHash('sha256').update(source).digest('hex')}));
}
fs.writeFileSync(`${dir}/auth-results.json`,JSON.stringify(results,null,2));
console.log('Full-source authorization comparison passed; same allowed/denied results.');
