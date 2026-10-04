import assert from 'node:assert/strict';
import { test } from 'node:test';
import { targetScanCandidate } from './rules_target_scan_candidate.mjs';
import { memberRemovalBaseline, rulesFunction } from './roster_complexity_candidate.mjs';
import { simplifyGroupDisplay } from './rules_group_display_candidate.mjs';
const before = targetScanCandidate(memberRemovalBaseline());
const after = simplifyGroupDisplay(before);
test('display simplification leaves allows and every unrelated helper intact', () => {
  const changed = new Set(['validGroupMemberOptionalNumberFields', 'validGroupMemberSnapshotsFromRelation',
    'validGroupMemberSnapshotsFromCharacter', 'validGroupMemberSelfSnapshotRefresh',
    'validInitialGroupMember', 'validInvitedGroupMember', 'validApprovedGroupMember', 'validJoinCodeGroupMember']);
  for (const [, name] of before.matchAll(/function (\w+)\(/g))
    if (!changed.has(name)) assert.equal(rulesFunction(after, name).text, rulesFunction(before, name).text);
  const allows = s => [...s.matchAll(/allow\s[^:]+:[\s\S]*?;/g)].map(m => m[0]);
  assert.deepEqual(allows(after), allows(before));
  for (const name of ['validInitialGroupMember','validInvitedGroupMember','validApprovedGroupMember','validJoinCodeGroupMember']) {
    assert.equal(rulesFunction(after,name).text, rulesFunction(before,name).text
      .replace('validGroupMemberSnapshotsFromRelation(data, relation)', 'validGroupMemberOptionalNumberFields(data)')
      .replace(/validGroupMemberSnapshotsFromCharacter\(\s*data,\s*data\.displayCharacterIdSnapshot\s*\)/g,
        'validGroupMemberOptionalNumberFields(data)'));
  }
  assert.ok(Buffer.byteLength(after) < Buffer.byteLength(before));
});
