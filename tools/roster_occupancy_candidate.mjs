import assert from 'node:assert/strict';
import { participationCandidate } from './roster_participation_candidate.mjs';

// Demo only: replace a lower ownership generation without deleting its old room.
export function occupancyCandidate(source) {
  let rules = participationCandidate(source);
  function edit(name, transform) {
    const start = rules.indexOf(`    function ${name}(`);
    const end = rules.indexOf('\n    function ', start + 1);
    assert.ok(start >= 0 && end > start, name);
    const before = rules.slice(start, end), after = transform(before);
    assert.notEqual(before, after, name);
    rules = rules.slice(0, start) + after + rules.slice(end);
  }
  for (const [name, data] of [['validPendingApplication', 'data'], ['validApplicationReapply', 'newData']]) {
    edit(name, text => text.replace(/!existsAfter\(raidStatePath\([\s\S]*?\)\)/,
      `deAvailablePriorState(playerId, ${data}.characterId, recruitment.raidId, ${data}.get('ownershipRevision', 0))`)
      .replace('!hasWeeklyRaidClaimAfter(', '!deBlockingClaim(')
      .replace('recruitment.raidId\n        );', `recruitment.raidId, ${data}.get('ownershipRevision', 0)\n        );`));
  }
  edit('validAtomicRaidStateCreate', text => text.replace('!hasWeeklyRaidCompletionAfter(', '!deBlockingClaim(')
    .replace('data.raidId\n        )', "data.raidId, data.get('ownershipRevision', 0)\n        )"));
  edit('validAtomicMemberCharacterChange', text => text.replace('!hasWeeklyRaidCompletionAfter(', '!deBlockingClaim(')
    .replace('after.raidId\n        )', "after.raidId, newData.get('ownershipRevision', 0)\n        )"));
  const hook = 'allow update: if validPersonalRaidStateCompletion(';
  // Cover legacy fallback validators too, not only the atomic validator.
  const memberGuard = '|| deCurrentOwnership(request.resource.data))';
  assert.equal(rules.split(memberGuard).length, 2);
  rules = rules.replace(memberGuard,
    '|| (deCurrentOwnership(resource.data) && deCurrentOwnership(request.resource.data)))');
  assert.equal(rules.split(hook).length, 2);
  rules = rules.replace(hook, `allow update: if deReplacePriorState(playerId, stateId, resource.data, request.resource.data)
          || validPersonalRaidStateCompletion(`);
  return rules.replace('    function deApplicationGeneration(', `
    function deOlderRecord(data, playerId, characterId, raidId, generation) {
      let prior = data.get('ownershipRevision', 0);
      return data.playerId == playerId && data.characterId == characterId && data.raidId == raidId
        && prior is int && prior >= 0 && generation is int && prior < generation;
    }
    function deOlderState(data, playerId, characterId, raidId, generation) {
      return deOlderRecord(data, playerId, characterId, raidId, generation)
        && data.status in ['active', 'completed'] && data.revision is int && data.revision >= 1;
    }
    function deAvailablePriorState(playerId, characterId, raidId, generation) {
      let path = raidStatePath(playerId, characterId, raidId);
      return !existsAfter(path) || deOlderState(getAfter(path).data, playerId, characterId, raidId, generation);
    }
    function deBlockingClaim(playerId, cycleKey, characterId, raidId, generation) {
      let path = weeklyRaidClaimPath(playerId, cycleKey, characterId, raidId);
      return existsAfter(path) && !deOlderRecord(getAfter(path).data, playerId, characterId, raidId, generation);
    }
    function deFreshParticipation(data) {
      let roomPath = recruitmentPath(data.recruitmentId);
      let memberPath = recruitmentMemberPath(data.recruitmentId, data.playerId);
      let room = getAfter(roomPath).data;
      let kind = !exists(roomPath) ? 'partyCreated' : (!exists(memberPath) ? 'memberJoined' : 'characterChanged');
      let eventId = kind + '_' + data.recruitmentId + '_' + string(room.revision);
      let eventPath = /databases/$(database)/documents/partyEvents/$(eventId);
      return room.updatedAt == request.time && getAfter(memberPath).data.updatedAt == request.time
        && (!exists(roomPath) || room.revision == get(roomPath).data.revision + 1)
        && !exists(eventPath) && getAfter(eventPath).data.occurredAt == request.time
        && getAfter(eventPath).data.type == kind;
    }
    function deReplacePriorState(playerId, stateId, before, after) {
      return deOlderState(before, playerId, after.characterId, after.raidId, after.get('ownershipRevision', 0))
        && before.get('recruitmentId', null) != after.recruitmentId
        && deFreshParticipation(after)
        && validAtomicRaidStateCreate(playerId, stateId, after);
    }
    function deApplicationGeneration(`);
}
