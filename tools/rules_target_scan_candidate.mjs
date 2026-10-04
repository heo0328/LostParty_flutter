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

export function dispatchGroupRecruitmentCount(source) {
  for (const name of ['validGroupLeaderApproveUpdate', 'validGroupDisbandUpdate',
    'validGroupLeaderTransferUpdate', 'validGroupMemberLeaveUpdate', 'validGroupActivityUpdate',
    'validGroupMemberJoinUpdate', 'validGroupJoinCodeFlagUpdate', 'validGroupJoinCodeVisibilityUpdate']) {
    const body = rulesFunction(source, name).body;
    assert.match(body, /newData\.diff\(oldData\)\.affectedKeys\(\)\s*\.hasOnly\(\[/, name);
    assert.ok(!body.includes("'activeRecruitmentCount'"), name);
  }
  const join = rulesFunction(source, 'validGroupJoinCommandUpdate').body;
  assert.ok(join.includes('validGroupActivityUpdate(oldData, newData)'));
  assert.ok(join.includes('validGroupMemberJoinUpdate(groupId, oldData, newData)'));
  for (const [name, sign] of [['Close', '-'], ['Open', '+']]) {
    assert.ok(rulesFunction(source, `validAtomicGroupRecruitment${name}Body`).body
      .includes(`newData.activeRecruitmentCount == oldData.activeRecruitmentCount ${sign} 1`));
  }
  const start = source.indexOf('      allow update:', source.indexOf('    match /groups/{groupId}'));
  const end = source.indexOf(';', start);
  let original = source.slice(start, end).replace('      allow update: if ', '');
  const calls = [];
  for (const kind of ['Close', 'Open']) {
    const call = `validAtomicGroupRecruitment${kind}(\n        groupId,\n        resource.data,\n        request.resource.data\n      )`;
    assert.equal(original.split(' || ' + call).length, 2);
    original = original.replace(' || ' + call, '');
    calls.push(call);
  }
  return source.slice(0, start) + `      allow update: if request.resource.data.diff(resource.data).affectedKeys().hasAny(['activeRecruitmentCount'])
        ? (${calls.join(' || ')}) : (${original})` + source.slice(end);
}

export function skipCompletedMembershipFallbacks(source) {
  const names = ['validAtomicPendingApplicationUpdate', 'validAtomicRecruitmentJoin',
    'validAtomicCharacterRevisionUpdate', 'validAtomicPositionAggregateUpdate',
    'validAtomicRecruitmentVisibilityChange'];
  for (const name of names)
    assert.ok(rulesFunction(source, name).body.includes('atomicActiveV2Recruitment(oldData)'), name);
  assert.ok(rulesFunction(source, 'atomicActiveV2Recruitment').body.includes("oldData.currentCycleStatus == 'active'"));
  const start = source.indexOf('      allow update:', source.indexOf('    match /recruitments/{recruitmentId}'));
  const end = source.indexOf(';', start);
  const block = source.slice(start, end);
  const calls = names.map(name => `${name}(\n          resource.data,\n          request.resource.data\n        )`).join(' || ');
  assert.equal(block.split(calls).length, 2);
  return source.slice(0, start) + block.replace(calls,
    `(resource.data.currentCycleStatus == 'active' && (${calls}))`) + source.slice(end);
}

export function reuseOwnershipReads(source) {
  const current = rulesFunction(source, 'deCurrentOwnership');
  const manual = rulesFunction(source, 'deManualCurrentOwnership');
  const split = current.text.indexOf("      let generation = character.get('ownershipRevision', 0);");
  assert.ok(split > 0);
  const predicate = current.text.slice(split);
  assert.ok(manual.text.includes("return character.status == 'active' && account.status == 'active' && deCurrentOwnership(data);"));
  const shared = `    function deOwnershipMatches(data, character, account) {\n${predicate}`;
  const wrapper = current.text.slice(0, split) + '      return deOwnershipMatches(data, character, account);\n    }';
  return source.replace(current.text, shared + '\n\n' + wrapper)
    .replace(manual.text, manual.text.replace('deCurrentOwnership(data)', 'deOwnershipMatches(data, character, account)'));
}

export function shareCleanupAggregateUpdate(source) {
  const names = ['deCleanupAggregate', 'dePeerCleanupAggregate', 'deLeaderCleanupAggregate'];
  let shared;
  for (const name of names) {
    const f = rulesFunction(source, name);
    const start = f.text.indexOf('after.partySlots == remaining &&');
    const end = f.text.indexOf('&& after.updatedAt == request.time', start)
      + '&& after.updatedAt == request.time'.length;
    assert.ok(start > 0 && end > start, name);
    const predicate = f.text.slice(start, end);
    if (shared === undefined) shared = predicate;
    else assert.equal(predicate, shared, name);
    source = source.replace(f.text, f.text.slice(0, start)
      + 'deCleanupAggregateUpdate(before, after, target, remaining)' + f.text.slice(end));
  }
  const insertion = source.indexOf('    function deLeaderCleanupAggregate(');
  return source.slice(0, insertion)
    + `    function deCleanupAggregateUpdate(before, after, target, remaining) {\n      return ${shared};\n    }\n\n`
    + source.slice(insertion);
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
  const recurrence = rulesFunction(source, 'validRecurrenceChange');
  const shape = "newData.diff(oldData).affectedKeys().hasOnly([\n          'continueTogether', 'revision', 'updatedAt'\n        ])";
  assert.ok(recurrence.text.includes('&& ' + shape));
  source = source.replace(recurrence.text, recurrence.text.replace('&& ' + shape, '')
    .replace('return hasActiveBinding()', `return ${shape} && hasActiveBinding()`));
  return shareCleanupAggregateUpdate(reuseOwnershipReads(dispatchGroupRecruitmentCount(skipCompletedMembershipFallbacks(source)))).replace(/^[ \t]+$/gm, '');
}
