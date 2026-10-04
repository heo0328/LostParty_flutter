import assert from 'node:assert/strict';
import { rulesFunction } from './roster_complexity_candidate.mjs';
import { boundRemovalRejections } from './rules_removal_rejection_candidate.mjs';

export function compactTargetScans(source) {
  for (const [name, helper, arg, field] of [
    ['atomicCommandIncludes', 'atomicTargetAt', 'data', 'commandTargets'],
    ['atomicRaidStateListedInTargets', 'atomicRaidStateTargetAt', 'recruitment', 'raidStateTargets'],
  ]) {
    const f = rulesFunction(source, name);
    const helperFunction = rulesFunction(source, helper);
    assert.equal((source.match(new RegExp(`\\b${helper}\\(`, 'g')) ?? []).length, 9);
    assert.ok(helperFunction.body.includes(`index < ${arg}.${field}.size()`));
    assert.ok(helperFunction.body.includes(`${arg}.${field}[index].playerId == playerId`));
    assert.ok(helperFunction.body.includes(`${arg}.${field}[index].stateId == stateId`));
    for (let i = 0; i < 8; i++) assert.ok(f.body.includes(`${helper}(${arg}, ${i}, playerId, stateId)`));
    let expression = '';
    for (let i = 7; i >= 0; i--) {
      const pair = `(targets[${i}].diff(expected).unchangedKeys().hasAll(['playerId', 'stateId']))`;
      expression = `(count > ${i} && (${pair}${expression ? ` || ${expression}` : ''}))`;
    }
    source = source.replace(f.text, `    function ${name}(${arg}, playerId, stateId) {
      let targets = ${arg}.${field};
      let count = targets.size();
      let expected = {'playerId': playerId, 'stateId': stateId};
      return ${expression};
    }`).replace(helperFunction.text + '\n\n', '');
    assert.ok(!source.includes(`${helper}(`));
  }
  return source;
}

// Compare the same required fields together; absent fields remain rejected.
export function compactCleanupComposition(source) {
  const f = rulesFunction(source, 'deCleanupComposition');
  const keys = ['partySlots', 'memberPlayerIds', 'raidStateTargets', 'memberCount',
    'dealerCount', 'supportCount', 'nonGroupMemberCount', 'hasAvailableSlot'];
  const original = keys.map(key => `data.${key} == room.${key}`).join('\n        && ');
  assert.ok(f.text.includes(original));
  const expression = `data.diff(room).unchangedKeys().hasAll([${keys.map(key => `'${key}'`).join(', ')}])`;
  return source.replace(f.text, f.text.replace(original, expression));
}

export function targetScanCandidate(baseline) {
  let source = compactCleanupComposition(compactTargetScans(boundRemovalRejections(baseline)));
  const f = rulesFunction(source, 'validAtomicStaleRaidStateDelete');
  const old = 'return deManualCurrentOwnership(oldData) && hasActiveBinding()';
  assert.ok(f.text.includes(old));
  assert.ok(f.text.includes('&& playerId == currentPlayerId()'));
  source = source.replace(f.text, f.text.replace(old,
    'return hasActiveBinding() && playerId == currentPlayerId()')
    .replace('&& playerId == currentPlayerId()\n        && oldData.playerId',
      '&& deManualCurrentOwnership(oldData)\n        && oldData.playerId'));
  const active = rulesFunction(source, 'atomicActiveV2Recruitment');
  assert.ok(active.text.includes('return hasActiveBinding()'));
  assert.ok(active.text.includes("&& oldData.currentCycleStatus == 'active'"));
  source = source.replace(active.text, active.text
    .replace('return hasActiveBinding()', "return oldData.currentCycleStatus == 'active' && hasActiveBinding()")
    .replace("&& oldData.currentCycleStatus == 'active';", ';'));
  return source;
}
