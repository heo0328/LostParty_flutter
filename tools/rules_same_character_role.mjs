import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

export function sameCharacterRole(source) {
  const change = (name, transform) => {
    const fn = rulesFunction(source, name);
    const replacement = transform(fn.text);
    assert.notEqual(replacement, fn.text, name);
    source = source.slice(0, fn.start) + replacement + source.slice(fn.end);
  };
  for (const name of ['bug24PrepPair', 'bug24PrepMember']) {
    change(name, body => body.replace('member.characterId != oldMember.characterId',
      '(member.characterId != oldMember.characterId || member.role != oldMember.role)')
      .replace('!(oldTarget in after.raidStateTargets)',
        '(oldTarget == newTarget || !(oldTarget in after.raidStateTargets))'));
  }
  change('bug24PrepDispatch', body => body
    .replace("return before.currentCycleStatus", "let memberPath = recruitmentMemberPath(before.recruitmentId, currentPlayerId());\n      return before.currentCycleStatus")
    .replace('after.raidStateTargets != before.raidStateTargets',
      '(after.raidStateTargets != before.raidStateTargets || getAfter(memberPath).data.role != get(memberPath).data.role)'));
  change('validAtomicMemberCharacterChange', body => body
    .replace('!existsAfter(atomicRaidStateDocPath(playerId, oldStateId))',
      '(oldStateId == newStateId || !existsAfter(atomicRaidStateDocPath(playerId, oldStateId)))')
    .replace('!(oldTarget in after.raidStateTargets)',
      '(oldTarget == newTarget || !(oldTarget in after.raidStateTargets))')
    .replace('&& newTarget in after.raidStateTargets',
      `&& (oldStateId != newStateId || (getAfter(atomicRaidStateDocPath(playerId, newStateId)).data.role == newData.role
          && getAfter(atomicRaidStateDocPath(playerId, newStateId)).data.updatedAt == request.time))
        && newTarget in after.raidStateTargets`));

  const marker = '    function validAtomicRaidStateUpdate(';
  assert.ok(source.includes(marker));
  // The old/new member role link and request.time require a real member write.
  // Its direct character-change gate owns actor/binding, current ownership,
  // role validity, room revision and placement validation. This state rule
  // links that validated generation and protects the remaining state fields.
  // Keep an explicit fresh event check: member validation alone permits no event.
  source = source.replace(marker, `    function validAtomicRoleUpdate(playerId, stateId, oldData, newData) {
      let before = get(recruitmentPath(oldData.recruitmentId)).data;
      let after = getAfter(recruitmentPath(oldData.recruitmentId)).data;
      let memberPath = recruitmentMemberPath(oldData.recruitmentId, playerId);
      let member = getAfter(memberPath).data;
      let eventPath = /databases/$(database)/documents/partyEvents/$('characterChanged_' + oldData.recruitmentId + '_' + string(after.revision));
      return oldData.playerId == playerId && member.playerId == playerId
        && stateId == oldData.characterId + '_' + oldData.raidId
        && oldData.get('ownershipRevision', 0) == member.get('ownershipRevision', 0)
        && oldData.status == 'active' && oldData.source == 'party'
        && oldData.role == get(memberPath).data.role && oldData.characterId == get(memberPath).data.characterId
        && oldData.cycleKey == after.currentCycleKey && oldData.raidId == after.raidId
        && before.currentCycleStatus == 'active' && before.status == 'active'
        && !exists(eventPath) && getAfter(eventPath).data.occurredAt == request.time
        && getAfter(eventPath).data.type == 'characterChanged'
        && newData.diff(oldData).affectedKeys().hasOnly(['role', 'revision', 'updatedAt'])
        && newData.role != oldData.role
        && newData.revision == oldData.revision + 1 && newData.updatedAt == request.time
        && member.characterId == oldData.characterId && member.role == newData.role
        && member.updatedAt == request.time;
    }
${marker}`);
  const start = source.indexOf('    match /raidStates/{stateId}');
  assert.ok(start >= 0);
  const update = source.indexOf('allow update: if ', start);
  assert.ok(update >= 0);
  const end = source.indexOf(';', update);
  const previous = source.slice(update + 'allow update: if '.length, end);
  source = source.slice(0, update) + `allow update: if (resource.data.get('status', '') == 'active'
        && request.resource.data.get('status', '') == 'active'
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['role', 'revision', 'updatedAt'])
        && resource.data.get('role', '') != request.resource.data.get('role', ''))
        ? validAtomicRoleUpdate(playerId, stateId, resource.data, request.resource.data)
        : (${previous})` + source.slice(end);

  // Every successful character/role mutation requires schema 2 and an active
  // after-room. Route all such changes once, instead of expanding the same
  // ownership/placement/claim validator again through the fallback branch.
  const memberStart = source.indexOf('match /members/{playerId}', source.indexOf('match /recruitments/'));
  assert.ok(memberStart >= 0);
  const memberUpdate = source.indexOf('allow update:', memberStart);
  const memberEnd = source.indexOf(';', memberUpdate);
  const memberRule = source.slice(memberUpdate, memberEnd);
  assert.equal((memberRule.match(/validAtomicMemberCharacterChange\(/g) || []).length, 2);
  const directMemberRule = memberRule
    .replace('request.resource.data.characterId != resource.data.characterId',
      '(request.resource.data.characterId != resource.data.characterId || request.resource.data.role != resource.data.role)')
    .replace("get(recruitmentPath(recruitmentId)).data.currentCycleStatus == 'active'",
      "getAfter(recruitmentPath(recruitmentId)).data.currentCycleStatus == 'active'")
    .replace(/validAtomicMemberCharacterChange\(\s*recruitmentId,\s*playerId,\s*resource\.data,\s*request\.resource\.data\s*\) \|\| deLeaderSuccessorUpdate/,
      'deLeaderSuccessorUpdate');
  assert.equal((directMemberRule.match(/validAtomicMemberCharacterChange\(/g) || []).length, 1);
  source = source.slice(0, memberUpdate) + directMemberRule + source.slice(memberEnd);
  return source;
}
