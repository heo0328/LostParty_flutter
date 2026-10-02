import assert from 'node:assert/strict';
import { manualCompletionCandidate } from './roster_manual_completion_candidate.mjs';
export function personalCompletionCandidate(source) {
  let rules = manualCompletionCandidate(source);
  const start = rules.indexOf('    function validPersonalRaidStateCompletion(');
  const end = rules.indexOf('\n    function ', start + 1);
  const before = rules.slice(start, end);
  const after = before.replace('return hasActiveBinding()', 'return deManualCurrentOwnership(oldData) && hasActiveBinding()');
  assert.notEqual(before, after);
  rules = rules.slice(0, start) + after + rules.slice(end);
  for (const name of ['validPersonalCompletionRecruitmentUpdate', 'validPersonalRaidStateCompletion']) {
    const from = rules.indexOf(`    function ${name}(`), to = rules.indexOf('\n    function ', from + 1);
    const prior = rules.slice(from, to);
    const next = prior.replace(/atomicRaidStateListedInTargets\(\s*(oldData|newData),\s*target.playerId,\s*target.stateId\s*\)/g,
      '$1.raidStateTargets.hasAny([target])').replace('atomicRaidStateListedInTargets(recruitment, playerId, stateId)',
      "recruitment.raidStateTargets.hasAny([{'playerId': playerId, 'stateId': stateId}])");
    assert.notEqual(prior, next, name);
    rules = rules.slice(0, from) + next + rules.slice(to);
  }
  const hook = 'personalCompletionCommandMarker(request.resource.data)';
  assert.equal(rules.split(hook).length, 2);
  rules = rules.replace(hook, `${hook}
          && dePersonalCompletionBoundary(resource.data, request.resource.data)`);
  // Dispatch only an actual personal-completion transition; preserve old paths otherwise.
  function dispatch(marker, indent, operation, condition, validator) {
    const anchor = rules.indexOf(marker);
    const start = rules.indexOf(`${indent}allow ${operation}: if `, anchor);
    const end = rules.indexOf(';', start);
    assert.ok(anchor >= 0 && start > anchor && end > start, marker);
    const prefix = `${indent}allow ${operation}: if `;
    const original = rules.slice(start + prefix.length, end);
    rules = rules.slice(0, start) + prefix + `(${condition}) ? (${validator}) : (${original})` + rules.slice(end);
  }
  dispatch('    match /recruitments/{recruitmentId} {', '      ', 'update',
    "request.resource.data.get('lastCommandType', '') == 'personalComplete' && request.resource.data.lastCommandAt == request.time",
    'dePersonalCompletionBoundary(resource.data, request.resource.data) && validPersonalCompletionRecruitmentUpdate(resource.data, request.resource.data)');
  dispatch('      match /raidStates/{stateId} {', '        ', 'update',
    "resource.data.status == 'active' && request.resource.data.status == 'completed' && request.resource.data.source == 'manual' && resource.data.get('ownershipRevision', 0) == request.resource.data.get('ownershipRevision', 0)",
    'validPersonalRaidStateCompletion(playerId, stateId, resource.data, request.resource.data)');
  const memberMarker = '      match /members/{playerId} {';
  // Locate party members, not group members.
  const partyStart = rules.indexOf('    match /recruitments/{recruitmentId} {');
  const uniqueMemberMarker = rules.slice(partyStart, rules.indexOf(memberMarker, partyStart) + memberMarker.length);
  dispatch(uniqueMemberMarker, '        ', 'delete', 'dePersonalCommand(recruitmentId)',
    'validPersonalCompletionMemberDelete(recruitmentId, playerId, resource.data)');
  dispatch(uniqueMemberMarker, '        ', 'update', 'dePersonalCommand(recruitmentId)',
    "request.resource.data.characterId == resource.data.characterId && request.resource.data.get('ownershipRevision', 0) == resource.data.get('ownershipRevision', 0) && validApprovalPermissionChange(recruitmentId, playerId, resource.data, request.resource.data)");
  dispatch('      match /raidListings/{recruitmentId} {', '        ', 'update', 'dePersonalCommand(recruitmentId)',
    'validPersonalCompletionListingUpdate(recruitmentId, resource.data, request.resource.data)');
  return rules.replace('    function deManualCurrentOwnership(', `
    function dePersonalCommand(roomId) {
      let room = getAfter(recruitmentPath(roomId)).data;
      return room.get('lastCommandType', '') == 'personalComplete' && room.lastCommandAt == request.time;
    }
    function dePersonalCompletionBoundary(before, after) {
      let target = after.commandTargets[0];
      let memberPath = recruitmentMemberPath(before.recruitmentId, target.playerId);
      let member = get(memberPath).data;
      let state = getAfter(atomicRaidStatePath(target)).data;
      let eventPath = /databases/$(database)/documents/partyEvents/$(after.lastCommandId);
      let event = getAfter(eventPath).data;
      return member.playerId == target.playerId && member.characterId == state.characterId
        && member.get('ownershipRevision', 0) == state.get('ownershipRevision', 0)
        && before.partySlots.size() == after.partySlots.size() + 1
        && before.partySlots.removeAll([atomicCharacterSlot(member, member.get('countedAsNonGroupMember', false))]) == after.partySlots
        && before.memberPlayerIds.removeAll([target.playerId]) == after.memberPlayerIds
        && before.raidStateTargets.removeAll([target]) == after.raidStateTargets
        && !existsAfter(memberPath) && state.updatedAt == request.time
        && !exists(eventPath) && event.occurredAt == request.time
        && event.type == 'memberLeft' && event.reason == 'weeklyRaidCompleted'
        && event.commandRevision == after.revision
        && event.actorPlayerId == target.playerId && event.targetPlayerId == target.playerId
        && (before.leaderPlayerId == after.leaderPlayerId
          || deManualCurrentOwnership(getAfter(recruitmentMemberPath(before.recruitmentId, after.leaderPlayerId)).data))
        && (!(before.groupId is string) || dePersonalCompletionListing(before, after));
    }
    function dePersonalCompletionListing(before, after) {
      let path = /databases/$(database)/documents/groups/$(before.groupId)/raidListings/$(before.recruitmentId);
      return after.memberCount == 0 ? !existsAfter(path)
        : (getAfter(path).data.sourceRevision == after.revision && getAfter(path).data.updatedAt == request.time);
    }
    function deManualCurrentOwnership(`);
}
