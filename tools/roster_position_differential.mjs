import fs from 'node:fs';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { runCutoverRegression } from './party_group_cutover_rules_test.mjs';
import { validateOnlyChangedSlots, removeRepeatedPositionValidation, integratedBaseline, preserveExistingSlots, deduplicateCleanup, dispatchCleanupEvents } from './roster_complexity_candidate.mjs';
const baseline = dispatchCleanupEvents(deduplicateCleanup(preserveExistingSlots(integratedBaseline())));
const candidate = validateOnlyChangedSlots(removeRepeatedPositionValidation(baseline));
const dir = new URL('../coverage/roster-position/', import.meta.url);
fs.mkdirSync(dir, {recursive:true});
const summary=[];
for (const [name,rules] of Object.entries({baseline,candidate})) {
  const file=new URL(name+'.rules',dir);fs.writeFileSync(file,rules);
  // Baseline placement already failed CI37122427787; retain that evidence.
  if (name === 'candidate') {
    process.env.PARTY_RULES_CASE='character-placement';
    process.env.RULES_POSITION_COVERAGE_DIR=fileURLToPath(dir);
    await runCutoverRegression(rules);
  }
  const run=spawnSync(process.execPath,['tools/roster_participation_proof.mjs'],{
    encoding:'utf8',timeout:300000,env:{...process.env,ROSTER_COMPLEXITY_RULES_FILE:decodeURIComponent(file.pathname).replace(/^\/(?=[A-Z]:)/,'' )}});
  fs.writeFileSync(new URL(name+'.log',dir),(run.stdout??'')+(run.stderr??''));
  assert.equal(run.status,0,name+' participation failure');
  const passes=(run.stdout??'').split(/\r?\n/).filter(l=>l.startsWith('PASS PARTICIPATION:'));
  assert.ok(passes.length>0);
  summary.push({name,sha256:createHash('sha256').update(rules).digest('hex'),passes});
  fs.writeFileSync(new URL('results.json',dir),JSON.stringify(summary,null,2));
  console.log(name+' participation PASS '+passes.length);
  if (name === 'candidate') {
    for (const script of ['tools/roster_peer_cleanup_proof.mjs', 'tools/roster_last_member_proof.mjs']) {
      const checked = spawnSync(process.execPath,[script],{
        encoding:'utf8',timeout:300000,env:{...process.env,LEADER_PROOF_SCOPE:'',ROSTER_TRACKED_RULES:'1',
          ROSTER_COMPLEXITY_RULES_FILE:decodeURIComponent(file.pathname).replace(/^\/(?=[A-Z]:)/,'')}});
      fs.writeFileSync(new URL(script.split('/').pop()+'.log',dir),(checked.stdout??'')+(checked.stderr??''));
      assert.equal(checked.status,0,script+' failed');
      const count=(checked.stdout??'').split(/\r?\n/).filter(l=>l.startsWith('PASS CLEANUP:')).length;
      assert.ok(count>0);console.log(script+' PASS '+count);
    }
  }
}
assert.deepEqual(summary[0].passes,summary[1].passes);
