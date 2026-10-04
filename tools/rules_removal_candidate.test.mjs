import fs from 'node:fs';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { prioritizeMemberRemoval, rulesFunction } from './roster_complexity_candidate.mjs';
const before=fs.readFileSync('firestore.rules','utf8').replace(/\r\n/g,'\n');
const after=prioritizeMemberRemoval(before);
test('only one allow changes; helpers and guarded reordered predicates are preserved',()=>{
  for(const [,name] of before.matchAll(/    function (\w+)\(/g))assert.equal(rulesFunction(before,name).text,rulesFunction(after,name).text);
  const allows=s=>[...s.matchAll(/allow\s[\s\S]*?;/g)].map(m=>m[0]);
  const a=allows(before),b=allows(after);assert.equal(a.length,b.length);assert.equal(a.filter((x,i)=>x!==b[i]).length,1);
  const tokens=s=>s.match(/'(?:\\.|[^'\\])*'|\w+|[^\s]/g).filter(t=>t!=='('&&t!==')').sort();
  assert.deepEqual(tokens(before),tokens(after.replace('request.resource.data.memberCount == resource.data.memberCount - 1 && ','')));
  const changed=b.find((x,i)=>x!==a[i]);
  assert.ok(changed.indexOf('validAtomicRecruitmentMemberRemoval(')<changed.indexOf("== 'cleanupCompletedLeaderOwnership'"));
  assert.ok(changed.indexOf('dePeerCleanupAggregate(')<changed.indexOf('validAtomicRecruitmentMemberRemoval('));
});
test('removal count guard cannot outlive its validator implication',()=>{
  const f=rulesFunction(before,'validAtomicRecruitmentMemberRemoval');
  assert.throws(()=>prioritizeMemberRemoval(before.replace(f.text,f.text.replace('&& newData.memberCount == oldData.memberCount - 1','&& true'))));
});
