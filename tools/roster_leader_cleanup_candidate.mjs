// DE2-E isolated candidate. D remains unchanged; production Rules are untouched.
import assert from 'node:assert/strict';
import { completedCleanupCandidate } from './roster_completed_cleanup_candidate.mjs';

export function leaderCleanupCandidate(source) {
  let rules = completedCleanupCandidate(source);
  const start = rules.indexOf('    function deCleanupTransition(');
  const end = rules.indexOf('    function validAtomicRecruitmentMemberRemoval(', start);
  assert.ok(start >= 0 && end > start);
  let block = rules.slice(start, end).replaceAll('deCleanup', 'deLeaderCleanup')
    .replaceAll('deOwnershipChanged', 'deLeaderOwnershipChanged')
    .replaceAll('cleanupCompletedOwnership', 'cleanupCompletedLeaderOwnership')
    .replaceAll('ownershipParticipantRemoved', 'ownershipLeaderRemoved');
  function change(from, to) {
    assert.equal(block.split(from).length, 2, `unique succession hook: ${from}`);
    block = block.replace(from, to);
  }
  change("'audiencePlayerIds': before.memberPlayerIds, 'occurredAt': request.time",
    "'successorPlayerId': before.partySlots[command.successorIndex].playerId,\n        'priorGenerations': command.priorGenerations,\n        'audiencePlayerIds': before.memberPlayerIds, 'occurredAt': request.time");
  change("['expectedRevision', 'targetIndex', 'actorIndex', 'observedOwnershipRevision']",
    "['expectedRevision', 'targetIndex', 'actorIndex', 'observedOwnershipRevision', 'successorIndex', 'priorGenerations']");
  change(`&& target.playerId != before.leaderPlayerId
        && (currentPlayerId() == target.playerId
          || (currentPlayerId() == before.leaderPlayerId
            && before.partySlots[command.actorIndex].playerId == currentPlayerId()
            && deCurrentOwnership(before.partySlots[command.actorIndex])))`,
    `&& target.playerId == before.leaderPlayerId
        && command.actorIndex is int && command.actorIndex >= 0 && command.actorIndex < before.partySlots.size()
        && before.partySlots[command.actorIndex].playerId == currentPlayerId()
        && deCurrentOwnership(before.partySlots[command.actorIndex])
        && command.successorIndex is int && command.successorIndex >= 0 && command.successorIndex < before.partySlots.size()
        && command.successorIndex != command.targetIndex
        && (command.successorIndex == command.actorIndex || deCurrentOwnership(before.partySlots[command.successorIndex]))
        && command.priorGenerations is list && command.priorGenerations.size() == before.partySlots.size()
        && deLeaderPriorValid(before, command)
        && after.leaderPlayerId == before.partySlots[command.successorIndex].playerId
        && getAfter(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(after.leaderPlayerId)).data.canApproveApplications == true
        && getAfter(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(after.leaderPlayerId)).data.updatedAt == request.time`);
  change("'lastCommandActorPlayerId', 'lastCommandAt', 'ownershipCleanup'])",
    "'lastCommandActorPlayerId', 'lastCommandAt', 'ownershipCleanup',\n          'leaderPlayerId', 'leaderCharacterNameSnapshot', 'leaderClassNameSnapshot'])");
  change('        && deLeaderCleanupStateUnchanged(target, before.raidId)\n', '');
  change('&& !(playerId in after.memberPlayerIds);',
    '&& !(playerId in after.memberPlayerIds)\n        && deLeaderCleanupStateUnchanged(target, before.raidId);');
  change("'sourceRevision', 'updatedAt'])", "'sourceRevision', 'updatedAt', 'leaderPlayerId', 'leaderCharacterNameSnapshot', 'leaderClassNameSnapshot'])");
  change('&& data.sourceRevision == room.revision', `&& data.leaderPlayerId == room.leaderPlayerId
        && data.leaderCharacterNameSnapshot == room.leaderCharacterNameSnapshot
        && data.leaderClassNameSnapshot == room.leaderClassNameSnapshot
        && data.sourceRevision == room.revision`);
  block += `
    function deLeaderPriorAt(room, command, index) {
      return index >= command.successorIndex || index == command.targetIndex
        || deLeaderOwnershipChanged(room.partySlots[index], command.priorGenerations[index]);
    }
    function deLeaderPriorValid(room, command) {
      return ${Array.from({ length: 7 }, (_, i) => `(command.successorIndex <= ${i} || (deLeaderPriorAt(room, command, ${i}) && `).join('')}true${'))'.repeat(7)};
    }
    function deLeaderSuccessorUpdate(roomId, playerId, before, after) {
      let roomBefore = get(recruitmentPath(roomId)).data;
      let roomAfter = getAfter(recruitmentPath(roomId)).data;
      let slot = roomBefore.partySlots[roomAfter.ownershipCleanup.successorIndex];
      return deLeaderCleanupTransition(roomBefore, roomAfter)
        && slot.playerId == playerId && before.playerId == playerId
        && before.characterId == slot.characterId
        && roomAfter.leaderPlayerId == playerId
        && roomAfter.leaderCharacterNameSnapshot == before.characterNameSnapshot
        && roomAfter.leaderClassNameSnapshot == before.classNameSnapshot
        && after.diff(before).affectedKeys().hasOnly(['canApproveApplications', 'updatedAt'])
        && after.canApproveApplications == true && after.updatedAt == request.time;
    }
`;
  rules = rules.slice(0, start) + block + rules.slice(start);
  function hook(from, to) {
    assert.equal(rules.split(from).length, 2, `unique leader allow hook: ${from}`);
    rules = rules.replace(from, to);
  }
  hook("allow update: if (request.resource.data.get('lastCommandType', '') == 'cleanupCompletedOwnership'",
    "allow update: if (request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership' && deLeaderCleanupAggregate(resource.data, request.resource.data)) || (request.resource.data.get('lastCommandType', '') == 'cleanupCompletedOwnership'");
  hook('allow delete: if deCleanupMemberDelete(', 'allow delete: if deLeaderCleanupMemberDelete(recruitmentId, playerId, resource.data) || deCleanupMemberDelete(');
  hook('allow update: if deCleanupListing(', 'allow update: if deLeaderCleanupListing(groupId, recruitmentId, resource.data, request.resource.data) || deCleanupListing(');
  hook('allow update: if validAtomicMemberCharacterChange(', 'allow update: if deLeaderSuccessorUpdate(recruitmentId, playerId, resource.data, request.resource.data) || validAtomicMemberCharacterChange(');
  hook("allow create: if (request.resource.data.type == 'ownershipParticipantRemoved'",
    "allow create: if (request.resource.data.type == 'ownershipLeaderRemoved' && request.resource.data.eventId == eventId && deLeaderCleanupEventCreate(request.resource.data)) || (request.resource.data.type == 'ownershipParticipantRemoved'");
  return rules;
}
