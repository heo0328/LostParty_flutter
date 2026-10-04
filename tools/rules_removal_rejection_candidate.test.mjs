import fs from 'node:fs';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { rulesFunction } from './roster_complexity_candidate.mjs';
import { boundRemovalRejections } from './rules_removal_rejection_candidate.mjs';
const before = fs.readFileSync('firestore.rules', 'utf8').replace(/\r\n/g, '\n');
const after = boundRemovalRejections(before);
test('listing reorders identical conditions; every other validator is unchanged', () => {
  for (const [, name] of before.matchAll(/    function (\w+)\(/g)) {
    const a = rulesFunction(before, name).text, b = rulesFunction(after, name).text;
    if (name === 'validAtomicMemberRemovalListingUpdate') {
      const tokens = s => s.match(/\w+|[^\s]/g).sort();
      assert.deepEqual(tokens(a), tokens(b));
      assert.ok(b.indexOf('newData.memberCount ==') < b.indexOf('&& validAtomicRecruitmentMemberRemoval('));
    } else assert.equal(a, b, name);
  }
});
test('ordinary marker contract cannot silently diverge', () => {
  const f = rulesFunction(before, 'validAtomicRecruitmentJoin');
  assert.throws(() => boundRemovalRejections(before.replace(f.text,
    f.text.replace('atomicLifecycleMarkerConsumedOrPreserved(oldData, newData)', 'true'))));
});
