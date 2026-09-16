import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;
  late Map<String, Object?> indexes;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync().replaceAll('\r\n', '\n');
    indexes =
        jsonDecode(File('firestore.indexes.json').readAsStringSync())
            as Map<String, Object?>;
  });

  test('그룹 경로 helper와 멤버·그룹장 판정을 제공한다', () {
    expect(rules, contains('function groupPath(groupId)'));
    expect(rules, contains('function groupMemberPath(groupId, playerId)'));
    expect(rules, contains('function groupMembershipStatePath(playerId)'));
    expect(rules, contains('function groupRelationPath(playerId, groupId)'));
    expect(rules, contains('function isCurrentGroupMember(groupId)'));
    expect(rules, contains('function isCurrentGroupLeader(groupId)'));
  });

  test('그룹 생성은 active Player와 인원 1·revision 1을 강제한다', () {
    final start = rules.indexOf('function validInitialGroup(');
    final end = rules.indexOf('function validInitialGroupMember(');
    final initialGroupRule = rules.substring(start, end);

    expect(rules, contains('function validInitialGroup(groupId, data)'));
    expect(initialGroupRule, isNot(contains('slotLedgerVersion')));
    expect(rules, contains('isCurrentPlayerActive()'));
    expect(rules, contains("data.status == 'active'"));
    expect(rules, contains('data.memberCount == 1'));
    expect(initialGroupRule, contains("'activeRecruitmentCount'"));
    expect(rules, contains('data.activeRecruitmentCount == 0'));
    expect(rules, contains('data.revision == 1'));
    expect(rules, contains('data.hasActiveJoinCode == false'));
    expect(
      rules,
      contains("!('activeJoinCode' in data) || data.activeJoinCode == null"),
    );
    expect(rules, contains('data.deletedAt == null'));
    expect(rules, contains('data.lastActivityAt == request.time'));
    expect(
      rules,
      contains('ownsActiveCharacter(data.representativeCharacterId)'),
    );
  });

  test('그룹 생성은 leader member·membership state·relation을 함께 확인한다', () {
    expect(
      rules,
      contains('getAfter(groupMemberPath(groupId, playerId)).data'),
    );
    expect(
      rules,
      contains('getAfter(groupMembershipStatePath(playerId)).data'),
    );
    expect(rules, contains('groupId in state.activeGroupIds'));
    expect(
      rules,
      contains('existsAfter(groupRelationPath(playerId, groupId))'),
    );
  });

  test('생성자 membership은 leader·joinSequence 1·created만 허용한다', () {
    expect(
      rules,
      contains('function validInitialGroupMember(groupId, playerId, data)'),
    );
    expect(
      rules,
      contains('function validNewGroupMemberCore(groupId, playerId, data)'),
    );
    expect(rules, contains("data.role == 'leader'"));
    expect(rules, contains("data.joinedBy == 'created'"));
    expect(rules, contains('data.joinSequence == 1'));
    expect(rules, contains('group.leaderPlayerId == playerId'));
  });

  test('membership state는 Group ID 1개 추가와 50개 한도를 강제한다', () {
    expect(
      rules,
      contains(
        'function validMembershipStateAdd(\n'
        '      playerId,\n'
        '      docId,\n'
        '      previousIds,\n'
        '      previousRevision,\n'
        '      newData',
      ),
    );
    expect(rules, contains('newData.activeGroupIds.size() <= 50'));
    expect(
      rules,
      contains('newData.activeGroupIds.size() == previousIds.size() + 1'),
    );
    expect(
      rules,
      contains('newData.activeGroupCount == newData.activeGroupIds.size()'),
    );
    expect(rules, contains('newData.revision == previousRevision + 1'));
  });

  test('member relation Projection은 원본 그룹·membership에 묶인다', () {
    expect(
      rules,
      contains(
        'function validInitialMemberGroupRelation(playerId, groupId, data)',
      ),
    );
    expect(rules, contains("data.relation == 'member'"));
    expect(rules, contains('data.requestStatus == null'));
    expect(rules, contains('data.groupNameSnapshot == group.name'));
    expect(rules, contains('data.sourceRevision == member.revision'));
  });

  test('그룹 원본은 공개 active만 list하고 수정·삭제를 막는다', () {
    expect(rules, contains('match /groups/{groupId}'));
    expect(rules, contains('allow get: if canGetGroup(groupId);'));
    expect(
      rules,
      contains(
        "allow list: if hasActiveBinding() && resource.data.status == 'active';",
      ),
    );
    expect(
      rules,
      contains(
        'allow create: if validInitialGroup(groupId, request.resource.data);',
      ),
    );
    expect(rules, contains('allow update, delete: if false;'));
  });

  test('그룹 전용 레이드 목록 Projection은 경로의 그룹원만 list한다', () {
    expect(rules, contains('function validGroupRaidListingCreate('));
    expect(
      rules,
      contains('data.diff(recruitment).affectedKeys().size() == 0'),
    );
    expect(rules, contains('match /raidListings/{recruitmentId}'));
    expect(
      rules,
      contains('allow get, list: if isCurrentGroupMember(groupId);'),
    );
    expect(rules, contains('allow create: if validGroupRaidListingCreate('));
    expect(rules, contains('function validGroupRaidListingBackfill('));
    expect(rules, contains('|| validGroupRaidListingBackfill('));
    expect(rules, contains('function validGroupRaidListingDelete('));
    expect(
      rules,
      contains(
        'allow delete: if validGroupRaidListingDelete(groupId, recruitmentId)',
      ),
    );
    expect(rules, contains('|| validAtomicLifecycleListingDelete('));
    expect(rules, contains('allow update: if validGroupRaidListingCreate('));
    expect(rules, contains('|| validAtomicLifecycleListingUpdate('));
  });

  test('Unit 4는 초대코드 생성·폐기·정확한 get을 열고 list·update는 막는다', () {
    final joinCodes = rules.substring(rules.indexOf('match /groupJoinCodes/'));
    expect(rules, contains('match /groupJoinCodes/{code}'));
    expect(rules, contains('function validJoinCodeId(code)'));
    expect(
      rules,
      contains("code.matches('^([2-9A-HJ-NP-Z]{6}|[2-9A-HJ-NP-Z]{20})\$')"),
    );
    expect(rules, contains('function validJoinCodeCreate(code, data)'));
    expect(rules, contains('function validJoinCodeDelete(code)'));
    expect(rules, contains('before.hasActiveJoinCode == false'));
    expect(rules, contains('after.hasActiveJoinCode == true'));
    expect(rules, contains('before.hasActiveJoinCode == true'));
    expect(rules, contains('after.hasActiveJoinCode == false'));
    expect(
      joinCodes,
      contains('allow get: if hasActiveBinding() && validJoinCodeId(code);'),
    );
    expect(joinCodes, contains('allow list: if false;'));
    expect(
      joinCodes,
      contains(
        'allow create: if validJoinCodeCreate(code, request.resource.data);',
      ),
    );
    expect(joinCodes, contains('allow update: if false;'));
    expect(joinCodes, contains('allow delete: if validJoinCodeDelete(code);'));
  });

  test('초대코드 플래그·표시 정책 그룹 update와 코드 가입 membership을 연다', () {
    expect(
      rules,
      contains('function validGroupJoinCodeFlagUpdate(oldData, newData)'),
    );
    expect(
      rules,
      contains('function validGroupJoinCodeVisibilityUpdate(oldData, newData)'),
    );
    final groupMatch = rules.substring(
      rules.indexOf('match /groups/{groupId}'),
    );
    expect(
      groupMatch.indexOf('validGroupJoinCodeFlagUpdate('),
      lessThan(groupMatch.indexOf('validGroupMemberLeaveUpdate(')),
    );
    expect(
      groupMatch.indexOf('validGroupJoinCodeVisibilityUpdate('),
      lessThan(groupMatch.indexOf('validGroupMemberLeaveUpdate(')),
    );
    expect(
      groupMatch.indexOf('validGroupJoinCommandUpdate('),
      lessThan(groupMatch.indexOf('validGroupMemberLeaveUpdate(')),
    );
    expect(
      rules,
      contains(
        "'hasActiveJoinCode', 'activeJoinCode', 'revision', 'lastActivityAt'",
      ),
    );
    expect(
      rules,
      contains("'joinCodeVisibleToMembers', 'revision', 'lastActivityAt'"),
    );
    expect(
      rules,
      contains('function validJoinCodeGroupMember(groupId, playerId, data)'),
    );
    expect(rules, contains("data.joinedBy == 'joinCode'"));
    expect(
      rules,
      contains('ownsActiveCharacter(data.displayCharacterIdSnapshot)'),
    );
    expect(
      rules,
      contains(
        'function validJoinCodeRelationAccept(groupId, playerId, oldData, newData)',
      ),
    );
    expect(
      rules,
      contains(
        'function validJoinCodeMemberGroupRelation(playerId, groupId, data)',
      ),
    );
    expect(rules, contains(') || validJoinCodeGroupMember('));
    expect(rules, contains(') || validJoinCodeRelationAccept('));
    expect(rules, contains(') || validGroupJoinCodeFlagUpdate('));
    expect(rules, contains(') || validGroupJoinCodeVisibilityUpdate('));
    expect(rules, contains("|| member.joinedBy == 'joinCode'"));
  });

  test('초대·신청 경로 helper와 금지 판정을 제공한다', () {
    expect(
      rules,
      contains('function groupJoinRelationPath(groupId, playerId)'),
    );
    expect(
      rules,
      contains('function groupApplicantStatsPath(groupId, playerId)'),
    );
    expect(rules, contains('function groupBlockPath(groupId, playerId)'));
    expect(rules, contains('function hasGroupBlock(groupId, playerId)'));
  });

  test('pending 요청은 허용 필드·24시간 만료·멤버·금지 부재를 강제한다', () {
    expect(rules, contains('function validGroupJoinRelationKeys(data)'));
    expect(
      rules,
      contains(
        'function validGroupPendingJoinRelation(\n'
        '      groupId,\n'
        '      playerId,\n'
        '      previousRevision,\n'
        '      reusable,\n'
        '      data',
      ),
    );
    expect(rules, contains("data.status == 'pending'"));
    expect(rules, contains('data.createdAt == request.time'));
    expect(rules, contains('data.decidedAt == null'));
    expect(rules, contains('function validGroupRequestExpiry(data)'));
    expect(
      rules,
      contains("data.expiresAt > request.time + duration.value(23, 'h')"),
    );
    expect(
      rules,
      contains("data.expiresAt < request.time + duration.value(25, 'h')"),
    );
    expect(rules, contains('!exists(groupMemberPath(groupId, playerId))'));
    expect(rules, contains('!hasGroupBlock(groupId, playerId)'));
    expect(
      rules,
      contains('existsAfter(groupRelationPath(playerId, groupId))'),
    );
  });

  test('유효 pending 관계는 종류가 달라도 새 요청으로 덮어쓰지 못한다', () {
    expect(rules, contains('function reusableGroupJoinRelation(oldData)'));
    expect(rules, contains("oldData.status != 'pending'"));
    expect(rules, contains('oldData.expiresAt <= request.time'));
    expect(rules, contains('data.revision == previousRevision + 1'));
  });

  test('직접 초대는 현재 그룹원만 만들고 신청 횟수를 늘리지 않는다', () {
    expect(
      rules,
      contains(
        'function validGroupInvitationCreate(\n'
        '      groupId,\n'
        '      playerId,\n'
        '      previousRevision,\n'
        '      previousApplicationAttempt,\n'
        '      reusable,\n'
        '      data',
      ),
    );
    expect(rules, contains("data.kind == 'invitation'"));
    expect(rules, contains('data.requestedByPlayerId == currentPlayerId()'));
    expect(rules, contains('playerId != currentPlayerId()'));
    expect(rules, contains('isCurrentGroupMember(groupId)'));
    expect(rules, contains('data.applicationAttempt == previousApplicationAttempt'));
  });

  test('가입 신청은 본인만 만들고 applicantStats 횟수와 함께 맞춘다', () {
    expect(
      rules,
      contains(
        'function validGroupApplicationCreate(\n'
        '      groupId,\n'
        '      playerId,\n'
        '      previousRevision,\n'
        '      reusable,\n'
        '      data',
      ),
    );
    expect(rules, contains("data.kind == 'application'"));
    expect(rules, contains('data.requestedByPlayerId == playerId'));
    expect(
      rules,
      contains('data.applicationAttempt == stats.applicationCount'),
    );
    expect(
      rules,
      contains(
        'function validGroupApplicantStatsWrite(\n'
        '      groupId,\n'
        '      playerId,\n'
        '      previousApplicationCount,\n'
        '      previousCreatedAt,\n'
        '      data',
      ),
    );
    expect(rules, contains('data.applicationCount == previousApplicationCount + 1'));
    expect(rules, contains("relation.kind == 'application'"));
    expect(
      rules,
      contains('relation.applicationAttempt == data.applicationCount'),
    );
  });

  test('수락·거절은 대상 Player만, 취소는 발신자 또는 그룹장만 한다', () {
    expect(
      rules,
      contains(
        'function validGroupJoinRelationDecision(groupId, playerId, oldData, newData)',
      ),
    );
    expect(
      rules,
      contains("hasOnly(['status', 'revision', 'decidedAt', 'updatedAt'])"),
    );
    expect(rules, contains("oldData.kind == 'invitation'"));
    expect(rules, contains("oldData.status == 'pending'"));
    expect(rules, contains('newData.revision == oldData.revision + 1'));
    expect(rules, contains('oldData.expiresAt > request.time'));
    expect(rules, contains('existsAfter(groupMemberPath(groupId, playerId))'));
    expect(rules, contains('oldData.requestedByPlayerId == currentPlayerId()'));
    expect(rules, contains('isCurrentGroupLeader(groupId)'));
  });

  test('초대 수락 membership은 member·invitation·인원 + 1을 강제한다', () {
    expect(
      rules,
      contains('function validInvitedGroupMember(groupId, playerId, data)'),
    );
    expect(rules, contains("data.role == 'member'"));
    expect(rules, contains("data.joinedBy == 'invitation'"));
    expect(rules, contains('data.joinSequence == group.memberCount'));
    expect(rules, contains("relation.status == 'accepted'"));
    expect(rules, contains('groupId in state.activeGroupIds'));
    expect(
      rules,
      contains(') || validInvitedGroupMember('),
      reason: 'members create는 생성자 경로와 초대 수락 경로만 허용한다.',
    );
  });

  test('그룹 원본 update는 활동 시각과 초대 수락 인원 증가만 허용한다', () {
    expect(
      rules,
      contains('function validGroupActivityUpdate(oldData, newData)'),
    );
    expect(
      rules,
      contains("hasOnly(['revision', 'lastActivityAt', 'updatedAt'])"),
    );
    expect(
      rules,
      contains(
        'function validGroupMemberJoinUpdate(groupId, oldData, newData)',
      ),
    );
    expect(rules, contains('newData.memberCount == oldData.memberCount + 1'));
    expect(rules, contains('newData.memberCount <= 50'));
    expect(
      rules,
      contains('getAfter(memberPath).data.joinSequence == newData.memberCount'),
    );
    expect(
      rules,
      contains(
        'function validGroupJoinCommandUpdate(groupId, oldData, newData)',
      ),
    );
    expect(rules, contains(') || validGroupJoinCommandUpdate('));
  });

  test('요청 Projection은 원본 join relation과 같은 sourceRevision을 요구한다', () {
    expect(
      rules,
      contains('function validGroupRequestRelation(playerId, groupId, data)'),
    );
    expect(rules, contains('data.sourceRevision == relation.revision'));
    expect(rules, contains('data.requestStatus == relation.status'));
    expect(rules, contains('data.expiresAt == relation.expiresAt'));
    expect(rules, contains('relation.targetPlayerId == playerId'));
    expect(
      rules,
      contains('function validAcceptedGroupRelation(playerId, groupId, data)'),
    );
    expect(rules, contains("data.requestStatus == 'accepted'"));
    expect(rules, contains('data.sourceRevision == member.revision'));
  });

  test('요청 원본은 당사자와 그룹원만 읽고 삭제를 막는다', () {
    expect(rules, contains('match /joinRelations/{playerId}'));
    expect(rules, contains('match /applicantStats/{playerId}'));
    expect(
      rules,
      contains(
        '&& (playerId == currentPlayerId() || isCurrentGroupMember(groupId));',
      ),
    );
    expect(rules, contains('allow list: if isCurrentGroupMember(groupId);'));
    expect(rules, contains('allow list: if isCurrentGroupLeader(groupId);'));
  });

  test('Player 하위 그룹 Projection은 본인만 읽고 탈퇴 시에만 삭제한다', () {
    expect(rules, contains('match /groupMembershipState/{docId}'));
    expect(rules, contains('match /groupRelations/{groupId}'));
    expect(
      rules,
      contains('allow create, update: if validInitialMemberGroupRelation('),
    );
    expect(
      rules,
      contains('validGroupMemberLeaveRelationDelete(playerId, groupId)'),
    );
  });

  test('그룹장 판정 helper는 binding·Player·그룹을 한 번씩만 읽는다', () {
    expect(rules, contains('function isActiveGroupLeader(groupId)'));
    expect(rules, contains('let callerId = currentPlayerId();'));
    expect(
      rules,
      contains("get(groupPath(groupId)).data.leaderPlayerId == callerId"),
      reason: '그룹장 판정과 Player active 검사를 한 helper에 모아 중복 get을 줄인다.',
    );
  });

  test('신청 승인·거절·금지 전이는 그룹장만 실행한다', () {
    expect(
      rules,
      contains(
        'function validGroupApplicationDecision(groupId, playerId, oldData, newData)',
      ),
    );
    expect(rules, contains("oldData.kind == 'application'"));
    expect(rules, contains('oldData.targetPlayerId == playerId'));
    expect(rules, contains('playerId != currentPlayerId()'));
    expect(rules, contains("(newData.status == 'accepted'"));
    expect(rules, contains("|| newData.status == 'rejected'"));
    expect(rules, contains("|| (newData.status == 'blocked'"));
    expect(
      rules,
      contains('&& existsAfter(groupBlockPath(groupId, playerId)))'),
      reason: '금지 전이는 같은 Transaction의 block 생성과 함께만 성공한다.',
    );
    expect(
      rules,
      contains(') || validGroupApplicationDecision('),
      reason: 'joinRelations update는 초대 전이와 신청 전이만 허용한다.',
    );
  });

  test('승인 membership은 application 경로와 정원·요약 반영을 강제한다', () {
    expect(
      rules,
      contains('function validApprovedGroupMember(groupId, playerId, data)'),
    );
    expect(rules, contains("data.joinedBy == 'application'"));
    expect(rules, contains('data.joinSequence == group.memberCount'));
    expect(rules, contains('group.memberCount <= 50'));
    expect(rules, contains("relation.status == 'accepted'"));
    expect(rules, contains('groupId in state.activeGroupIds'));
    expect(
      rules,
      contains(') || validApprovedGroupMember('),
      reason: 'members create는 생성·초대 수락·그룹장 승인 경로만 허용한다.',
    );
  });

  test('그룹장 승인의 대상 요약 병합은 Group ID 1개 추가와 50개 한도를 지킨다', () {
    expect(rules, contains('function validLeaderApprovedMembershipStateAdd('));
    expect(rules, contains("member.joinedBy == 'application'"));
    expect(
      rules,
      contains(
        'getAfter(groupPath(addedGroupId)).data.leaderPlayerId == callerId',
      ),
    );
    expect(rules, contains(') || validLeaderApprovedMembershipStateAdd('));
  });

  test('승인 이후 대상 Projection과 그룹 인원 증가는 그룹장에게만 열린다', () {
    expect(
      rules,
      contains(
        'function validLeaderApprovedGroupRelation(playerId, groupId, data)',
      ),
    );
    expect(rules, contains('data.createdAt is timestamp'));
    expect(
      rules,
      contains('function validGroupLeaderApproveUpdate(oldData, newData)'),
    );
    expect(rules, contains('oldData.leaderPlayerId == currentPlayerId()'));
    expect(rules, contains('newData.memberCount == oldData.memberCount + 1'));
    expect(rules, contains(') || validGroupLeaderApproveUpdate('));
    expect(rules, contains(') || validGroupMemberLeaveUpdate('));
  });

  test('금지 문서는 그룹장만 읽고 만들고 지우며 수정할 수 없다', () {
    final blocked = rules.substring(
      rules.indexOf('match /blockedPlayers/{playerId}'),
    );
    expect(
      rules,
      contains('function validGroupBlockCreate(groupId, playerId, data)'),
    );
    expect(rules, contains("data.blockedByPlayerId == currentPlayerId()"));
    expect(
      rules,
      contains('== (stats == null ? 0 : stats.data.applicationCount)'),
    );
    expect(rules, contains("(data.reason == 'applicationRejected'"));
    expect(rules, contains("&& relation.status == 'blocked')"));
    expect(
      rules,
      contains(
        "&& relation.status in ['rejected', 'cancelled', 'expired', 'blocked']",
      ),
      reason: '계약 §10은 block 생성을 blocked 전이 또는 끝난 신청에만 묶는다.',
    );
    expect(
      blocked,
      contains('allow get, list: if isCurrentGroupLeader(groupId);'),
    );
    expect(blocked, contains('allow create: if validGroupBlockCreate('));
    expect(blocked, contains('allow update: if false;'));
    expect(blocked, contains('allow delete: if isActiveGroupLeader(groupId);'));
  });

  test('탈퇴 대상은 native list 차집합으로 찾고 빈 결과 접근을 막는다', () {
    expect(rules, contains('let removedIds = previousIds.removeAll(newIds);'));
    expect(
      rules,
      contains("return removedIds.size() == 1 ? removedIds[0] : '';"),
    );
    expect(rules, isNot(contains('removedActiveGroupIdChunk')));
  });

  test('표시 갱신은 필수 필드를 유지하고 네 필드 외 변경을 차단한다', () {
    final start = rules.indexOf(
      '    function validGroupMemberSelfSnapshotRefresh(',
    );
    final end = rules.indexOf('    function reusableGroupJoinRelation(', start);
    final refresh = rules.substring(start, end);
    expect(refresh, contains('oldData.keys().hasAll(['));
    for (final field in [
      'schemaVersion',
      'groupId',
      'playerId',
      'role',
      'joinedAt',
      'joinSequence',
      'joinedBy',
      'displayCharacterIdSnapshot',
      'displayCharacterNameSnapshot',
      'revision',
      'createdAt',
    ]) {
      expect(refresh, contains("'$field'"));
    }
    expect(refresh, contains('newData.diff(oldData).affectedKeys().hasOnly(['));
    expect(refresh, contains('playerId == currentPlayerId()'));
    expect(refresh, contains('oldData.groupId == groupId'));
    expect(refresh, contains('validGroupMemberOptionalNumberFields(newData)'));
    expect(refresh, isNot(contains('newData.role == oldData.role')));
  });

  test('과거 membership의 선택 Snapshot 필드 누락을 허용한다', () {
    final start = rules.indexOf(
      '    function validGroupMemberOptionalNumberFields(data)',
    );
    final end = rules.indexOf(
      '    function validGroupMemberSnapshotsFromRelation',
      start,
    );
    final optionalFields = rules.substring(start, end);
    for (final field in [
      'itemLevelSnapshot',
      'combatPowerSnapshot',
      'gemValidationSnapshot',
    ]) {
      expect(optionalFields, contains("!('$field' in data)"));
    }
  });

  test('일반 멤버 탈퇴 Rules helper와 삭제 경로를 고정한다', () {
    expect(
      rules,
      contains(
        'function validGroupMemberSelfLeaveDelete(groupId, playerId, data)',
      ),
    );
    expect(
      rules,
      contains(
        'function validGroupMemberLeaveUpdate(groupId, oldData, newData)',
      ),
    );
    expect(
      rules,
      contains(
        'function validMembershipStateRemove(playerId, docId, oldData, newData)',
      ),
    );
    expect(
      rules,
      contains(
        'function validGroupMemberLeaveRelationDelete(playerId, groupId)',
      ),
    );
    expect(
      rules,
      contains('allow delete: if validGroupMemberSelfLeaveDelete('),
    );
    expect(
      rules,
      contains('validGroupMemberLeaveRelationDelete(playerId, groupId)'),
    );
    expect(
      rules,
      contains('validGroupDisbandRelationDelete(playerId, groupId)'),
    );
    expect(rules, contains(') || validGroupMemberLeaveUpdate('));
    expect(rules, contains('function validGroupLeaderTransferUpdate('));
    expect(rules, contains('function validGroupMemberRoleTransferUpdate('));
    expect(rules, contains('function validGroupDisbandUpdate('));
    expect(rules, contains('function validGroupMemberDisbandDelete('));
    final disbandStart = rules.indexOf('function validGroupDisbandUpdate(');
    final disbandEnd = rules.indexOf(
      'function validGroupMemberDisbandDelete(',
      disbandStart,
    );
    final disbandRule = rules.substring(disbandStart, disbandEnd);
    expect(disbandRule, contains('oldData.activeRecruitmentCount is int'));
    expect(disbandRule, contains('oldData.activeRecruitmentCount == 0'));
    final groupUpdateStart = rules.indexOf(
      'allow update: if validGroupDisbandUpdate(',
    );
    expect(groupUpdateStart, greaterThanOrEqualTo(0));
    expect(
      groupUpdateStart,
      lessThan(rules.indexOf(') || validGroupJoinCodeFlagUpdate(')),
    );
    expect(
      groupUpdateStart,
      lessThan(rules.indexOf(') || validGroupJoinCommandUpdate(')),
    );
    final transferUpdateStart = rules.indexOf(
      ') || validGroupLeaderTransferUpdate(',
      groupUpdateStart,
    );
    expect(transferUpdateStart, greaterThan(groupUpdateStart));
    expect(
      transferUpdateStart,
      lessThan(rules.indexOf(') || validAtomicGroupRecruitmentClose(')),
    );
    final groupMemberUpdateStart = rules.indexOf(
      'allow update: if validGroupMemberRoleTransferUpdate(',
    );
    expect(groupMemberUpdateStart, greaterThanOrEqualTo(0));
    expect(
      groupMemberUpdateStart,
      lessThan(rules.indexOf(') || validGroupMemberSelfSnapshotRefresh(')),
    );
    expect(rules, contains('allow update: if validMembershipStateRemove('));
    expect(rules, contains('function validGroupMemberDocumentKeys(data)'));
    expect(rules, contains('displayClassNameSnapshot'));
    expect(rules, contains("'gemValidationSnapshot'"));
    expect(rules, contains('function validGroupMemberSnapshotsFromRelation'));
    expect(rules, contains('function validGroupMemberSelfSnapshotRefresh('));
    expect(rules, contains("'combatPowerSnapshot'"));
    expect(
      rules,
      contains(') || validGroupMemberSelfSnapshotRefresh('),
    );
  });

  test('그룹 쿼리에 필요한 복합 인덱스를 고정한다', () {
    final entries = (indexes['indexes'] as List)
        .cast<Map<String, Object?>>()
        .where(
          (index) => const [
            'groups',
            'groupRelations',
            'joinRelations',
            'characters',
          ].contains(index['collectionGroup']),
        )
        .map(
          (index) => [
            index['collectionGroup'],
            index['queryScope'],
            for (final field in (index['fields'] as List).cast<Map>())
              '${field['fieldPath']}:${field['order']}',
          ].join('|'),
        )
        .toList(growable: false);

    expect(
      entries,
      contains(
        'groups|COLLECTION|status:ASCENDING|normalizedName:ASCENDING'
        '|__name__:ASCENDING',
      ),
    );
    expect(
      entries,
      contains(
        'groups|COLLECTION|status:ASCENDING'
        '|normalizedRepresentativeCharacterName:ASCENDING|__name__:ASCENDING',
      ),
    );
    expect(
      entries,
      contains(
        'groups|COLLECTION|status:ASCENDING|lastActivityAt:DESCENDING'
        '|__name__:DESCENDING',
      ),
    );
    expect(
      entries,
      contains(
        'groupRelations|COLLECTION|relation:ASCENDING|updatedAt:DESCENDING',
      ),
    );
    expect(
      entries,
      contains(
        'joinRelations|COLLECTION|kind:ASCENDING|status:ASCENDING'
        '|createdAt:ASCENDING',
      ),
    );
    expect(
      entries,
      contains(
        'characters|COLLECTION|status:ASCENDING|characterName:ASCENDING'
        '|__name__:ASCENDING',
      ),
      reason: '초대 대상 정확한 캐릭터명 검색은 상태·이름 조합 인덱스를 고정한다.',
    );
    expect(
      entries,
      contains(
        'characters|COLLECTION|status:ASCENDING|ownerPlayerId:ASCENDING'
        '|__name__:ASCENDING',
      ),
      reason: '그룹원 카드 터치 시 Player별 active 캐릭터 조회 인덱스를 고정한다.',
    );
  });
}
