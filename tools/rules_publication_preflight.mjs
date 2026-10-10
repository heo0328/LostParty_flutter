// Read/check local deployment artifacts only. Never calls Firebase APIs.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {compactExecutableRules} from './rules_executable_compact.mjs';
const budget=JSON.parse(fs.readFileSync('tools/rules_publication_budget.json','utf8'));
const config=JSON.parse(fs.readFileSync('firebase.json','utf8'));
assert.equal(config.firestore.rules,'firestore.rules');
// Rebuild deterministically without changing the deployment path.
execFileSync(process.execPath,['tools/integrate_roster_rules.mjs','--candidate-only'],{stdio:'pipe'});
const source=fs.readFileSync('firestore.rules'),candidate=fs.readFileSync('coverage/rules-localization/candidate.rules');
assert.ok(source.equals(candidate),'Tracked Rules differ from their generator. Review before publication.');
const sha256=createHash('sha256').update(source).digest('hex');
const compact=compactExecutableRules(fs.readFileSync('coverage/rules-localization/readable.rules','utf8')).source;
const compactSha256=createHash('sha256').update(compact).digest('hex');
const compactBytes=Buffer.byteLength(compact);
const depth=JSON.parse(execFileSync(process.execPath,['tools/rules_call_depth_audit.mjs',
  'coverage/rules-localization/readable.rules',compactSha256],{encoding:'utf8'}));
const result={sha256,sourceBytes:source.length,compactSha256,compactBytes,
  removedCompactBytes:budget.baselineSourceBytes-compactBytes,
  maximumUserFunctionDepth:depth.maximumUserFunctionDepth,
  functionCount:[...fs.readFileSync('coverage/rules-localization/readable.rules','utf8').matchAll(/\bfunction\s+\w+\s*\(/g)].length,
  publicationVerified:false};
fs.writeFileSync('coverage/rules-localization/preflight.json',JSON.stringify(result,null,2));
assert.ok(compactBytes<=budget.maximumSourceBytes,'Rules content grew beyond reviewed compact budget');
assert.ok(source.length<256*1024,'Formatted Rules exceed source size limit');
assert.ok(depth.maximumUserFunctionDepth<=budget.maximumUserFunctionDepth,'Rules call depth grew beyond reviewed budget');
console.log(JSON.stringify(result,null,2));
