// DE2-F: bounded completed-room disband guard. Demo only.
import assert from 'node:assert/strict';
import { peerCleanupCandidate } from './roster_peer_cleanup_candidate.mjs';
export function lastMemberCandidate(source) {
  let rules = peerCleanupCandidate(source);
  const marker = '    match /recruitments/{recruitmentId} {';
  const start = rules.indexOf('      allow update: if ', rules.indexOf(marker));
  const end = rules.indexOf('      allow delete: if false;', start);
  assert.ok(start > 0 && end > start);
  const original = rules.slice(start, end).trim().replace(/^allow update: if /, '').replace(/;$/, '');
  rules = rules.slice(0, start) + `      allow update: if
        (request.resource.data.get('lastCommandType', '') == 'disband'
          && resource.data.memberCount == 1
          && resource.data.currentCycleStatus == 'completed')
          ? (deLastCompletedDisband(resource.data, request.resource.data)
            && validAtomicLifecycleUpdate(resource.data, request.resource.data))
          : (${original});
` + rules.slice(end);
  const hook = '    function validAtomicLifecycleUpdate(';
  assert.equal(rules.split(hook).length, 2);
  return rules.replace(hook, `
    function deLastCompletedDisband(before, after) {
      let slot = before.partySlots[0];
      let memberPath = /databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(slot.playerId);
      let eventPath = /databases/$(database)/documents/partyEvents/$(after.lastCommandId);
      let event = getAfter(eventPath).data;
      return before.partySlots.size() == 1
        && slot.playerId == before.leaderPlayerId
        && after.diff(before).affectedKeys().hasOnly([
          'status', 'manualRecruitmentEnabled', 'hasAvailableSlot', 'commandTargets',
          'groupActiveRecruitmentCountAfter', 'revision', 'lastCommandId',
          'lastCommandType', 'lastCommandActorPlayerId', 'lastCommandAt', 'updatedAt'])
        && after.commandTargets == []
        && getAfter(memberPath).data == get(memberPath).data
        && deCleanupStateUnchanged(slot, before.raidId)
        && (!atomicHasGroupId(before)
          || !existsAfter(/databases/$(database)/documents/groups/$(before.groupId)/raidListings/$(before.recruitmentId)))
        && !exists(eventPath)
        && event.recruitmentId == before.recruitmentId
        && event.eventId == after.lastCommandId && event.commandId == after.lastCommandId
        && event.type == 'disband' && event.commandRevision == after.revision
        && event.actorPlayerId == currentPlayerId()
        && event.audiencePlayerIds == before.memberPlayerIds
        && event.occurredAt == request.time;
    }

` + hook);
}
