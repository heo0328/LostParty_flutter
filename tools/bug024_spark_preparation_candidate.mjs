// Isolated Spark feasibility input. Never writes firestore.rules.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

export function distributePreparationRecords(source) {
  function replace(before, after) {
    assert.equal(source.split(before).length, 2, before);
    source = source.replace(before, () => after);
  }
  const begin = source.indexOf('    function bug24PrepRecords(');
  const end = source.indexOf('    function bug24PrepListing(', begin);
  assert.ok(begin > 0 && end > begin);
  source = source.slice(0, begin) + `
    function sparkPrepKnownCompleted(data, playerId, characterId, raidId, generation) {
      return data.schemaVersion == 1 && data.status == 'completed'
        && data.playerId == playerId && data.characterId == characterId && data.raidId == raidId
        && data.get('ownershipRevision', 0) == generation
        && data.revision is int && data.revision >= 1
        && data.cycleKey is string && data.cycleKey.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
        && data.source in ['manual', 'party']
        && (data.source == 'manual' ? data.get('role', null) == null || data.role in ['dealer', 'support'] : data.role in ['dealer', 'support'])
        && data.difficultyId is string && data.difficultyId.size() > 0;
    }
    function sparkPrepRecords(data) {
      let room = getAfter(recruitmentPath(data.recruitmentId)).data;
      let oldPath = atomicRaidStateDocPath(data.actorPlayerId, data.previousCharacterId + '_' + room.raidId);
      let newPath = atomicRaidStateDocPath(data.actorPlayerId, data.nextCharacterId + '_' + room.raidId);
      return hasActiveBinding() && data.actorPlayerId == currentPlayerId()
        && bug24PrepState(room) && room.updatedAt == request.time
        && data.commandRevision == room.revision && data.occurredAt == request.time
        && data.cycleKey == room.currentCycleKey
        && bug24Unchanged(oldPath) && bug24Unchanged(newPath)
        && (!exists(newPath) || sparkPrepKnownCompleted(get(newPath).data,
          data.actorPlayerId, data.nextCharacterId, room.raidId, data.nextOwnershipRevision))
        && bug24Unchanged(weeklyRaidClaimPath(data.actorPlayerId, data.cycleKey, data.previousCharacterId, room.raidId))
        && bug24Unchanged(weeklyRaidClaimPath(data.actorPlayerId, data.cycleKey, data.nextCharacterId, room.raidId));
    }
` + source.slice(end);
  replace('    function bug24PrepEvent(before, after) {',
    '    function bug24PrepEvent(before, after, oldMember, member) {');
  replace("        'occurredAt': request.time\n      };", `        'occurredAt': request.time,
        'previousCharacterId': oldMember.characterId, 'nextCharacterId': member.characterId,
        'nextOwnershipRevision': member.ownershipRevision, 'cycleKey': before.currentCycleKey
      };`);
  replace('        && bug24PrepEvent(before, after)',
    '        && bug24PrepEvent(before, after, get(path).data, getAfter(path).data)');
  replace('        && bug24PrepRecords(before, oldMember, member);',
    "        && bug24AssignmentAvailable({'playerId': playerId, 'characterId': member.characterId, 'raidId': before.raidId, 'ownershipRevision': member.ownershipRevision});");
  const match = source.indexOf('    match /partyEvents/{eventId}');
  const start = source.indexOf('      allow create: if ', match);
  const stop = source.indexOf(';', start);
  assert.ok(match > 0 && start > match && stop > start);
  const prior = source.slice(start + '      allow create: if '.length, stop);
  source = source.slice(0, start) + `      allow create: if
        (request.resource.data.type == 'characterChanged'
          && getAfter(recruitmentPath(request.resource.data.recruitmentId)).data.currentCycleStatus == 'completed')
          ? (request.resource.data.eventId == eventId && sparkPrepRecords(request.resource.data))
          : (${prior})` + source.slice(stop);
  return source;
}

if (process.argv.includes('--generate')) {
  const dir = 'coverage/bug024/spark';
  fs.mkdirSync(dir, { recursive: true });
  const baseline = execFileSync('git', ['show', 'e4f8e0f:firestore.rules'], { encoding: 'utf8' });
  const hash = createHash('sha256').update(baseline).digest('hex');
  assert.equal(hash, '36b5920e7677b395192e47e05daeea1eec4512beaf19250bf6c5a82eff352e3d');
  fs.writeFileSync(`${dir}/published-baseline.rules`, baseline);
  const readable = fs.readFileSync('coverage/rules-executable/review/readable.rules', 'utf8');
  fs.writeFileSync(`${dir}/preparation-distributed.rules`, distributePreparationRecords(readable));
  console.log(JSON.stringify({ baselineSha256: hash, candidate: 'isolated preparation distribution', deploymentWrites: 0 }));
}
