import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

// B1 informational fields only; A2 preserves the existing actor union.
export function groupDisplayContract(input) {
  let source = input;
  const edit = (name, change) => {
    const f = rulesFunction(source, name);
    source = source.slice(0, f.start) + change(f.text) + source.slice(f.end);
  };
  const strip = (name, clauses) => edit(name, text => {
    for (const clause of clauses) {
      assert.ok(text.includes(clause), `${name}: ${clause}`);
      text = text.replace(clause, '');
    }
    return text;
  });
  edit('validGroupMemberOptionalNumberFields', () => '');
  source = source.replace(' && validGroupMemberOptionalNumberFields(request.resource.data)', '');
  strip('validGroupMemberSelfSnapshotRefresh', ['\n        && validGroupMemberOptionalNumberFields(newData)']);
  // New member writes may omit an informational name. Such members must remain
  // eligible for their own display refresh; retain all non-display legacy keys.
  edit('validGroupMemberSelfSnapshotRefresh', text => {
    const old = "'displayCharacterNameSnapshot', 'revision', 'createdAt'";
    assert.ok(text.includes(old));
    return text.replace(old, "'revision', 'createdAt'");
  });
  strip('validInitialGroup', [
    '\n        && data.representativeCharacterNameSnapshot is string',
    '\n        && data.representativeCharacterNameSnapshot.size() > 0',
    '\n        && data.representativeServerNameSnapshot is string',
    '\n        && data.representativeServerNameSnapshot.size() > 0',
    '\n        && data.leaderDisplayCharacterNameSnapshot\n          == data.representativeCharacterNameSnapshot',
  ]);
  strip('validGroupLeaderTransferUpdate', ['\n        && newData.leaderDisplayCharacterNameSnapshot\n          == incoming.displayCharacterNameSnapshot']);
  strip('validInitialGroupMember', [
    '\n        && data.displayCharacterNameSnapshot is string',
    '\n        && group.leaderDisplayCharacterNameSnapshot\n          == data.displayCharacterNameSnapshot',
  ]);
  for (const name of ['validInvitedGroupMember', 'validApprovedGroupMember'])
    strip(name, ['\n        && data.displayCharacterNameSnapshot == relation.characterNameSnapshot']);
  strip('validJoinCodeGroupMember', [
    '\n        && data.displayCharacterNameSnapshot is string',
    '\n        && get(characterPath(data.displayCharacterIdSnapshot))\n          .data.characterName == data.displayCharacterNameSnapshot',
  ]);
  strip('validGroupPendingJoinRelation', ['characterNameSnapshot', 'serverNameSnapshot', 'characterClassNameSnapshot']
    .map(field => `\n        && data.${field} is string`));
  strip('validGroupRelationProjectionKeys', ['groupNameSnapshot', 'displayCharacterNameSnapshot']
    .map(field => `\n        && data.${field} is string && data.${field}.size() <= 256`));
  for (const [name, fields] of [
    ['validGroupApplicantStatsWrite', ['lastCharacterNameSnapshot', 'lastItemLevelSnapshot', 'lastCombatPowerSnapshot']],
    ['validGroupBlockCreate', ['characterNameSnapshot', 'itemLevelSnapshot', 'combatPowerSnapshot']],
  ]) strip(name, [
    `\n        && data.${fields[0]} is string && data.${fields[0]}.size() <= 256`,
    ...fields.slice(1).map(field => `\n        && (data.${field} == null || data.${field} is number)`),
  ]);

  // No new member dependency on the leader approval branch. Self-join retains it.
  edit('validGroupJoinCommandUpdate', () => `    function validGroupJoinCommandUpdate(groupId, oldData, newData) {
      return isCurrentPlayerActive() && oldData.status == 'active'
        && newData.diff(oldData).affectedKeys().hasOnly(['memberCount', 'revision', 'lastActivityAt', 'updatedAt'])
        && (newData.diff(oldData).affectedKeys().hasAny(['memberCount'])
          ? (newData.memberCount == oldData.memberCount + 1 && newData.memberCount <= 50
            && (oldData.leaderPlayerId == currentPlayerId()
              || ((isCurrentGroupMember(groupId) || existsAfter(groupRelationPath(currentPlayerId(), groupId)))
                && existsAfter(groupMemberPath(groupId, currentPlayerId()))
                && getAfter(groupMemberPath(groupId, currentPlayerId())).data.joinSequence == newData.memberCount)))
          : (isCurrentGroupMember(groupId) || existsAfter(groupRelationPath(currentPlayerId(), groupId))));
    }`);
  for (const name of ['validGroupActivityUpdate', 'validGroupMemberJoinUpdate', 'validGroupLeaderApproveUpdate']) edit(name, () => '');
  const approval = /\(request\.resource\.data\.memberCount\s*== resource\.data\.memberCount \+ 1\s*&& validGroupLeaderApproveUpdate\(\s*resource\.data,\s*request\.resource\.data\s*\)\) \|\| /;
  assert.ok(approval.test(source));
  source = source.replace(approval, '');

  // Close/open have the same allowed keys and recruitment lookup. Keep the
  // body union: count direction alone must not silently change fallback rights.
  edit('validAtomicGroupRecruitmentClose', text => text.replace('validAtomicGroupRecruitmentClose(', 'validGroupRecruitmentCountUpdate(')
    .replace('&& validAtomicGroupRecruitmentCloseBody(', '&& (validAtomicGroupRecruitmentCloseBody(')
    .replace('        );', `        ) || validAtomicGroupRecruitmentOpenBody(groupId, oldData, newData,
          getAfter(recruitmentPath(newData.lastRecruitmentId)).data));`));
  edit('validAtomicGroupRecruitmentOpen', () => '');
  const count = /validAtomicGroupRecruitmentClose\(\s*groupId,\s*resource\.data,\s*request\.resource\.data\s*\) \|\| validAtomicGroupRecruitmentOpen\(\s*groupId,\s*resource\.data,\s*request\.resource\.data\s*\)/;
  assert.ok(count.test(source));
  source = source.replace(count, 'validGroupRecruitmentCountUpdate(groupId, resource.data, request.resource.data)');
  assert.ok(!source.includes('validGroupMemberOptionalNumberFields'));
  return source;
}
