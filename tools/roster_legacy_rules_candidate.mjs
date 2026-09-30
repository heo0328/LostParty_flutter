// Demo-only DE2-C candidate, shared by subsequent isolated proofs.
import assert from 'node:assert/strict';
import { sharedTargetStatus } from './roster_target_rules_candidate.mjs';
export function legacyOwnershipCandidate(source) {
let rules = sharedTargetStatus(source);
function replaceOnce(from, to) {
  assert.equal(rules.split(from).length, 2, `unique hook: ${from}`);
  rules = rules.replace(from, to);
}
replaceOnce('    function validAtomicAdvanceRaidStateCreate(', `    function deCurrentOwnership(data) {
      let character = get(characterPath(data.characterId)).data;
      let account = get(/databases/$(database)/documents/gameAccounts/$(character.gameAccountId)).data;
      let generation = character.get('ownershipRevision', 0);
      return generation is int && generation >= 0
        && account.get('ownershipRevision', 0) is int
        && account.get('ownershipRevision', 0) == generation
        && character.ownerPlayerId == data.playerId
        && account.ownerPlayerId == data.playerId
        && data.get('ownershipRevision', 0) is int
        && data.get('ownershipRevision', 0) == generation;
    }

    function validAtomicAdvanceRaidStateCreate(`);
replaceOnce('&& newData.raidStateTargets == oldData.raidStateTargets',
  '&& newData.raidStateTargets == oldData.raidStateTargets\n        && newData.partySlots == oldData.partySlots');
replaceOnce('&& recruitment.partySlots[index].role == data.role;',
  "&& recruitment.partySlots[index].role == data.role\n        && recruitment.partySlots[index].get('ownershipRevision', 0) == data.get('ownershipRevision', 0);");
replaceOnce("&& recruitment.lastCommandType == 'advanceCycle'\n        && data.keys().hasOnly([",
  "&& recruitment.lastCommandType == 'advanceCycle'\n        && deCurrentOwnership(data)\n        && data.keys().hasOnly([");
replaceOnce("'source', 'revision', 'updatedAt'\n        ])",
  "'source', 'revision', 'updatedAt', 'ownershipRevision'\n        ])");
replaceOnce('return atomicIsLifecycleCommand(recruitment)\n        && newData.playerId == playerId',
  'return atomicIsLifecycleCommand(recruitment)\n        && deCurrentOwnership(oldData)\n        && newData.playerId == playerId');
replaceOnce("&& oldData.status == 'active'\n            && newData.status == 'completed'",
  "&& oldData.status == 'active'\n            && atomicAdvanceStateMatchesSlot(recruitment, oldData)\n            && newData.status == 'completed'");

return rules;
}
