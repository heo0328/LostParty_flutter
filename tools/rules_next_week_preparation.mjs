import assert from 'node:assert/strict';

// BUG-024: add bounded preparation and expired-completion advance paths.
// This transform runs on readable Rules; the deployment file remains generated.
export function nextWeekPreparation(source) {
  function replaceOnce(before, after) {
    assert.equal(source.split(before).length, 2, before);
    source = source.replace(before, after);
  }
  const helpers = `
    function bug24Unchanged(path) {
      return exists(path) ? existsAfter(path) && getAfter(path).data == get(path).data
        : !existsAfter(path);
    }
    function bug24PrepState(data) {
      return hasActiveBinding() && data.schemaVersion == 2 && data.status == 'active'
        && data.continueTogether == true && data.currentCycleStatus == 'completed';
    }
    function bug24PrepDispatch(before, after) {
      return before.currentCycleStatus == 'completed' && after.currentCycleStatus == 'completed'
        && after.memberCount == before.memberCount && after.lastCommandType == null
        && after.partySlots != before.partySlots;
    }
    function bug24PrepRecords(before, oldMember, member) {
      let oldPath = atomicRaidStateDocPath(member.playerId, oldMember.characterId + '_' + before.raidId);
      let newPath = atomicRaidStateDocPath(member.playerId, member.characterId + '_' + before.raidId);
      return bug24Unchanged(oldPath) && bug24Unchanged(newPath)
        && (!exists(newPath) || get(newPath).data.status == 'completed')
        && bug24Unchanged(weeklyRaidClaimPath(member.playerId, before.currentCycleKey, oldMember.characterId, before.raidId))
        && bug24Unchanged(weeklyRaidClaimPath(member.playerId, before.currentCycleKey, member.characterId, before.raidId));
    }
    function bug24PrepListing(before, after) {
      let path = /databases/$(database)/documents/groups/$(before.groupId)/raidListings/$(before.recruitmentId);
      return exists(path) && getAfter(path).data == after;
    }
    function bug24PrepEvent(before, after) {
      let id = 'characterChanged_' + before.recruitmentId + '_' + string(after.revision);
      let path = /databases/$(database)/documents/partyEvents/$(id);
      return !exists(path) && getAfter(path).data == {
        'schemaVersion': 1, 'eventId': id, 'recruitmentId': before.recruitmentId,
        'type': 'characterChanged', 'commandId': id, 'commandRevision': after.revision,
        'audiencePlayerIds': before.memberPlayerIds, 'actorPlayerId': currentPlayerId(),
        'occurredAt': request.time
      };
    }
    function bug24PrepPair(before, after, oldMember, member) {
      let oldTarget = {'playerId': member.playerId, 'stateId': oldMember.characterId + '_' + before.raidId};
      let newTarget = {'playerId': member.playerId, 'stateId': member.characterId + '_' + before.raidId};
      return bug24PrepState(before) && bug24PrepState(after)
        && member.playerId == currentPlayerId() && oldMember.playerId == member.playerId
        && member.characterId != oldMember.characterId
        && deCurrentOwnership(oldMember) && deCurrentOwnership(member)
        && member.role in ['dealer', 'support']
        && member.diff(oldMember).affectedKeys().hasOnly([
          'characterId', 'characterNameSnapshot', 'classNameSnapshot', 'itemLevelSnapshot',
          'combatPowerSnapshot', 'gemValidationSnapshot', 'buildIntegritySnapshot',
          'ownershipRevision', 'role', 'partyIndex', 'slotIndex', 'characterChangedAt', 'updatedAt'])
        && member.characterChangedAt == request.time && member.updatedAt == request.time
        && atomicCharacterPlacementMatches(before, after, oldMember, member)
        && newTarget in after.raidStateTargets && !(oldTarget in after.raidStateTargets)
        && after.raidStateTargets.removeAll([newTarget]) == before.raidStateTargets.removeAll([oldTarget])
        && after.dealerCount == before.dealerCount + (member.role == 'dealer' ? 1 : 0) - (oldMember.role == 'dealer' ? 1 : 0)
        && after.supportCount == before.supportCount + (member.role == 'support' ? 1 : 0) - (oldMember.role == 'support' ? 1 : 0)
        && (member.playerId == before.leaderPlayerId
          ? after.leaderCharacterNameSnapshot == member.characterNameSnapshot && after.leaderClassNameSnapshot == member.classNameSnapshot
          : after.leaderCharacterNameSnapshot == before.leaderCharacterNameSnapshot && after.leaderClassNameSnapshot == before.leaderClassNameSnapshot)
        && bug24PrepRecords(before, oldMember, member);
    }
    function bug24PrepAggregate(before, after) {
      let path = recruitmentMemberPath(before.recruitmentId, currentPlayerId());
      return bug24PrepState(before) && after.revision == before.revision + 1
        && after.diff(before).affectedKeys().hasOnly([
          'partySlots', 'raidStateTargets', 'dealerCount', 'supportCount',
          'leaderCharacterNameSnapshot', 'leaderClassNameSnapshot', 'commandTargets',
          'lastCommandId', 'lastCommandType', 'lastCommandActorPlayerId', 'lastCommandAt', 'revision', 'updatedAt'])
        && after.updatedAt == request.time && atomicAggregateSizesMatch(after)
        && atomicLifecycleMarkerConsumedOrPreserved(before, after)
        && bug24PrepPair(before, after, get(path).data, getAfter(path).data)
        && bug24PrepEvent(before, after)
        && (before.visibility != 'group' || bug24PrepListing(before, after));
    }
    function bug24PrepMember(roomId, playerId, oldMember, member) {
      return playerId == currentPlayerId() && bug24PrepPair(
        get(recruitmentPath(roomId)).data, getAfter(recruitmentPath(roomId)).data, oldMember, member);
    }
`;
  replaceOnce('    function atomicIsLifecycleCommand(newData) {', helpers + '\n    function atomicIsLifecycleCommand(newData) {');
  // Dedicated dispatch avoids evaluating unrelated completed-room cleanup paths.
  function dispatchUpdate(match, predicate, validation) {
    const matchStart = source.indexOf(match);
    const start = source.indexOf('      allow update: if ', matchStart);
    const end = source.indexOf(';', start);
    assert.ok(matchStart >= 0 && start > matchStart && end > start);
    const prior = source.slice(start + '      allow update: if '.length, end);
    source = source.slice(0, start) + `      allow update: if (${predicate}) ? (${validation}) : (${prior})` + source.slice(end);
  }
  dispatchUpdate('    match /recruitments/{recruitmentId}',
    'bug24PrepDispatch(resource.data, request.resource.data)',
    'bug24PrepAggregate(resource.data, request.resource.data)');
  dispatchUpdate('      match /members/{playerId}',
    "request.resource.data.characterId != resource.data.characterId && bug24PrepDispatch(get(recruitmentPath(recruitmentId)).data, getAfter(recruitmentPath(recruitmentId)).data)",
    'bug24PrepMember(recruitmentId, playerId, resource.data, request.resource.data)');
  dispatchUpdate('      match /raidListings/{recruitmentId}',
    'bug24PrepDispatch(get(recruitmentPath(recruitmentId)).data, getAfter(recruitmentPath(recruitmentId)).data)',
    'validGroupRaidListingCreate(groupId, recruitmentId, request.resource.data)');
  // Legacy assignment checks must not authorize an isolated V2 prep member write.
  replaceOnce('      return membershipFieldsOk\n        && (nextWeekPrep',
    "      return membershipFieldsOk\n        && !(recruitment.schemaVersion == 2 && nextWeekPrep)\n        && (nextWeekPrep");
  const advance = `
    function bug24AdvanceCompleted(playerId, stateId, oldData, data) {
      let room = getAfter(recruitmentPath(data.recruitmentId)).data;
      return oldData.status == 'completed' && oldData.cycleKey < data.cycleKey
        && oldData.revision is int && oldData.revision >= 1
        && oldData.playerId == playerId && data.playerId == playerId
        && oldData.characterId == data.characterId && oldData.raidId == data.raidId
        && stateId == data.characterId + '_' + data.raidId
        && oldData.get('ownershipRevision', 0) == data.get('ownershipRevision', 0)
        && deCurrentOwnership(oldData) && deCurrentOwnership(data)
        && atomicIsLifecycleCommand(room) && room.lastCommandType == 'advanceCycle'
        && room.lastCommandAt == request.time
        && data.diff(oldData).affectedKeys().hasOnly([
          'recruitmentId', 'difficultyId', 'cycleKey', 'role', 'status', 'source', 'revision', 'updatedAt', 'completedAt'])
        && data.schemaVersion == 1 && data.status == 'active' && data.source == 'party'
        && data.cycleKey == room.currentCycleKey && data.raidId == room.raidId
        && data.difficultyId == room.difficultyId && data.revision == oldData.revision + 1
        && data.updatedAt == request.time && !('completedAt' in data)
        && atomicCommandIncludes(room, playerId, stateId) && atomicAdvanceStateMatchesSlot(room, data)
        && !deBlockingClaim(playerId, data.cycleKey, data.characterId, data.raidId, data.get('ownershipRevision', 0));
    }
`;
  replaceOnce('    function validAtomicAdvanceRaidStateCreate(playerId, stateId, data) {',
    advance + '\n    function validAtomicAdvanceRaidStateCreate(playerId, stateId, data) {');
  // Discriminators are already mandatory in the selected validators. Keep
  // complete off unrelated fallback paths, preserving its eight-member budget.
  const stateMatch = source.indexOf('      match /raidStates/{stateId}');
  const updateStart = source.indexOf('        allow update: if ', stateMatch);
  const updateEnd = source.indexOf(';', updateStart);
  assert.ok(stateMatch >= 0 && updateStart > stateMatch && updateEnd > updateStart);
  const priorUpdate = source.slice(updateStart + '        allow update: if '.length, updateEnd);
  source = source.slice(0, updateStart) + `        allow update: if
        (resource.data.status == 'active' && request.resource.data.status == 'completed' && request.resource.data.source == 'party')
          ? validAtomicRaidStateUpdate(playerId, stateId, resource.data, request.resource.data)
          : ((resource.data.status == 'completed' && request.resource.data.status == 'active' && request.resource.data.source == 'party')
            ? (bug24AdvanceCompleted(playerId, stateId, resource.data, request.resource.data)
              || deReplacePriorState(playerId, stateId, resource.data, request.resource.data))
            : (${priorUpdate}))` + source.slice(updateEnd);
  replaceOnce("&& !newData.diff(oldData).affectedKeys().hasAny(['role'])",
    "&& oldData.cycleKey < newData.cycleKey\n            && !deBlockingClaim(playerId, newData.cycleKey, newData.characterId, newData.raidId, newData.get('ownershipRevision', 0))\n            && !newData.diff(oldData).affectedKeys().hasAny(['role'])");
  replaceOnce('        && atomicAdvanceStateMatchesSlot(recruitment, data);',
    "        && atomicAdvanceStateMatchesSlot(recruitment, data)\n        && !deBlockingClaim(playerId, data.cycleKey, data.characterId, data.raidId, data.get('ownershipRevision', 0));");
  return source;
}
