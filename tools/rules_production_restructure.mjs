import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

export function restructureProduction(input) {
  let source = input;
  const edit = (name, change) => {
    const f = rulesFunction(source, name);
    source = source.slice(0, f.start) + change(f.text) + source.slice(f.end);
  };
  const remove = (text, clause) => {
    assert.ok(text.includes(clause), clause);
    return text.replace(clause, '');
  };
  const gate = (startMarker, method, prefix) => {
    const start = source.indexOf(startMarker);
    assert.ok(start >= 0, startMarker);
    const at = source.indexOf(`allow ${method}: if`, start);
    const begin = at + `allow ${method}: if`.length;
    const end = source.indexOf(';', begin);
    assert.ok(at > start && end > begin);
    source = source.slice(0, begin) + ` ${prefix} && (` + source.slice(begin, end) + ')' + source.slice(end);
  };
  // All four creation alternatives had these two predicates, without exceptions.
  for (const name of ['validInitialGroupMember', 'validInvitedGroupMember', 'validApprovedGroupMember', 'validJoinCodeGroupMember']) {
    edit(name, t => remove(remove(t,
      '\n        && validNewGroupMemberCore(groupId, playerId, data)'),
      '\n        && validGroupMemberOptionalNumberFields(data)'));
  }
  gate('match /members/{playerId} {\n    function validInitialGroupMember', 'create',
    'validNewGroupMemberCore(groupId, playerId, request.resource.data) && validGroupMemberOptionalNumberFields(request.resource.data)');
  // Keep the original OR union; join-code acceptance overlaps invitation decisions.
  const decisions = ['validGroupJoinRelationDecision', 'validGroupApplicationDecision', 'validJoinCodeRelationAccept'];
  for (const name of decisions) edit(name, t => {
    for (const clause of [
      "\n        && newData.diff(oldData).affectedKeys()\n          .hasOnly(['status', 'revision', 'decidedAt', 'updatedAt'])",
      '\n        && newData.revision == oldData.revision + 1',
      '\n        && newData.decidedAt == request.time', '\n        && newData.updatedAt == request.time',
    ]) t = remove(t, clause);
    return t;
  });
  const decisionStart = source.indexOf("          : ((resource.data.kind == 'application'", source.indexOf('match /joinRelations/{playerId}'));
  assert.ok(decisionStart > 0);
  source = source.slice(0, decisionStart) + source.slice(decisionStart).replace(
    "          : ((resource.data.kind == 'application'",
    "          : (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'revision', 'decidedAt', 'updatedAt']) && request.resource.data.revision == resource.data.revision + 1 && request.resource.data.decidedAt == request.time && request.resource.data.updatedAt == request.time && ((resource.data.kind == 'application'");
  const decisionEnd = source.indexOf(';', decisionStart);
  source = source.slice(0, decisionEnd) + ')' + source.slice(decisionEnd);

  const general = ['validGroupActivityUpdate', 'validGroupMemberJoinUpdate', 'validGroupMemberLeaveUpdate',
    'validGroupLeaderTransferUpdate', 'validGroupDisbandUpdate', 'validGroupLeaderApproveUpdate',
    'validGroupJoinCodeFlagUpdate', 'validGroupJoinCodeVisibilityUpdate'];
  for (const name of [...general, 'validAtomicGroupRecruitmentCloseBody', 'validAtomicGroupRecruitmentOpenBody']) edit(name, t => {
    t = remove(t, '\n        && newData.revision == oldData.revision + 1');
    t = remove(t, '\n        && newData.updatedAt == request.time');
    if (general.includes(name)) t = remove(t, '\n        && newData.lastActivityAt == request.time');
    return t;
  });
  gate('match /groups/{groupId} {', 'update',
    'request.resource.data.revision == resource.data.revision + 1 && request.resource.data.updatedAt == request.time');
  const groupStart = source.indexOf('match /groups/{groupId} {');
  const update = source.indexOf('allow update:', groupStart);
  const end = source.indexOf(';', update);
  let block = source.slice(update, end);
  const boundary = ") : ((request.resource.data.memberCount";
  assert.ok(block.includes(boundary));
  block = block.replace(boundary, ") : (request.resource.data.lastActivityAt == request.time && ((request.resource.data.memberCount") + ')';
  source = source.slice(0, update) + block + source.slice(end);

  // Same-document common fields for party membership creation, not cross-document trust.
  for (const name of ['validAtomicInitialLeaderMembership', 'validAtomicJoinedMembership']) edit(name, t => {
    t = t.replace('return deCurrentOwnership(data) && hasActiveBinding()\n        && ', 'return ');
    for (const clause of ['\n        && data.schemaVersion == 1', '\n        && data.playerId == playerId',
      '\n        && data.joinedAt == request.time', '\n        && data.updatedAt == request.time']) t = remove(t, clause);
    return t;
  });
  gate('function validAtomicInitialLeaderMembership(', 'create',
    'deCurrentOwnership(request.resource.data) && hasActiveBinding() && request.resource.data.schemaVersion == 1 && request.resource.data.playerId == playerId && request.resource.data.joinedAt == request.time && request.resource.data.updatedAt == request.time');
  // Inline a single-use wrapper only: do not duplicate its body in every branch.
  const core = rulesFunction(source, 'validNewGroupMemberCore');
  const coreExpression = core.text.slice(core.text.indexOf('return ') + 7, core.text.lastIndexOf(';'));
  source = source.slice(0, core.start) + source.slice(core.end);
  const call = 'validNewGroupMemberCore(groupId, playerId, request.resource.data)';
  assert.equal(source.split(call).length, 2);
  source = source.replace(call, () => '(' + coreExpression.replace(/\bdata\b/g, 'request.resource.data') + ')');
  // P && join || join equals join. Remove the repeated, guarded evaluation only.
  const redundant = /\|\| \(request\.resource\.data\.diff\(resource\.data\)\.affectedKeys\(\)\s*\.hasOnly\(\['memberCount', 'revision', 'lastActivityAt', 'updatedAt'\]\)\s*&& request\.resource\.data\.memberCount == resource\.data\.memberCount \+ 1\s*&& validGroupJoinCommandUpdate\(\s*groupId,\s*resource\.data,\s*request\.resource\.data\s*\)\)/;
  assert.ok(redundant.test(source));
  source = source.replace(redundant, '');
  // One pending-relation entry, with actor-specific checks behind the kind branch.
  const invitation = rulesFunction(source, 'validGroupInvitationCreate');
  const application = rulesFunction(source, 'validGroupApplicationCreate');
  const pending = `    function validGroupPendingWrite(groupId, playerId, previousRevision, previousApplicationAttempt, reusable, data) {
      return validGroupPendingJoinRelation(groupId, playerId, previousRevision, reusable, data)
        && (data.kind == 'invitation'
          ? (data.requestedByPlayerId == currentPlayerId()
            && playerId != currentPlayerId() && isCurrentGroupMember(groupId)
            && data.applicationAttempt == previousApplicationAttempt)
          : (data.kind == 'application' && data.requestedByPlayerId == playerId
            && playerId == currentPlayerId() && data.applicationAttempt >= 1
            && data.applicationAttempt == getAfter(groupApplicantStatsPath(groupId, playerId)).data.applicationCount));
    }`;
  source = source.slice(0, invitation.start) + pending + source.slice(application.end);
  const pendingAllow = /allow create: if request\.resource\.data\.kind == 'invitation'[\s\S]*?(?=\n          : \(request\.resource\.data\.diff)/;
  assert.ok(pendingAllow.test(source));
  source = source.replace(pendingAllow, `allow create: if validGroupPendingWrite(groupId, playerId, 0, 0, true, request.resource.data);
        allow update: if request.resource.data.status == 'pending'
          ? validGroupPendingWrite(groupId, playerId, resource.data.revision,
              request.resource.data.kind == 'invitation' ? resource.data.applicationAttempt : 0,
              reusableGroupJoinRelation(resource.data), request.resource.data)`);
  // Lifecycle validators require a lifecycle marker AND lastCommandAt == request.time.
  // The first lifecycle dispatch already consumes that entire allowed set. In the
  // fallback those validators cannot succeed, including the last-completed disband.
  const deadDisband = /\(\(request\.resource\.data\.get\('lastCommandType', ''\) == 'disband'[\s\S]*?\? \(deLastCompletedDisband\(resource\.data, request\.resource\.data\)\s*&& \(validAtomicLifecycleUpdate\(resource\.data, request\.resource\.data\) && r1ListingTransition\(resource\.data, request\.resource\.data\)\)\)/;
  assert.ok(deadDisband.test(source));
  source = source.replace(deadDisband, match => '(!' + match.slice(1, match.indexOf('?')).trim() + ' &&');
  source = source.replace(/&&\s*: \(\(request\.resource\.data\.get\('lastCommandType', ''\) == 'cleanupCompletedPeerOwnership'\)/,
    "&& ((request.resource.data.get('lastCommandType', '') == 'cleanupCompletedPeerOwnership')");
  const deadLifecycle = / \|\| \(validAtomicLifecycleUpdate\(\s*resource\.data,\s*request\.resource\.data\s*\) && r1ListingTransition\(resource\.data, request\.resource\.data\)\)/;
  assert.ok(deadLifecycle.test(source));
  source = source.replace(deadLifecycle, '');
  // The earlier manual/older-state ternary owns this exact allowed set already.
  const repeatedManual = /\(\(request\.resource\.data\.source == 'manual'\s*&& deOlderState\(resource\.data, playerId, request\.resource\.data\.characterId,\s*request\.resource\.data\.raidId, request\.resource\.data\.get\('ownershipRevision', 0\)\)\s*&& validManualRaidStateCreate\(playerId, stateId, request\.resource\.data\)\)\s*\|\| /;
  assert.ok(repeatedManual.test(source));
  source = source.replace(repeatedManual, '(');
  return source;
}
