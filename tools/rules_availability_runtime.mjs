import assert from 'node:assert/strict';
import { distributePreparationRecords } from './bug024_spark_preparation_candidate.mjs';
import { availabilitySeals } from './bug024_spark_seal_candidate.mjs';

// Promote the proven mechanism with normal writer compatibility. Never permit
// clients to introduce a seal through a normal participation/completion writer.
export function availabilityRuntime(input) {
  let source = availabilitySeals(distributePreparationRecords(input));
  // Absent final creation is forbidden: certification must first create a stub.
  // Inline the proof's constant denial so the deployed compiler has no unused
  // parameters in the otherwise obsolete create validator.
  const absentValidator = /    function validAtomicAdvanceRaidStateCreate\(playerId, stateId, data\) \{\s*return false;\s*\}/;
  assert.ok(absentValidator.test(source));
  source = source.replace(absentValidator, '');
  const absentCalls = /validAtomicAdvanceRaidStateCreate\(\s*playerId,\s*stateId,\s*request\.resource\.data\s*\)/g;
  assert.equal([...source.matchAll(absentCalls)].length, 2);
  source = source.replace(absentCalls, 'false');
  // Certification now checks the before Claim in sealAvailableBefore. The
  // old final-transition-only wrapper has no callers after the C transform.
  // Remove only that unreachable declaration; do not remove its shared helpers.
  assert.equal([...source.matchAll(/\bbug24PriorClaimAvailable\s*\(/g)].length, 1);
  const obsoleteClaim = /    function bug24PriorClaimAvailable\(data\) \{\s*let path = weeklyRaidClaimPath\(data\.playerId, data\.cycleKey, data\.characterId, data\.raidId\);\s*return !exists\(path\) \|\| deOlderRecord\(get\(path\)\.data,\s*data\.playerId, data\.characterId, data\.raidId, data\.get\('ownershipRevision', 0\)\);\s*\}/;
  assert.ok(obsoleteClaim.test(source));
  source = source.replace(obsoleteClaim, '');
  function replace(before, after) {
    assert.equal(source.split(before).length, 2, before);
    source = source.replace(before, () => after);
  }
  // A complete command has the same immutable slots/targets lifecycle shape.
  // Dispatch before unrelated membership/cleanup fallbacks, including denials.
  replace('allow update: if (bug24Advancing(request.resource.data))',
    "allow update: if (request.resource.data.get('lastCommandType', '') in ['advanceCycle', 'complete'] && request.resource.data.lastCommandAt == request.time)");
  replace('allow update: if (bug24Advancing(getAfter(recruitmentPath(recruitmentId)).data))',
    "allow update: if (getAfter(recruitmentPath(recruitmentId)).data.get('lastCommandType', '') in ['advanceCycle', 'complete'] && getAfter(recruitmentPath(recruitmentId)).data.lastCommandAt == request.time)");
  replace("? validAtomicRaidStateUpdate(playerId, stateId, resource.data, request.resource.data)\n          : ((resource.data.status == 'completed'",
    "? (resource.data.recruitmentId == request.resource.data.recruitmentId && existsAfter(recruitmentPath(resource.data.recruitmentId)) && validAtomicRaidStateUpdate(playerId, stateId, resource.data, request.resource.data))\n          : ((resource.data.status == 'completed'");
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
  // A known older manual record is exclusively the existing replacement path.
  // Do not evaluate unrelated participation branches after a Claim denial.
  replace(': ((resource.data.get(\'status\', \'\') == \'active\' && request.resource.data.get(\'status\', \'\') == \'active\'',
    `: ((request.resource.data.get('source', '') == 'manual'
        && deOlderState(resource.data, playerId, request.resource.data.characterId, request.resource.data.raidId, request.resource.data.get('ownershipRevision', 0)))
      ? validManualRaidStateCreate(playerId, stateId, request.resource.data)
      : ((resource.data.get('status', '') == 'active' && request.resource.data.get('status', '') == 'active'`);
  // Close the additional conditional surrounding the prior update expression.
  const stateMatch = source.indexOf('      match /raidStates/{stateId}');
  const update = source.indexOf('        allow update:', stateMatch);
  const updateEnd = source.indexOf(';', update);
  source = source.slice(0, updateEnd) + ')' + source.slice(updateEnd);

  const memberMatch = source.indexOf('      match /members/{playerId} {');
  const memberUpdate = source.indexOf('        allow update:', memberMatch);
  const memberEnd = source.indexOf(';', memberUpdate);
  const existing = source.slice(memberUpdate + '        allow update: if '.length, memberEnd);
  assert.ok(existing.includes('bug24PrepMember(') && existing.includes('validAtomicMemberCharacterChange('));
  source = source.slice(0, memberUpdate) + `        allow update: if
    (request.resource.data.characterId != resource.data.characterId
      && get(recruitmentPath(recruitmentId)).data.schemaVersion == 2
      && get(recruitmentPath(recruitmentId)).data.currentCycleStatus == 'active')
      ? (deCurrentOwnership(resource.data)
        && validAtomicMemberCharacterChange(recruitmentId, playerId, resource.data, request.resource.data))
      : (${existing})` + source.slice(memberEnd);
  replace('(!exists(newPath) || sparkPrepKnownCompleted(get(newPath).data,',
    '(!exists(newPath) || sealIdle(get(newPath).data) || sparkPrepKnownCompleted(get(newPath).data,');
  // Same stub identity/generation is proved by the membership and live ownership
  // rules. Reject a different generation rather than trusting the shape alone.
  replace('|| sealIdle(get(newPath).data) || sparkPrepKnownCompleted',
    '|| (sealIdle(get(newPath).data) && get(newPath).data.playerId == data.actorPlayerId && get(newPath).data.characterId == data.nextCharacterId && get(newPath).data.raidId == room.raidId && get(newPath).data.ownershipRevision == data.nextOwnershipRevision) || sparkPrepKnownCompleted');
  // A newly created legacy Claim cannot masquerade as an older ownership
  // lifetime. Missing generation remains compatible only with live generation 0.
  replace("'completedAt', 'updatedAt'\n        ])\n        && data.schemaVersion == 1",
    "'completedAt', 'updatedAt', 'ownershipRevision'\n        ])\n        && data.schemaVersion == 1");
  replace("        && ownsActiveCharacter(data.characterId)\n        && !existsAfter(assignmentPath(playerId, assignmentId));",
    "        && ownsActiveCharacter(data.characterId) && deManualCurrentOwnership(data)\n        && !existsAfter(assignmentPath(playerId, assignmentId));");
  return source;
}
