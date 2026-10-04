// Local candidates only: no promotion until differential emulator checks pass.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { orphanCleanupCandidate } from './roster_orphan_cleanup_candidate.mjs';

// Keep the comparison baseline reproducible after the accepted result is promoted.
export function integratedBaseline() {
  const source = fs.readFileSync(new URL('./fixtures/roster_reauth_preintegration.rules', import.meta.url), 'utf8').replace(/\r\n/g, '\n');
  return '// roster-reauth-integrated-v1\n' + orphanCleanupCandidate(source);
}

export function rulesFunction(source, name) {
  const start = source.indexOf(`    function ${name}(`);
  assert.ok(start >= 0, `missing function ${name}`);
  const open = source.indexOf('{', start);
  let depth = 1, end = open + 1;
  while (depth && end < source.length) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
    end++;
  }
  assert.equal(depth, 0, `unclosed function ${name}`);
  return { start, end, text: source.slice(start, end), body: source.slice(open + 1, end - 1) };
}

// These validators imply the earlier personalComplete/request.time dispatch.
// Remove only their unreachable fallback calls; keep every validator unchanged.
export function removeRepeatedPersonalCompletion(source) {
  const target = rulesFunction(source, 'personalCompletionTargetsCurrentPlayer').body;
  assert.ok(target.includes('personalCompletionCommandMarker(recruitment)'));
  assert.ok(target.includes('recruitment.lastCommandAt == request.time'));
  assert.ok(rulesFunction(source, 'personalCompletionCommandMarker').body.includes("data.lastCommandType == 'personalComplete'"));
  for (const [name, argument] of [
    ['validPersonalLastMemberCompletion', 'newData'],
    ['validPersonalCompletionRecruitmentUpdate', 'newData'],
    ['validPersonalCompletionMemberDelete', 'after'],
    ['validPersonalCompletionListingUpdate', 'recruitment'],
  ]) assert.ok(rulesFunction(source, name).body.includes(`personalCompletionTargetsCurrentPlayer(${argument})`));
  const fragments = [
    ` || (personalCompletionCommandMarker(request.resource.data)
          && dePersonalCompletionBoundary(resource.data, request.resource.data)
          && validPersonalCompletionRecruitmentUpdate(
            resource.data,
            request.resource.data
          ))`,
    ` || validPersonalCompletionMemberDelete(
          recruitmentId,
          playerId,
          resource.data
        )`,
    ` || validPersonalCompletionListingUpdate(
          recruitmentId,
          resource.data,
          request.resource.data
        )`,
  ];
  let result = source;
  for (const fragment of fragments) {
    assert.equal(result.split(fragment).length, 2, 'personal fallback source drift');
    result = result.replace(fragment, '');
  }
  return result;
}

export function deduplicateCleanup(source) {
  let result = source;
  // Compare bodies before substituting; generator drift must fail closed.
  for (const [duplicate, canonical] of [
    ['deLeaderOwnershipChanged', 'deOwnershipChanged'],
    ['dePeerOwnershipChanged', 'deOwnershipChanged'],
    ['deLeaderCleanupStateUnchanged', 'deCleanupStateUnchanged'],
    ['dePeerCleanupStateUnchanged', 'deCleanupStateUnchanged'],
    ['dePeerCleanupComposition', 'deCleanupComposition'],
  ]) {
    const old = rulesFunction(result, duplicate);
    assert.equal(old.body, rulesFunction(result, canonical).body, duplicate);
    result = result.slice(0, old.start) + result.slice(old.end + 1);
    result = result.replaceAll(`${duplicate}(`, `${canonical}(`);
  }
  const leader = rulesFunction(result, 'deLeaderCleanupComposition');
  const extras = `        && data.leaderPlayerId == room.leaderPlayerId
        && data.leaderCharacterNameSnapshot == room.leaderCharacterNameSnapshot
        && data.leaderClassNameSnapshot == room.leaderClassNameSnapshot
`;
  assert.ok(leader.body.includes(extras));
  assert.equal(leader.body.replace(extras, ''), rulesFunction(result, 'deCleanupComposition').body);
  result = result.slice(0, leader.start) + `    function deLeaderCleanupComposition(data, room) {
      return deCleanupComposition(data, room)
${extras.trimEnd()};
    }` + result.slice(leader.end);
  return result;
}

export function preserveExistingSlots(source) {
  const original = rulesFunction(source, 'deChangedSlotGenerations');
  const needle = '&& deChangedSlotGenerationAt(before, after, 0)';
  assert.equal(original.text.split(needle).length, 2);
  // hasAll uses the same exact element equality as the existing per-slot hasAny.
  // Retain size <= 8 and fall back unchanged for any newly added/modified slot.
  const replacement = original.text.replace(needle,
    '&& (before.partySlots.hasAll(after.partySlots)\n          || (deChangedSlotGenerationAt(before, after, 0)')
    .replace('deChangedSlotGenerationAt(before, after, 7));',
      'deChangedSlotGenerationAt(before, after, 7))));');
  assert.notEqual(replacement, original.text);
  return source.slice(0, original.start) + replacement + source.slice(original.end);
}

