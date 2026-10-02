import assert from 'node:assert/strict';
import { occupancyCandidate } from './roster_occupancy_candidate.mjs';

// Demo only. Active-party personal completion remains a separate integration gate.
export function manualCompletionCandidate(source) {
  let rules = occupancyCandidate(source);
  function edit(name, transform) {
    const start = rules.indexOf(`    function ${name}(`);
    const end = rules.indexOf('\n    function ', start + 1);
    assert.ok(start >= 0 && end > start, name);
    const before = rules.slice(start, end), after = transform(before);
    assert.notEqual(before, after, name);
    rules = rules.slice(0, start) + after + rules.slice(end);
  }
  edit('validManualRaidStateCreate', text => text
    .replace("'updatedAt'", "'updatedAt', 'ownershipRevision'")
    .replace('&& ownsActiveCharacter(data.characterId)', '&& deManualCurrentOwnership(data)')
    .replace('!hasWeeklyRaidClaimAfter(', '!deBlockingClaim(')
    .replace('data.raidId\n        )', "data.raidId, data.get('ownershipRevision', 0)\n        )")
    .replace('!existsAfter(assignmentPath(playerId, stateId))',
      "deManualAssignmentAvailable(playerId, stateId, data)"));
  edit('validPersonalCompletedRaidStateDelete', text => text.replace(
    "&& data.status == 'completed';", "&& data.status == 'completed' && deManualCurrentOwnership(data);"));
  edit('validManualWeeklyRaidClaimDelete', text => text.replace(
    'return hasActiveBinding()', 'return deManualCurrentOwnership(data) && hasActiveBinding()'));
  const hook = 'allow update: if deReplacePriorState(';
  assert.equal(rules.split(hook).length, 2);
  rules = rules.replace(hook, `allow update: if (request.resource.data.source == 'manual'
          && deOlderState(resource.data, playerId, request.resource.data.characterId,
            request.resource.data.raidId, request.resource.data.get('ownershipRevision', 0))
          && validManualRaidStateCreate(playerId, stateId, request.resource.data))
          || deReplacePriorState(`);
  return rules.replace('    function deOlderRecord(', `
    function deManualCurrentOwnership(data) {
      let character = get(characterPath(data.characterId)).data;
      let account = get(/databases/$(database)/documents/gameAccounts/$(character.gameAccountId)).data;
      return character.status == 'active' && account.status == 'active' && deCurrentOwnership(data);
    }
    function deManualAssignmentAvailable(playerId, stateId, data) {
      let path = assignmentPath(playerId, stateId);
      return !existsAfter(path) || deOlderRecord(getAfter(path).data,
        playerId, data.characterId, data.raidId, data.get('ownershipRevision', 0));
    }
    function deOlderRecord(`);
}
