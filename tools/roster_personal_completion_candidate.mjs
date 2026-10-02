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
  const hook = 'personalCompletionCommandMarker(request.resource.data)';
  assert.equal(rules.split(hook).length, 2);
  rules = rules.replace(hook, `${hook}
          && dePersonalCompletionBoundary(resource.data, request.resource.data)`);
  return rules.replace('    function deManualCurrentOwnership(', `
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
