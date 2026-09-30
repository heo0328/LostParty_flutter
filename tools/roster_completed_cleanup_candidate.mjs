// DE2-D demo only. Never written to tracked firestore.rules or deployed.
import assert from 'node:assert/strict';
import { legacyOwnershipCandidate } from './roster_legacy_rules_candidate.mjs';

export function completedCleanupCandidate(source) {
  let rules = legacyOwnershipCandidate(source);
  function replace(from, to) {
    assert.equal(rules.split(from).length, 2, `unique cleanup hook: ${from}`);
    rules = rules.replace(from, to);
  }
  replace('    function validAtomicRecruitmentMemberRemoval(', `
    function deCleanupTransition(before, after) {
      return after.get('lastCommandType', '') == 'cleanupCompletedOwnership'
        && before.revision + 1 == after.revision
        && after.ownershipCleanup.expectedRevision == before.revision
        && after.lastCommandActorPlayerId == currentPlayerId()
        && after.lastCommandAt == request.time;
    }

    function deOwnershipChanged(slot, observed) {
      let character = get(characterPath(slot.characterId)).data;
      let account = get(/databases/$(database)/documents/gameAccounts/$(character.gameAccountId)).data;
      let oldGeneration = slot.get('ownershipRevision', 0);
      return oldGeneration is int && oldGeneration >= 0
        && observed is int
        && character.ownershipRevision is int
        && character.ownershipRevision > oldGeneration
        && character.ownershipRevision == observed
        && account.ownershipRevision is int
        && account.ownershipRevision == character.ownershipRevision
        && character.ownerPlayerId is string && character.ownerPlayerId.size() > 0
        && account.ownerPlayerId == character.ownerPlayerId;
    }

    function deCleanupStateUnchanged(slot, raidId) {
      let path = atomicRaidStateDocPath(slot.playerId, slot.characterId + '_' + raidId);
      return exists(path)
        ? getAfter(path).data == get(path).data
        : !existsAfter(path);
    }

    function deCleanupComposition(data, room) {
      return data.partySlots == room.partySlots
        && data.memberPlayerIds == room.memberPlayerIds
        && data.raidStateTargets == room.raidStateTargets
        && data.memberCount == room.memberCount
        && data.dealerCount == room.dealerCount
        && data.supportCount == room.supportCount
        && data.nonGroupMemberCount == room.nonGroupMemberCount
        && data.hasAvailableSlot == room.hasAvailableSlot
        && data.sourceRevision == room.revision
        && data.updatedAt == request.time;
    }

    function deCleanupEvent(before, after) {
      let command = after.ownershipCleanup;
      let target = before.partySlots[command.targetIndex];
      return {
        'schemaVersion': 1, 'eventId': after.lastCommandId,
        'commandId': after.lastCommandId, 'recruitmentId': before.recruitmentId,
        'type': 'ownershipParticipantRemoved', 'commandRevision': after.revision,
        'expectedRevision': before.revision, 'actorPlayerId': currentPlayerId(),
        'targetPlayerId': target.playerId, 'targetCharacterId': target.characterId,
        'observedOwnershipRevision': command.observedOwnershipRevision,
        'audiencePlayerIds': before.memberPlayerIds, 'occurredAt': request.time
      };
    }

    function deCleanupAggregate(before, after) {
      let command = after.ownershipCleanup;
      let target = before.partySlots[command.targetIndex];
      let remaining = before.partySlots.removeAll([target]);
      return hasActiveBinding() && deCleanupTransition(before, after)
        && before.schemaVersion == 2 && before.status == 'active'
        && before.currentCycleStatus == 'completed' && before.continueTogether == true
        && before.memberCount >= 2 && before.memberCount <= 8
        && command.keys().hasOnly(['expectedRevision', 'targetIndex', 'actorIndex', 'observedOwnershipRevision'])
        && command.targetIndex is int && command.targetIndex >= 0
        && command.targetIndex < before.partySlots.size()
        && target.playerId != before.leaderPlayerId
        && (currentPlayerId() == target.playerId
          || (currentPlayerId() == before.leaderPlayerId
            && before.partySlots[command.actorIndex].playerId == currentPlayerId()
            && deCurrentOwnership(before.partySlots[command.actorIndex])))
        && deOwnershipChanged(target, command.observedOwnershipRevision)
        && after.diff(before).affectedKeys().hasOnly([
          'partySlots', 'memberPlayerIds', 'raidStateTargets', 'memberCount',
          'dealerCount', 'supportCount', 'nonGroupMemberCount', 'hasAvailableSlot',
          'revision', 'updatedAt', 'commandTargets', 'lastCommandId', 'lastCommandType',
          'lastCommandActorPlayerId', 'lastCommandAt', 'ownershipCleanup'])
        && after.partySlots == remaining && after.memberCount == before.memberCount - 1
        && after.memberPlayerIds == before.memberPlayerIds.removeAll([target.playerId])
        && after.raidStateTargets == before.raidStateTargets.removeAll([
          {'playerId': target.playerId, 'stateId': target.characterId + '_' + before.raidId}])
        && after.dealerCount == before.dealerCount - (target.role == 'dealer' ? 1 : 0)
        && after.supportCount == before.supportCount - (target.role == 'support' ? 1 : 0)
        && after.nonGroupMemberCount == before.nonGroupMemberCount - (target.countedAsNonGroupMember ? 1 : 0)
        && after.hasAvailableSlot == true && after.commandTargets == []
        && after.lastCommandId is string && after.lastCommandId.size() > 0
        && after.updatedAt == request.time
        && !existsAfter(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(target.playerId))
        && deCleanupStateUnchanged(target, before.raidId)
        && (before.visibility != 'group' || deCleanupComposition(
          getAfter(/databases/$(database)/documents/groups/$(before.groupId)/raidListings/$(before.recruitmentId)).data, after))
        && getAfter(/databases/$(database)/documents/partyEvents/$(after.lastCommandId)).data == deCleanupEvent(before, after);
    }

    function deCleanupMemberDelete(roomId, playerId, data) {
      let before = get(recruitmentPath(roomId)).data;
      let after = getAfter(recruitmentPath(roomId)).data;
      let target = before.partySlots[after.ownershipCleanup.targetIndex];
      return deCleanupTransition(before, after)
        && target.playerId == playerId && target.characterId == data.characterId
        && !(playerId in after.memberPlayerIds);
    }

    function deCleanupListing(groupId, roomId, before, after) {
      let roomBefore = get(recruitmentPath(roomId)).data;
      let roomAfter = getAfter(recruitmentPath(roomId)).data;
      return deCleanupTransition(roomBefore, roomAfter)
        && roomBefore.groupId == groupId && roomBefore.visibility == 'group'
        && after.diff(before).affectedKeys().hasOnly([
          'partySlots', 'memberPlayerIds', 'raidStateTargets', 'memberCount',
          'dealerCount', 'supportCount', 'nonGroupMemberCount', 'hasAvailableSlot',
          'sourceRevision', 'updatedAt'])
        && deCleanupComposition(after, roomAfter);
    }

    function deCleanupEventCreate(data) {
      let before = get(recruitmentPath(data.recruitmentId)).data;
      let after = getAfter(recruitmentPath(data.recruitmentId)).data;
      return deCleanupTransition(before, after) && data == deCleanupEvent(before, after);
    }

    function validAtomicRecruitmentMemberRemoval(`);
  replace('allow update: if (personalCompletionCommandMarker(request.resource.data)',
    "allow update: if (request.resource.data.get('lastCommandType', '') == 'cleanupCompletedOwnership' && deCleanupAggregate(resource.data, request.resource.data)) || (personalCompletionCommandMarker(request.resource.data)");
  replace('allow delete: if validPersonalCompletionMemberDelete(',
    'allow delete: if deCleanupMemberDelete(recruitmentId, playerId, resource.data) || validPersonalCompletionMemberDelete(');
  replace('allow update: if validPersonalCompletionListingUpdate(',
    'allow update: if deCleanupListing(groupId, recruitmentId, resource.data, request.resource.data) || validPersonalCompletionListingUpdate(');
  replace('allow create: if validAtomicMembershipPartyEvent(request.resource.data)',
    "allow create: if (request.resource.data.type == 'ownershipParticipantRemoved' && request.resource.data.eventId == eventId && deCleanupEventCreate(request.resource.data)) || validAtomicMembershipPartyEvent(request.resource.data)");
  return rules;
}
