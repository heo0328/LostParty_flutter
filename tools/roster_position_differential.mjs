import fs from 'node:fs';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { runCutoverRegression } from './party_group_cutover_rules_test.mjs';
import { removeRepeatedPositionValidation, integratedBaseline, preserveExistingSlots, deduplicateCleanup, dispatchCleanupEvents } from './roster_complexity_candidate.mjs';
const baseline = dispatchCleanupEvents(deduplicateCleanup(preserveExistingSlots(integratedBaseline())));
const candidate = removeRepeatedPositionValidation(baseline);
const dir = new URL('../coverage/roster-position/', import.meta.url);
fs.mkdirSync(dir, {recursive:true});
const summary=[];
for (const [name,rules] of Object.entries({baseline,candidate})) {
  process.env.PARTY_RULES_CASE='character-placement';
  await runCutoverRegression(rules);
  const file=new URL(name+'.rules',dir);fs.writeFileSync(file,rules);
  const run=spawnSync(process.execPath,['tools/roster_participation_proof.mjs'],{
    encoding:'utf8',timeout:300000,env:{...process.env,ROSTER_COMPLEXITY_RULES_FILE:decodeURIComponent(file.pathname).replace(/^\/(?=[A-Z]:)/,'' )}});
  fs.writeFileSync(new URL(name+'.log',dir),(run.stdout??'')+(run.stderr??''));
  assert.equal(run.status,0,name+' participation failure');
  const passes=(run.stdout??'').split(/\r?\n/).filter(l=>l.startsWith('PASS PARTICIPATION:'));
  assert.ok(passes.length>0);
  summary.push({name,sha256:createHash('sha256').update(rules).digest('hex'),passes});
  fs.writeFileSync(new URL('results.json',dir),JSON.stringify(summary,null,2));
  console.log(name+' participation PASS '+passes.length);
}
assert.deepEqual(summary[0].passes,summary[1].passes);
