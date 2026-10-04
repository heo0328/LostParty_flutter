import { memberRemovalBaseline } from './roster_complexity_candidate.mjs';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { compactTargetScans, targetScanCandidate, compactCleanupComposition } from './rules_target_scan_candidate.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';
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
