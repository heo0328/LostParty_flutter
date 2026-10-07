// C feasibility only: writes ignored demo input, never deployment Rules.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const out = 'coverage/bug024/spark-seal';
let source = fs.readFileSync('coverage/bug024/spark/preparation-distributed.rules', 'utf8');
const guards = "['guardSchemaVersion', 'guardRecruitmentId', 'guardRoomRevision', 'guardCycleKey', 'guardCycleStartedAt', 'guardCycleEndsAt', 'guardSlotIndex', 'guardCheckedAt']";
function replace(before, after) {
  assert.equal(source.split(before).length, 2, before);
  source = source.replace(before, () => after);
}
function replaceFunction(name, body) {
  const start = source.indexOf(`    function ${name}(`);
  assert.ok(start > 0, name);
  let level = 0; let end = source.indexOf('{', start);
  for (; end < source.length; end++) {
    if (source[end] === '{') level++;
    if (source[end] === '}' && --level === 0) break;
  }
  source = source.slice(0, start) + body + source.slice(end + 1);
}
const helpers = `
    function sealIdle(data) {
      return data.keys().hasOnly(['playerId', 'characterId', 'raidId', 'ownershipRevision',
        'guardSchemaVersion', 'guardRecruitmentId', 'guardRoomRevision', 'guardCycleKey', 'guardCycleStartedAt', 'guardCycleEndsAt', 'guardSlotIndex', 'guardCheckedAt'])
        && data.keys().hasAll(['playerId', 'characterId', 'raidId', 'ownershipRevision',
        'guardSchemaVersion', 'guardRecruitmentId', 'guardRoomRevision', 'guardCycleKey', 'guardCycleStartedAt', 'guardCycleEndsAt', 'guardSlotIndex', 'guardCheckedAt'])
        && data.guardSchemaVersion == 1;
    }
    function sealAvailableBefore(path, data) {
      return !exists(path) || deOlderRecord(get(path).data, data.playerId,
        data.characterId, data.raidId, data.ownershipRevision);
    }
    function sealAudit(playerId, stateId, data) {
      let room = get(recruitmentPath(data.guardRecruitmentId)).data;
      let index = data.guardSlotIndex;
      return hasActiveBinding() && currentPlayerId() == room.leaderPlayerId
        && room == getAfter(recruitmentPath(data.guardRecruitmentId)).data
        && room.schemaVersion == 2 && room.status == 'active' && room.continueTogether == true
        && data.guardSchemaVersion == 1 && data.guardCheckedAt == request.time
        && data.guardRoomRevision == room.revision
        && data.guardCycleKey is string && data.guardCycleKey.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
        && data.guardCycleKey > room.currentCycleKey
        && data.guardCycleStartedAt is timestamp && data.guardCycleEndsAt is timestamp
        && data.guardCycleStartedAt >= room.cycleEndsAt
        && data.guardCycleEndsAt == data.guardCycleStartedAt + duration.value(7, 'd')
        && request.time >= data.guardCycleStartedAt && request.time < data.guardCycleEndsAt
        && index is int && index >= 0 && index < room.partySlots.size()
        && room.partySlots[index].playerId == playerId && data.playerId == playerId
        && room.partySlots[index].characterId == data.characterId
        && room.partySlots[index].get('ownershipRevision', 0) == data.ownershipRevision
        && data.raidId == room.raidId && stateId == data.characterId + '_' + data.raidId
        && deManualCurrentOwnership(data)
        && sealAvailableBefore(assignmentPath(playerId, stateId), data)
        && sealAvailableBefore(weeklyRaidClaimPath(playerId, data.guardCycleKey, data.characterId, data.raidId), data);
    }
    function sealAuditUpdate(playerId, stateId, before, data) {
      return data.diff(before).affectedKeys().hasOnly(${guards})
        && before.playerId == data.playerId && before.characterId == data.characterId
        && before.raidId == data.raidId && before.get('ownershipRevision', 0) == data.ownershipRevision
        && (sealIdle(before)
          || (sparkPrepKnownCompleted(before, playerId, data.characterId, data.raidId, data.ownershipRevision)
            && before.cycleKey < data.guardCycleKey && before.completedAt is timestamp && before.updatedAt is timestamp)
          || (before.get('schemaVersion', 0) == 1 && before.get('status', '') == 'active'
            && before.source == 'party' && before.recruitmentId == data.guardRecruitmentId
            && before.revision is int && before.revision >= 1 && before.role in ['dealer', 'support']
            && before.cycleKey is string && before.cycleKey.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
            && before.cycleKey < data.guardCycleKey && !('completedAt' in before)
            && before.difficultyId == get(recruitmentPath(data.guardRecruitmentId)).data.difficultyId
            && before.role == get(recruitmentPath(data.guardRecruitmentId)).data.partySlots[data.guardSlotIndex].role))
        && sealAudit(playerId, stateId, data);
    }
    function sealPrepared(before, data, room) {
      return before.get('guardSchemaVersion', 0) == 1
        && before.guardRecruitmentId == room.recruitmentId
        && before.guardRoomRevision == room.revision - 1
        && before.guardCycleKey == data.cycleKey
        && before.guardCycleStartedAt == room.cycleStartedAt && before.guardCycleEndsAt == room.cycleEndsAt
        && !data.diff(before).affectedKeys().hasAny(${guards})
        && before.guardSlotIndex is int && before.guardSlotIndex >= 0
        && atomicAdvanceStateMatchesSlotAt(room, data, before.guardSlotIndex);
    }
    function sealAdvanceIdle(playerId, stateId, before, data) {
      let room = getAfter(recruitmentPath(data.recruitmentId)).data;
      return sealIdle(before) && sealPrepared(before, data, room) && deManualCurrentOwnership(data)
        && atomicIsLifecycleCommand(room) && room.lastCommandType == 'advanceCycle'
        && room.lastCommandAt == request.time
        && data.keys().hasOnly(['playerId', 'characterId', 'raidId', 'ownershipRevision',
          'guardSchemaVersion', 'guardRecruitmentId', 'guardRoomRevision', 'guardCycleKey', 'guardCycleStartedAt', 'guardCycleEndsAt', 'guardSlotIndex', 'guardCheckedAt',
          'schemaVersion', 'difficultyId', 'recruitmentId', 'cycleKey', 'role', 'status', 'source', 'revision', 'updatedAt'])
        && data.playerId == playerId && stateId == data.characterId + '_' + data.raidId
        && data.characterId == before.characterId && data.raidId == before.raidId
        && data.ownershipRevision == before.ownershipRevision
        && data.schemaVersion == 1 && data.status == 'active' && data.source == 'party'
        && data.revision == 1 && data.updatedAt == request.time
        && data.cycleKey == room.currentCycleKey && data.raidId == room.raidId
        && data.difficultyId == room.difficultyId && bug24CommandIncludes(room, playerId, stateId);
    }
    function sealBlocksClaimAt(path, cycle) {
      return (exists(path) && get(path).data.get('guardSchemaVersion', 0) == 1
          && get(path).data.guardCycleKey == cycle && request.time < get(path).data.guardCycleEndsAt)
        || (existsAfter(path) && getAfter(path).data.get('guardSchemaVersion', 0) == 1
          && getAfter(path).data.guardCycleKey == cycle && request.time < getAfter(path).data.guardCycleEndsAt);
    }
`;
source = source.replace('    function bug24Unchanged(', () => helpers + '\n    function bug24Unchanged(');
replace('oldData.cycleKey < data.cycleKey\n        && bug24AssignmentAvailable(data) && bug24PriorClaimAvailable(data)',
  'oldData.cycleKey < data.cycleKey\n        && sealPrepared(oldData, data, room)');
