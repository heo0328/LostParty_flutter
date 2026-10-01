// DE2-E5 demo only. Keep prior candidates unchanged for comparison.
import assert from 'node:assert/strict';
import { leaderCleanupCandidate } from './roster_leader_cleanup_candidate.mjs';
export function peerCleanupCandidate(source) {
  let rules = leaderCleanupCandidate(source);
  const start = rules.indexOf('    function deCleanupTransition(');
  const end = rules.indexOf('    function validAtomicRecruitmentMemberRemoval(', start);
  assert.ok(start >= 0 && end > start);
  let block = rules.slice(start, end).replaceAll('deCleanup', 'dePeerCleanup')
    .replaceAll('deOwnershipChanged', 'dePeerOwnershipChanged')
    .replaceAll('cleanupCompletedOwnership', 'cleanupCompletedPeerOwnership')
    .replaceAll('ownershipParticipantRemoved', 'ownershipPeerRemoved');
  function change(from, to) {
    assert.equal(block.split(from).length, 2, `peer hook: ${from}`);
    block = block.replace(from, to);
  }
  change("['expectedRevision', 'targetIndex', 'actorIndex', 'observedOwnershipRevision']",
    "['expectedRevision', 'targetIndex', 'actorIndex', 'observedOwnershipRevision', 'leaderIndex', 'observedLeaderRevision']");
  change(`&& (currentPlayerId() == target.playerId
          || (currentPlayerId() == before.leaderPlayerId
            && before.partySlots[command.actorIndex].playerId == currentPlayerId()
            && deCurrentOwnership(before.partySlots[command.actorIndex])))
        && dePeerOwnershipChanged(target, command.observedOwnershipRevision)`,
    `&& command.actorIndex is int && command.actorIndex >= 0 && command.actorIndex < before.partySlots.size()
        && before.partySlots[command.actorIndex].playerId == currentPlayerId()
        && deCurrentOwnership(before.partySlots[command.actorIndex])
        && command.leaderIndex is int && command.leaderIndex >= 0 && command.leaderIndex < before.partySlots.size()
        && before.partySlots[command.leaderIndex].playerId == before.leaderPlayerId
        && dePeerOwnershipChanged(before.partySlots[command.leaderIndex], command.observedLeaderRevision)`);
  change('        && dePeerCleanupStateUnchanged(target, before.raidId)\n', '');
  change('        && !existsAfter(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(target.playerId))',
    `        && exists(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(target.playerId))
        && !existsAfter(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(target.playerId))`);
  change('&& !(playerId in after.memberPlayerIds);',
    `&& !(playerId in after.memberPlayerIds)
        && dePeerOwnershipChanged(target, after.ownershipCleanup.observedOwnershipRevision)
        && dePeerCleanupStateUnchanged(target, before.raidId);`);
  change("'audiencePlayerIds': before.memberPlayerIds, 'occurredAt': request.time",
    "'leaderPlayerId': before.leaderPlayerId, 'observedLeaderRevision': command.observedLeaderRevision,\n        'audiencePlayerIds': before.memberPlayerIds, 'occurredAt': request.time");
  block += `
    function dePeerCommand(roomId) {
      let before = get(recruitmentPath(roomId)).data;
      let after = getAfter(recruitmentPath(roomId)).data;
      return after.get('lastCommandType', '') == 'cleanupCompletedPeerOwnership'
        && after.revision != before.revision;
    }
`;
  rules = rules.slice(0, start) + block + rules.slice(start);
  function exclusive(prefix, condition, validator) {
    const from = rules.indexOf(prefix), to = rules.indexOf(';', from);
    assert.ok(from >= 0 && to > from);
    const offset = prefix.indexOf('if ') + 3;
    rules = rules.slice(0, from) + prefix.slice(0, offset)
      + `(${condition}) ? (${validator}) : (` + rules.slice(from + offset, to) + ')' + rules.slice(to);
  }
  exclusive("allow update: if (request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership'",
    "request.resource.data.get('lastCommandType', '') == 'cleanupCompletedPeerOwnership'",
    'dePeerCleanupAggregate(resource.data, request.resource.data)');
  exclusive('allow delete: if deLeaderCleanupMemberDelete(', 'dePeerCommand(recruitmentId)',
    'dePeerCleanupMemberDelete(recruitmentId, playerId, resource.data)');
  exclusive('allow update: if deLeaderCleanupListing(', 'dePeerCommand(recruitmentId)',
    'dePeerCleanupListing(groupId, recruitmentId, resource.data, request.resource.data)');
  exclusive("allow create: if (request.resource.data.type == 'ownershipLeaderRemoved'",
    "request.resource.data.type == 'ownershipPeerRemoved'",
    'request.resource.data.eventId == eventId && dePeerCleanupEventCreate(request.resource.data)');
  assert.equal(rules.split('&& deLeaderPriorValid(before, command)').length, 2);
  rules = rules.replace('&& deLeaderPriorValid(before, command)',
    '&& command.successorIndex == (command.targetIndex == 0 ? 1 : 0)');
  const priorStart = rules.indexOf('    function deLeaderPriorAt(');
  const priorEnd = rules.indexOf('    function deLeaderSuccessorUpdate(', priorStart);
  rules = rules.slice(0, priorStart) + rules.slice(priorEnd);
  return rules;
}
