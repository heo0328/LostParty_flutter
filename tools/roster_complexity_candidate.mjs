// Local candidates only: no promotion until differential emulator checks pass.
import assert from 'node:assert/strict';

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