export function dispatchCleanupEvents(source) {
  const start = source.indexOf('    match /partyEvents/{eventId} {');
  const end = source.indexOf('    match /recruitments/{recruitmentId} {', start);
  assert.ok(start >= 0 && end > start);
  const section = source.slice(start, end);
  const allow = section.indexOf('      allow create:');
  assert.ok(allow >= 0);
  const terminator = section.indexOf(';', allow);
  // Only the three exact cleanup event types dispatch exclusively. The remaining
  // membership/lifecycle OR is unchanged. Each cleanup validator still checks
  // before/after revision, actor, request.time and exact event/command identity.
  const replacement = `      allow create: if request.resource.data.type == 'ownershipPeerRemoved'
        ? (request.resource.data.eventId == eventId && dePeerCleanupEventCreate(request.resource.data))
        : request.resource.data.type == 'ownershipLeaderRemoved'
          ? (request.resource.data.eventId == eventId && deLeaderCleanupEventCreate(request.resource.data))
          : request.resource.data.type == 'ownershipParticipantRemoved'
            ? (request.resource.data.eventId == eventId && deCleanupEventCreate(request.resource.data))
            : (validAtomicMembershipPartyEvent(request.resource.data)
              || validAtomicLifecyclePartyEvent(request.resource.data));`;
  return source.slice(0, start) + section.slice(0, allow) + replacement
    + section.slice(terminator + 1) + source.slice(end);
}

export function removeRepeatedPositionValidation(source) {
  const guard = "newData.diff(oldData).affectedKeys().hasOnly([\n          'partyIndex', 'slotIndex', 'updatedAt'\n        ])";
  assert.ok(rulesFunction(source, 'validMemberPositionChange').body.includes(guard),
    'position validator must imply the existing fast-path shape');
  const start = source.indexOf('      match /members/{playerId} {');
  const update = source.indexOf('        allow update:', start);
  const end = source.indexOf(';', update);
  assert.ok(start >= 0 && update > start && end > update);
  const block = source.slice(update, end);
  assert.ok(block.includes("request.resource.data.diff(resource.data).affectedKeys()\n              .hasOnly(['partyIndex', 'slotIndex', 'updatedAt'])"));
  assert.equal(block.split('validMemberPositionChange(').length, 3);
  const duplicate = ` || validMemberPositionChange(
            recruitmentId,
            playerId,
            resource.data,
            request.resource.data
          )`;
  assert.equal(block.split(duplicate).length, 2);
  return source.slice(0, update) + block.replace(duplicate, '') + source.slice(end);
}

export function validateOnlyChangedSlots(source) {
  const at = rulesFunction(source, 'deChangedSlotGenerationAt');
  assert.ok(at.body.includes('before.partySlots.hasAny([after.partySlots[index]])'));
  let result = source.slice(0, at.start) + `    function deChangedSlotGenerationAt(roomId, changed, index) {
      return index >= changed.size() || deSlotMemberGeneration(roomId, changed[index]);
    }` + source.slice(at.end);
  const all = rulesFunction(result, 'deChangedSlotGenerations');
  assert.ok(all.body.includes('before.partySlots.hasAll(after.partySlots)'));
  const checks = Array.from({ length: 8 }, (_, i) =>
    `deChangedSlotGenerationAt(before.recruitmentId, changed, ${i})`).join('\n          && ');
  result = result.slice(0, all.start) + `    function deChangedSlotGenerations(before, after) {
      let changed = after.partySlots.removeAll(before.partySlots);
      return before.partySlots == after.partySlots || (after.partySlots.size() <= 8
        && (changed.size() == 0 || (${checks})));
    }` + result.slice(all.end);
  return result;
}

export function prioritizeCharacterChange(source) {
  const start = source.indexOf('      match /members/{playerId} {');
  const begin = source.indexOf('        allow update:', start);
  const end = source.indexOf(';', begin);
  const block = source.slice(begin, end);
  const leader = 'deLeaderSuccessorUpdate(recruitmentId, playerId, resource.data, request.resource.data)';
  const atomic = `validAtomicMemberCharacterChange(
            recruitmentId,
            playerId,
            resource.data,
            request.resource.data
          )`;
  assert.equal(block.split(`${leader} || ${atomic}`).length, 2);
  return source.slice(0, begin) + block.replace(`${leader} || ${atomic}`, `${atomic} || ${leader}`) + source.slice(end);
}

export function prioritizeMemberRemoval(source) {
  assert.ok(rulesFunction(source,'validAtomicRecruitmentMemberRemoval').body.includes('&& newData.memberCount == oldData.memberCount - 1'));
  const begin=source.indexOf('      allow update:',source.indexOf('    match /recruitments/{recruitmentId}'));
  const end=source.indexOf(';',begin);
  let block=source.slice(begin,end);
  const call=`validAtomicRecruitmentMemberRemoval(
          resource.data,
          request.resource.data
        )`;
  const anchor="((request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership'";
  assert.equal(block.split(' || '+call).length,2);
  assert.equal(block.split(anchor).length,2);
  block=block.replace(' || '+call,'').replace(anchor,'((request.resource.data.memberCount == resource.data.memberCount - 1 && '+call+") || (request.resource.data.get('lastCommandType', '') == 'cleanupCompletedLeaderOwnership'");
  return source.slice(0,begin)+block+source.slice(end);
}
