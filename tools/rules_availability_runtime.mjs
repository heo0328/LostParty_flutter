import assert from 'node:assert/strict';
import { distributePreparationRecords } from './bug024_spark_preparation_candidate.mjs';
import { availabilitySeals } from './bug024_spark_seal_candidate.mjs';

// Promote the proven mechanism with normal writer compatibility. Never permit
// clients to introduce a seal through a normal participation/completion writer.
export function availabilityRuntime(input) {
  let source = availabilitySeals(distributePreparationRecords(input));
  function replace(before, after) {
    assert.equal(source.split(before).length, 2, before);
    source = source.replace(before, () => after);
  }
  const fields = "['guardSchemaVersion', 'guardRecruitmentId', 'guardRoomRevision', 'guardCycleKey', 'guardCycleStartedAt', 'guardCycleEndsAt', 'guardSlotIndex', 'guardCheckedAt']";
  const helpers = `
    function sealRemoved(before, data) {
      return before.keys().hasAny(${fields}) && !data.keys().hasAny(${fields});
    }
    function sealNormalReplacement(playerId, stateId, before, data) {
      return sealRemoved(before, data) && data.playerId == before.playerId
        && data.characterId == before.characterId && data.raidId == before.raidId
        && (sealIdle(before) || before.get('status', '') in ['active', 'completed'])
        && (data.get('source', '') == 'manual'
          ? ((sealIdle(before) || deOlderState(before, playerId, data.characterId, data.raidId, data.get('ownershipRevision', 0)))
            && validManualRaidStateCreate(playerId, stateId, data))
          : ((sealIdle(before) || deOlderState(before, playerId, data.characterId, data.raidId, data.get('ownershipRevision', 0)))
            && deFreshParticipation(data) && validAtomicRaidStateCreate(playerId, stateId, data)));
    }
    function sealParticipateIdle(playerId, stateId, before, data) {
      return sealIdle(before) && !data.diff(before).affectedKeys().hasAny(${fields})
        && data.playerId == before.playerId && data.characterId == before.characterId && data.raidId == before.raidId
        && deFreshParticipation(data) && validAtomicRaidStateCreate(playerId, stateId, data);
    }
`;
  // Validators are scoped to raidStates; keep these helpers in that scope.
  replace('    function bug24AdvanceCompleted(', helpers + '\n    function bug24AdvanceCompleted(');
  replace(`return data.diff(before).affectedKeys().hasOnly(${fields})`,
    `return data.diff(before).affectedKeys().hasOnly(${fields.slice(0, -1)}, 'ownershipRevision'])`);
  replace("&& before.raidId == data.raidId && before.get('ownershipRevision', 0) == data.ownershipRevision",
    "&& before.raidId == data.raidId && (before.get('ownershipRevision', 0) == data.ownershipRevision || (sealIdle(before) && deOlderRecord(before, playerId, data.characterId, data.raidId, data.ownershipRevision)))");
  const audit = 'sealAuditUpdate(playerId, stateId, resource.data, request.resource.data)';
  replace(`? (${audit})`, `? (${audit} || sealNormalReplacement(playerId, stateId, resource.data, request.resource.data))`);
  replace('? sealAdvanceIdle(playerId, stateId, resource.data, request.resource.data)',
    '? (request.resource.data.get(\'recruitmentId\', null) is string && bug24Advancing(getAfter(recruitmentPath(request.resource.data.recruitmentId)).data)\n        ? sealAdvanceIdle(playerId, stateId, resource.data, request.resource.data)\n        : sealParticipateIdle(playerId, stateId, resource.data, request.resource.data))');
  replace('(!exists(newPath) || sparkPrepKnownCompleted(get(newPath).data,',
    '(!exists(newPath) || sealIdle(get(newPath).data) || sparkPrepKnownCompleted(get(newPath).data,');
  // Same stub identity/generation is proved by the membership and live ownership
  // rules. Reject a different generation rather than trusting the shape alone.
  replace('|| sealIdle(get(newPath).data) || sparkPrepKnownCompleted',
    '|| (sealIdle(get(newPath).data) && get(newPath).data.playerId == data.actorPlayerId && get(newPath).data.characterId == data.nextCharacterId && get(newPath).data.raidId == room.raidId && get(newPath).data.ownershipRevision == data.nextOwnershipRevision) || sparkPrepKnownCompleted');
  return source;
}
