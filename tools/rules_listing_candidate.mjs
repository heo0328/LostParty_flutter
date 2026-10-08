import assert from 'node:assert/strict';
import fs from 'node:fs';
import { rulesFunction } from './roster_complexity_candidate.mjs';

// Review-only R1 candidate. The 8-member character/placement regression still
// exceeds the evaluation budget. Never promote this output to deployment Rules
// until the complete R1 acceptance gate passes (reduction design section 17).

export function canonicalListings(source) {
  const dart = fs.readFileSync(new URL('../lib/features/recruitment_list/data/mappers/party_raid_listing_document.dart', import.meta.url), 'utf8');
  const fieldBlock = dart.match(/const partyRaidListingFields = <String>\{([\s\S]*?)\};/);
  assert.ok(fieldBlock, 'listing field contract');
  const fields = [...fieldBlock[1].matchAll(/'([^']+)'/g)].map(m => m[1]);
  assert.equal(fields.length, new Set(fields).size);
  const replaceFunction = (name, text) => {
    const f = rulesFunction(source, name);
    source = source.slice(0, f.start) + text + source.slice(f.end);
  };
  // These helpers are consumed only by the source's mandatory listing checks.
  replaceFunction('deCleanupComposition', `    function deCleanupComposition(data, room) {
      return data == room;
    }`);
  replaceFunction('dePersonalCompletionListing', `    function dePersonalCompletionListing(before, after) {
      let path = /databases/$(database)/documents/groups/$(before.groupId)/raidListings/$(before.recruitmentId);
      return before.visibility != 'group' || (after.memberCount == 0
        ? !existsAfter(path) : getAfter(path).data == after);
    }`);
  const start = source.indexOf('      match /raidListings/{recruitmentId} {');
  const end = source.indexOf('      match /joinRelations/{playerId} {', start);
  assert.ok(start >= 0 && end > start);
  source = source.slice(0, start) + `      match /raidListings/{recruitmentId} {
        function r1ListingCopy(data, room) {
          return room.groupId == groupId && room.visibility == 'group'
            && data == room && data.keys().hasOnly([${fields.map(f => `'${f}'`).join(', ')}]);
        }
        function r1ListingWrite(data) {
          let path = recruitmentPath(recruitmentId);
          let after = getAfter(path).data;
          return hasActiveBinding() && r1ListingCopy(data, after)
            && after.updatedAt == request.time
            && (!exists(path) ? after.revision == 1
              : after.revision == get(path).data.revision + 1);
        }
        function r1ListingBackfill(data) {
          let path = recruitmentPath(recruitmentId);
          let before = get(path).data;
          return isCurrentGroupMember(groupId)
            && currentPlayerId() in before.memberPlayerIds
            && before.status != 'disbanded' && before.currentCycleStatus != 'disbanded'
            && getAfter(path).data == before && r1ListingCopy(data, before);
        }
        function r1ListingCreate(data) {
          let path = recruitmentPath(recruitmentId);
          return r1ListingWrite(data) && (!exists(path)
            || get(path).data.visibility != 'group'
            || (data.memberCount >= get(path).data.memberCount
              && data.currentCycleStatus != 'completed'
              && !(data.get('lastCommandType', '') in ['complete', 'advanceCycle'])));
        }
        function r1ListingDelete() {
          let path = recruitmentPath(recruitmentId);
          let before = get(path).data;
          let after = getAfter(path).data;
          return hasActiveBinding() && before.groupId == groupId && after.groupId == groupId
            && after.revision == before.revision + 1 && after.updatedAt == request.time
            && (after.visibility == 'public' || after.status in ['completed', 'disbanded', 'incompleteEnded']);
        }
        allow get, list: if isCurrentGroupMember(groupId);
        allow create: if r1ListingCreate(request.resource.data) || r1ListingBackfill(request.resource.data);
        allow update: if r1ListingWrite(request.resource.data);
        allow delete: if r1ListingDelete();
      }

` + source.slice(end);
  const helpers = `    function r1InitialListing(after) {
      return after.visibility != 'group' || getAfter(/databases/$(database)/documents/groups/$(after.groupId)/raidListings/$(after.recruitmentId)).data == after;
    }
    function r1ListingTransition(before, after) {
      return (after.visibility != 'group' && before.visibility != 'group')
        || ((after.visibility != 'group' || after.status in ['completed', 'disbanded', 'incompleteEnded'])
          ? !existsAfter(/databases/$(database)/documents/groups/$(after.groupId)/raidListings/$(after.recruitmentId))
          : getAfter(/databases/$(database)/documents/groups/$(after.groupId)/raidListings/$(after.recruitmentId)).data == after);
    }
`;
  const anchor = '    function validAtomicInitialRecruitment(';
  assert.ok(source.includes(anchor)); source = source.replace(anchor, helpers + anchor);
  const create = 'allow create: if validAtomicInitialRecruitment(\n        recruitmentId,\n        request.resource.data\n      );';
  assert.ok(source.includes(create)); source = source.replace(create, create.replace('      );', '      ) && r1InitialListing(request.resource.data);'));
  const rootStart = source.indexOf('      allow update: if ', source.indexOf('      allow get: if canGetRecruitment('));
  const rootEnd = source.indexOf(';', rootStart);
  assert.ok(rootStart >= 0 && rootEnd > rootStart);
  let expression = source.slice(rootStart, rootEnd);
  // Preparation, personal completion and cleanup already bind the final listing.
  // Add the obligation only to source branches that did not have that binding.
  for (const name of ['validAtomicLifecycleUpdate', 'validAtomicRecruitmentMemberRemoval',
    'validRecurrenceChange', 'validAtomicRecruitmentJoin', 'validAtomicCharacterRevisionUpdate',
    'validAtomicPositionAggregateUpdate', 'validAtomicRecruitmentVisibilityChange']) {
    const call = new RegExp(`${name}\\(\\s*resource\\.data,\\s*request\\.resource\\.data\\s*\\)`, 'g');
    assert.ok(call.test(expression), name); call.lastIndex = 0;
    const binding = ['validRecurrenceChange', 'validAtomicRecruitmentJoin',
      'validAtomicCharacterRevisionUpdate', 'validAtomicPositionAggregateUpdate'].includes(name)
      ? 'r1InitialListing(request.resource.data)'
      : 'r1ListingTransition(resource.data, request.resource.data)';
    expression = expression.replace(call, match => `(${match} && ${binding})`);
  }
  source = source.slice(0, rootStart) + expression + source.slice(rootEnd);
  return source;
}
