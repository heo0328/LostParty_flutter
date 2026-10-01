// H3 demo: validate generations where participation is created or replaced.
import assert from 'node:assert/strict';
import { generationCandidate } from './roster_generation_candidate.mjs';
export function participationCandidate(source) {
  let rules = generationCandidate(source);
  function editFunction(name, transform) {
    const start = rules.indexOf(`    function ${name}(`);
    const end = rules.indexOf('\n    function ', start + 1);
    assert.ok(start >= 0 && end > start, name);
    const before = rules.slice(start, end), after = transform(before);
    assert.notEqual(after, before, name);
    rules = rules.slice(0, start) + after + rules.slice(end);
  }
  for (const name of ['validAtomicRaidStateCreate', 'validAtomicInitialLeaderMembership', 'validAtomicJoinedMembership']) {
    editFunction(name, text => text.replace('return hasActiveBinding()', 'return deCurrentOwnership(data) && hasActiveBinding()'));
  }
  editFunction('atomicInitialPartySlotMatches', text => text.replace('return slot.playerId == playerId',
    "return slot.get('ownershipRevision', 0) == member.get('ownershipRevision', 0)\n        && slot.playerId == playerId"));
  editFunction('validAtomicRaidStateCreate', text => text.replace('&& data.characterId == member.characterId',
    "&& data.characterId == member.characterId\n        && data.get('ownershipRevision', 0) == member.get('ownershipRevision', 0)"));
  editFunction('validAtomicJoinedMembership', text => text.replace('&& (directJoin || approvedJoin)',
    '&& (directJoin || (approvedJoin && deApprovedGeneration(recruitmentId, playerId, data)))'));
  editFunction('validPendingApplication', text => text.replace('return hasActiveBinding()', 'return deApplicationGeneration(data) && hasActiveBinding()'));
  editFunction('validApplicationReapply', text => text.replace('return hasActiveBinding()', 'return deApplicationGeneration(newData) && hasActiveBinding()')
    .replace("'countedAsNonGroupApplicant'", "'countedAsNonGroupApplicant', 'ownershipRevision'"));
  editFunction('validAtomicMemberCharacterChange', text => text.replace('return hasActiveBinding()', 'return deCurrentOwnership(newData) && hasActiveBinding()')
    .replace("'buildIntegritySnapshot',", "'buildIntegritySnapshot', 'ownershipRevision',"));
  editFunction('atomicCharacterSlot', text => {
    const value = text.slice(text.indexOf('return ') + 7, text.indexOf(';'));
    return text.replace(`return ${value};`, `return member.keys().hasAny(['ownershipRevision'])
        ? ${value.replace("'playerId':", "'ownershipRevision': member.ownershipRevision, 'playerId':")}
        : ${value};`);
  });
  const marker = '    match /recruitments/{recruitmentId} {';
  const start = rules.indexOf('      allow update: if ', rules.indexOf(marker));
  const end = rules.indexOf('      allow delete: if false;', start);
  assert.ok(start > 0 && end > start);
  const original = rules.slice(start, end).trim().replace(/^allow update: if /, '').replace(/;$/, '');
  rules = rules.slice(0, start) + `      allow update: if deChangedSlotGenerations(resource.data, request.resource.data)
        && (${original});
` + rules.slice(end);
  const memberStart = rules.indexOf('        allow update: if ', rules.indexOf('      match /members/{playerId} {', rules.indexOf(marker)));
  const memberEnd = rules.indexOf('        allow delete: if ', memberStart);
  assert.ok(memberStart > 0 && memberEnd > memberStart);
  const memberOriginal = rules.slice(memberStart, memberEnd).trim().replace(/^allow update: if /, '').replace(/;$/, '');
  rules = rules.slice(0, memberStart) + `        allow update: if
          ((request.resource.data.characterId == resource.data.characterId
            && request.resource.data.get('ownershipRevision', 0) == resource.data.get('ownershipRevision', 0))
            || deCurrentOwnership(request.resource.data))
          && (${memberOriginal});
` + rules.slice(memberEnd);
  return rules.replace('    function deValidGeneration(', `
    function deApplicationGeneration(data) {
      return deCurrentOwnership({'characterId': data.characterId, 'playerId': data.applicantPlayerId,
        'ownershipRevision': data.get('ownershipRevision', 0)});
    }
    function deApprovedGeneration(roomId, playerId, member) {
      let application = get(/databases/$(database)/documents/recruitments/$(roomId)/applications/$(playerId)).data;
      return application.status == 'pending' && application.characterId == member.characterId
        && application.get('ownershipRevision', 0) == member.get('ownershipRevision', 0);
    }
    function deSlotMemberGeneration(roomId, slot) {
      let member = getAfter(/databases/$(database)/documents/recruitments/$(roomId)/members/$(slot.playerId)).data;
      return member.playerId == slot.playerId && member.characterId == slot.characterId
        && slot.get('ownershipRevision', 0) is int && slot.get('ownershipRevision', 0) >= 0
        && slot.get('ownershipRevision', 0) == member.get('ownershipRevision', 0);
    }
    function deChangedSlotGenerationAt(before, after, index) {
      return index >= after.partySlots.size() || before.partySlots.hasAny([after.partySlots[index]])
        || deSlotMemberGeneration(before.recruitmentId, after.partySlots[index]);
    }
    function deChangedSlotGenerations(before, after) {
      return before.partySlots == after.partySlots || (after.partySlots.size() <= 8
        && deChangedSlotGenerationAt(before, after, 0) && deChangedSlotGenerationAt(before, after, 1)
        && deChangedSlotGenerationAt(before, after, 2) && deChangedSlotGenerationAt(before, after, 3)
        && deChangedSlotGenerationAt(before, after, 4) && deChangedSlotGenerationAt(before, after, 5)
        && deChangedSlotGenerationAt(before, after, 6) && deChangedSlotGenerationAt(before, after, 7));
    }
    function deValidGeneration(`);
}
