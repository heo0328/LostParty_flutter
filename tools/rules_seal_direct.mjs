import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

export function directSealValidation(source) {
  const replace = (before, after) => {
    assert.equal(source.split(before).length, 2, before);
    source = source.replace(before, () => after);
  };
  const replaceFunction = (name, text) => {
    const f = rulesFunction(source, name);
    source = source.slice(0, f.start) + text + source.slice(f.end);
  };
  const audit = rulesFunction(source, 'sealAudit').text;
  const update = rulesFunction(source, 'sealAuditUpdate').text;
  const prior = update.slice(update.indexOf('return ') + 7,
    update.indexOf('\n        && sealAudit('));
  let merged = audit.replace('sealAudit(playerId, stateId, data, room)',
    'sealAudit(playerId, stateId, before, data, updating)')
    .replace('      let index =', `      let room = get(/databases/$(database)/documents/recruitments/$(data.guardRecruitmentId)).data;
      let assignment = /databases/$(database)/documents/players/$(playerId)/activeRaidAssignments/$(stateId);
      let claimId = data.guardCycleKey + '_' + data.characterId + '_' + data.raidId;
      let claim = /databases/$(database)/documents/players/$(playerId)/weeklyRaidClaims/$(claimId);
      let index =`)
    .replace('return hasActiveBinding()', () => `return (!updating || (${prior}))\n        && hasActiveBinding()`)
    .replace('getAfter(recruitmentPath(data.guardRecruitmentId))',
      'getAfter(/databases/$(database)/documents/recruitments/$(data.guardRecruitmentId))')
    .replace('sealAvailableBefore(assignmentPath(playerId, stateId), data)',
      '(!exists(assignment) || deOlderRecord(get(assignment).data, data.playerId, data.characterId, data.raidId, data.ownershipRevision))')
    .replace('sealAvailableBefore(weeklyRaidClaimPath(playerId, data.guardCycleKey, data.characterId, data.raidId), data)',
      '(!exists(claim) || deOlderRecord(get(claim).data, data.playerId, data.characterId, data.raidId, data.ownershipRevision))');
  replaceFunction('sealAudit', merged);
  replaceFunction('sealAuditUpdate', '');
  replaceFunction('sealAvailableBefore', '');
  replace('sealAudit(playerId, stateId, request.resource.data, get(recruitmentPath(request.resource.data.guardRecruitmentId)).data)',
    'sealAudit(playerId, stateId, request.resource.data, request.resource.data, false)');
  replace('sealAuditUpdate(playerId, stateId, resource.data, request.resource.data)',
    'sealAudit(playerId, stateId, resource.data, request.resource.data, true)');

  const slot = rulesFunction(source, 'atomicAdvanceStateMatchesSlotAt').text;
  const slotExpression = slot.slice(slot.indexOf('return ') + 7, slot.lastIndexOf(';'))
    .replace(/\brecruitment\b/g, 'room').replace(/\bindex\b/g, 'before.guardSlotIndex');
  replace('atomicAdvanceStateMatchesSlotAt(room, data, before.guardSlotIndex)', `(${slotExpression})`);
  for (const name of ['sealAdvanceIdle', 'bug24AdvanceCompleted']) {
    const original = rulesFunction(source, name).text;
    const direct = original.replace('getAfter(recruitmentPath(data.recruitmentId))',
      'getAfter(/databases/$(database)/documents/recruitments/$(data.recruitmentId))')
      // Equality to this enum member implies the removed string/enum predicate.
      .replace("atomicIsLifecycleCommand(room) && room.lastCommandType == 'advanceCycle'",
        "room.lastCommandType == 'advanceCycle'")
      .replace('bug24CommandIncludes(room, playerId, stateId)',
        "(room.commandTargets.size() <= 8 && {'playerId': playerId, 'stateId': stateId} in room.commandTargets)");
    assert.notEqual(original, direct);
    replaceFunction(name, direct);
  }
  replaceFunction('bug24CommandIncludes', '');
  for (const removed of ['sealAuditUpdate', 'sealAvailableBefore', 'bug24CommandIncludes'])
    assert.ok(!new RegExp(`\\b${removed}\\s*\\(`).test(source), `Unresolved ${removed}: ${source.split('\n').filter(l=>l.includes(removed)).join('\n')}`);
  return source;
}
