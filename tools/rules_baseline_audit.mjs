// Every suite reads the same tracked source; no candidate transforms or remote requests.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
const source=fs.readFileSync('firestore.rules');
const sha256=createHash('sha256').update(source).digest('hex');
const dir='coverage/rules-audit';fs.mkdirSync(dir,{recursive:true});
const suites=['party_group_cutover_rules_test','group_leave_rules_test','character_activity_rules_test',
  'manual_verification_rules_test','roster_generation_proof','roster_participation_proof',
  'roster_occupancy_proof','roster_manual_completion_proof','roster_personal_completion_proof',
  'roster_peer_cleanup_proof','roster_last_member_proof','roster_orphan_cleanup_proof'];
const results=[];
for(const suite of suites){
  const run=spawnSync(process.execPath,[`tools/${suite}.mjs`],{encoding:'utf8',timeout:180000,
    env:{...process.env,ROSTER_TRACKED_RULES:'1',ROSTER_COMPLEXITY_RULES_FILE:path.resolve('firestore.rules'),
      RULES_AUDIT:'1',PARTY_RULES_CASE:'full',LEADER_PROOF_SCOPE:'',FIRESTORE_EMULATOR_HOST:'127.0.0.1:8080'}});
  const output=(run.stdout??'')+(run.stderr??'');fs.writeFileSync(`${dir}/${suite}.log`,output);
  const passes=output.split(/\r?\n/).filter(x=>/^PASS\b/.test(x));
  const failures=output.split(/\r?\n/).filter(x=>/^FAIL\b/.test(x));
  results.push({suite,sha256,status:run.status,signal:run.signal,error:run.error?.message,passes,failures});
  fs.writeFileSync(`${dir}/baseline-results.json`,JSON.stringify(results,null,2));
  console.log(`${suite}: exit=${run.status} passes=${passes.length} failures=${failures.length}`);
}
if(results.some(r=>r.status!==0))process.exitCode=1;
