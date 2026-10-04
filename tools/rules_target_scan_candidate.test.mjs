import { memberRemovalBaseline } from './roster_complexity_candidate.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { compactTargetScans, targetScanCandidate, compactCleanupComposition, dispatchGroupRecruitmentCount, skipCompletedMembershipFallbacks, reuseOwnershipReads } from './rules_target_scan_candidate.mjs';
import { rulesFunction, prioritizeMemberRemoval } from './roster_complexity_candidate.mjs';
const baseline = memberRemovalBaseline();
const candidate = compactTargetScans(baseline);
test('foreign stale cleanup rejects before ownership reads without changing conditions', () => {
  const name = 'validAtomicStaleRaidStateDelete';
  const before = rulesFunction(baseline, name).text;
  const after = rulesFunction(targetScanCandidate(baseline), name).text;
  const tokens = text => text.match(/\w+|[^\s]/g).sort();
  assert.deepEqual(tokens(before), tokens(after));
  assert.ok(after.indexOf('playerId == currentPlayerId()') < after.indexOf('deManualCurrentOwnership(oldData)'));
});
test('target scan keeps every index and legacy extra fields; no permission predicate changes', () => {
  const changed = new Set(['atomicCommandIncludes', 'atomicTargetAt', 'atomicRaidStateListedInTargets', 'atomicRaidStateTargetAt']);
  for (const [, name] of baseline.matchAll(/    function (\w+)\(/g)) {
    if (!changed.has(name)) assert.equal(rulesFunction(candidate, name).text, rulesFunction(baseline, name).text);
  }
  for (const [name, field] of [['atomicCommandIncludes', 'commandTargets'], ['atomicRaidStateListedInTargets', 'raidStateTargets']]) {
    const body = rulesFunction(candidate, name).body.replaceAll('targets.size()', 'targets.length');
    // Executes the generated boolean expression for well-formed contract maps.
    const evaluate = new Function('data', 'recruitment', 'playerId', 'stateId', body);
    for (let size = 0; size <= 9; size++) for (let match = -1; match < size; match++) {
      const targets = Array.from({ length: size }, (_, i) => ({ playerId: i === match ? 'p' : 'other', stateId: 's', legacyExtra: true,
        diff(expected) { return { unchangedKeys: () => ({ hasAll: keys => keys.every(key => this[key] === expected[key]) }) }; } }));
      const data = { [field]: targets };
      assert.equal(evaluate(data, data, 'p', 's'), match >= 0 && match < 8);
      assert.equal(evaluate(data, data, 'p', 'wrong'), false);
    }
  }
});

test('cleanup composition retains all required fields and revision/time checks', () => {
  const before = rulesFunction(baseline, 'deCleanupComposition');
  const afterSource = compactCleanupComposition(baseline);
  const after = rulesFunction(afterSource, 'deCleanupComposition');
  const keys = [...before.body.matchAll(/data\.(\w+) == room\.\1/g)].map(m => m[1]);
  const listed = [...after.body.matchAll(/'([^']+)'/g)].map(m => m[1]);
  assert.deepEqual(listed, keys);
  assert.equal(keys.length, 8);
  assert.ok(after.body.includes('data.sourceRevision == room.revision'));
  assert.ok(after.body.includes('data.updatedAt == request.time'));
  for (const [, name] of baseline.matchAll(/    function (\w+)\(/g)) {
    if (name !== before.name && name !== 'deCleanupComposition')
      assert.equal(rulesFunction(baseline, name).text, rulesFunction(afterSource, name).text);
  }
  assert.throws(() => compactCleanupComposition(baseline.replace('data.memberCount == room.memberCount', 'true')));
});

test('completed cycles skip active-only authentication work with identical predicates', () => {
  const before = rulesFunction(baseline, 'atomicActiveV2Recruitment').text;
  const after = rulesFunction(targetScanCandidate(baseline), 'atomicActiveV2Recruitment').text;
  const tokens = text => text.match(/\w+|[^\s]/g).sort();
  assert.deepEqual(tokens(before), tokens(after));
  assert.ok(after.indexOf("oldData.currentCycleStatus == 'active'") < after.indexOf('hasActiveBinding()'));
});

test('group count dispatch preserves validators and fails if a competing path permits the field', () => {
  const result = dispatchGroupRecruitmentCount(baseline);
  for (const [, name] of baseline.matchAll(/    function (\w+)\(/g))
    assert.equal(rulesFunction(result, name).text, rulesFunction(baseline, name).text);
  const allows = source => [...source.matchAll(/allow\s[\s\S]*?;/g)].map(m => m[0]);
  const a = allows(baseline), b = allows(result);
  assert.equal(a.length, b.length);
  assert.equal(a.filter((x, i) => x !== b[i]).length, 1);
  const f = rulesFunction(baseline, 'validGroupActivityUpdate');
  assert.throws(() => dispatchGroupRecruitmentCount(baseline.replace(f.text,
    f.text.replace("['revision'", "['activeRecruitmentCount', 'revision'"))));
});

test('completed membership fallback guard requires the existing active contract', () => {
  const input = prioritizeMemberRemoval(baseline);
  const result = skipCompletedMembershipFallbacks(input);
  const tokens = text => text.match(/\w+|[^\s]/g).filter(x => x !== '(' && x !== ')').sort();
  assert.deepEqual(tokens(result.replace("(resource.data.currentCycleStatus == 'active' && (validAtomicPendingApplicationUpdate", '(validAtomicPendingApplicationUpdate')), tokens(input));
  const f = rulesFunction(baseline, 'validAtomicRecruitmentJoin');
  assert.throws(() => skipCompletedMembershipFallbacks(input.replace(f.text,
    f.text.replace('atomicActiveV2Recruitment(oldData)', 'true'))));
});

test('recurrence rejects unrelated changed fields before authentication with identical conditions', () => {
  const before = rulesFunction(baseline, 'validRecurrenceChange').text;
  const after = rulesFunction(targetScanCandidate(baseline), 'validRecurrenceChange').text;
  const tokens = text => text.match(/\w+|[^\s]/g).sort();
  assert.deepEqual(tokens(before), tokens(after));
  assert.ok(after.indexOf('affectedKeys()') < after.indexOf('hasActiveBinding()'));
});

test('ownership map reuse preserves the exact predicate and both guarded reads', () => {
  const result = reuseOwnershipReads(baseline);
  const original = rulesFunction(baseline, 'deCurrentOwnership').text;
  const shared = rulesFunction(result, 'deOwnershipMatches').text;
  assert.equal(shared.slice(shared.indexOf('      let generation')),
    original.slice(original.indexOf('      let generation')));
  for (const name of ['deCurrentOwnership', 'deManualCurrentOwnership']) {
    const before = rulesFunction(baseline, name).text;
    const after = rulesFunction(result, name).text;
    assert.equal(after.match(/let character =[\s\S]*?let account =[^;]+;/)[0],
      before.match(/let character =[\s\S]*?let account =[^;]+;/)[0]);
    assert.ok(after.includes('deOwnershipMatches(data, character, account)'));
  }
  assert.ok(rulesFunction(result, 'deManualCurrentOwnership').text.includes(
    "character.status == 'active' && account.status == 'active' && deOwnershipMatches(data, character, account)"));
});
