import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

// Both callers supply a Rules constant; clients cannot choose the state branch.
export function sharedAdvanceValidation(source) {
  const idle = rulesFunction(source, 'sealAdvanceIdle');
  const completed = rulesFunction(source, 'bug24AdvanceCompleted');
  const common = [
    "room.lastCommandType == 'advanceCycle'", 'room.lastCommandAt == request.time',
    'data.playerId == playerId', "stateId == data.characterId + '_' + data.raidId",
    "data.schemaVersion == 1 && data.status == 'active' && data.source == 'party'",
    'data.cycleKey == room.currentCycleKey && data.raidId == room.raidId',
    'data.difficultyId == room.difficultyId', 'data.updatedAt == request.time',
    "(room.commandTargets.size() <= 8 && {'playerId': playerId, 'stateId': stateId} in room.commandTargets)",
  ];
  for (const condition of common) {
    assert.ok(idle.text.includes(condition), condition);
    assert.ok(completed.text.includes(condition), condition);
  }
  const text = `function sealAdvance(playerId, stateId, before, data, idle) {
      let room = getAfter(/databases/$(database)/documents/recruitments/$(data.recruitmentId)).data;
      return (idle
        ? (sealIdle(before) && deManualCurrentOwnership(data)
          && data.keys().hasOnly(['playerId', 'characterId', 'raidId', 'ownershipRevision',
            'guardSchemaVersion', 'guardRecruitmentId', 'guardRoomRevision', 'guardCycleKey', 'guardCycleStartedAt', 'guardCycleEndsAt', 'guardSlotIndex', 'guardCheckedAt',
            'schemaVersion', 'difficultyId', 'recruitmentId', 'cycleKey', 'role', 'status', 'source', 'revision', 'updatedAt'])
          && data.characterId == before.characterId && data.raidId == before.raidId
          && data.ownershipRevision == before.ownershipRevision && data.revision == 1)
        : (bug24KnownCompleted(before, playerId, data.characterId, data.raidId)
          && before.cycleKey < data.cycleKey
          && data.diff(before).affectedKeys().hasOnly([
            'recruitmentId', 'difficultyId', 'cycleKey', 'role', 'status', 'source', 'revision', 'updatedAt', 'completedAt'])
          && data.revision == before.revision + 1 && !('completedAt' in data)))
        && sealPrepared(before, data, room)
        && ${common.join('\n        && ')};
    }`;
  source = source.slice(0, completed.start) + source.slice(completed.end);
  source = source.slice(0, idle.start) + text + source.slice(idle.end);
  for (const [name, flag] of [['sealAdvanceIdle', 'true'], ['bug24AdvanceCompleted', 'false']]) {
    const call = `${name}(playerId, stateId, resource.data, request.resource.data)`;
    assert.equal(source.split(call).length, 2);
    source = source.replace(call, `sealAdvance(playerId, stateId, resource.data, request.resource.data, ${flag})`);
    assert.ok(!source.includes(name));
  }
  return source;
}