replace('        && bug24CommandIncludes(room, playerId, stateId) && atomicAdvanceStateMatchesSlot(room, data)\n        && !deBlockingClaim(playerId, data.cycleKey, data.characterId, data.raidId, data.get(\'ownershipRevision\', 0));',
  '        && bug24CommandIncludes(room, playerId, stateId);');
replaceFunction('validAtomicAdvanceRaidStateCreate', `    function validAtomicAdvanceRaidStateCreate(playerId, stateId, data) {
      return false;
    }`);
replace(`            && bug24AssignmentAvailable(newData)
            && bug24PriorClaimAvailable(newData)
            && !deBlockingClaim(playerId, newData.cycleKey, newData.characterId, newData.raidId, newData.get('ownershipRevision', 0))`,
  '            && sealPrepared(oldData, newData, recruitment)');
replace('            && atomicAdvanceStateMatchesSlot(recruitment, newData)));', '            ));');
// Every path introducing/changing seal metadata must take the audit branch, including old writers.
const stateMatch = source.indexOf('      match /raidStates/{stateId}');
for (const operation of ['create', 'update']) {
  const begin = source.indexOf(`        allow ${operation}: if`, stateMatch);
  const end = source.indexOf(';', begin);
  const old = source.slice(begin + `        allow ${operation}: if`.length, end);
  const condition = operation === 'create'
    ? `request.resource.data.keys().hasAny(${guards})`
    : `request.resource.data.diff(resource.data).affectedKeys().hasAny(${guards})`;
  const audit = operation === 'create'
    ? 'sealIdle(request.resource.data) && sealAudit(playerId, stateId, request.resource.data)'
    : 'sealAuditUpdate(playerId, stateId, resource.data, request.resource.data)';
  const otherwise = operation === 'create' ? old : `sealIdle(resource.data)
      ? sealAdvanceIdle(playerId, stateId, resource.data, request.resource.data) : (${old})`;
  source = source.slice(0, begin) + `        allow ${operation}: if (${condition}) ? (${audit}) : (${otherwise})` + source.slice(end);
}
// Assignment create/update are already unconditionally forbidden in the published contract.
assert.ok(source.includes('allow create, update: if false;'));
replace('        allow create: if validManualWeeklyRaidClaimCreate(', `        allow create: if !sealBlocksClaimAt(
          atomicRaidStateDocPath(playerId, request.resource.data.characterId + '_' + request.resource.data.raidId),
          request.resource.data.cycleKey) && validManualWeeklyRaidClaimCreate(`);
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(`${out}/candidate.rules`, source);
console.log('C availability seal: demo-only candidate generated; deployment writes 0');
