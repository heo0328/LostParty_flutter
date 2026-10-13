import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {rulesFunction} from './roster_complexity_candidate.mjs';
execFileSync(process.execPath,['tools/integrate_roster_rules.mjs','--candidate-only'],{stdio:'pipe'});
const before=fs.readFileSync('coverage/rules-localization/before-group-source.rules','utf8');
const after=fs.readFileSync('firestore.rules','utf8');
const names=s=>[...s.matchAll(/function (\w+)\(/g)].map(m=>m[1]);
test('L1 removes exactly eleven projection functions and retains other bodies',()=>{
 const removed=names(before).filter(n=>!names(after).includes(n));
 assert.deepEqual(removed.sort(),['validPreparationListing','ownershipPersonalCompletionListing',
 'ownershipLeaderCleanupComposition','ownershipCleanupComposition','r1InitialListing','r1ListingTransition',
 'r1ListingCopy','r1ListingWrite','r1ListingBackfill','r1ListingCreate','r1ListingDelete'].sort());
 const changed=names(after).filter(n=>rulesFunction(before,n).text.replace(/\s/g,'')!==rulesFunction(after,n).text.replace(/\s/g,''));
 assert.deepEqual(changed.sort(),['validPreparationRecruitment','ownershipLastCompletedDisband',
 'ownershipLeaderCleanupAggregate','ownershipPeerCleanupAggregate','ownershipCleanupAggregate',
 'ownershipPersonalCompletionBoundary','canListRecruitment'].sort());
 assert.ok(!after.includes('raidListings'));
});
test('changed command bodies remove only projection conjuncts',()=>{
 for(const name of ['validPreparationRecruitment','ownershipLastCompletedDisband',
 'ownershipLeaderCleanupAggregate','ownershipPeerCleanupAggregate','ownershipCleanupAggregate','ownershipPersonalCompletionBoundary']){
   const a=rulesFunction(after,name).text.replace(/\s/g,'');
   const b=rulesFunction(before,name).text.replace(/\s/g,'');
   // A single contiguous removed conjunct must explain the entire difference.
   let left=0;while(a[left]===b[left]&&left<a.length)left++;
   let right=0;while(right<a.length-left&&a.at(-1-right)===b.at(-1-right))right++;
   const deleted=b.slice(left,b.length-right);
   assert.equal(a.slice(left,a.length-right),'',name);
   assert.match(deleted,/Listing|raidListings|CleanupComposition/,name);
 }
});
