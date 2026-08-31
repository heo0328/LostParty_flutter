import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_request_character.dart';

import 'group_member_write_fields.dart';

/// 계약 §8.3~8.5 초대·신청 명령의 쓰기 계획.
///
/// 요청 원본([joinRelationDocument] 또는 [joinRelationPatch]), 대상 Player의
/// 역방향 Projection([playerRelation])과 그룹 활동 시각([groupPatch])은 항상 같은
/// Transaction에서 함께 쓴다. 초대 수락만 추가로 membership 세 문서를 만든다.
class GroupJoinWritePlan {
  const GroupJoinWritePlan({
    required this.playerRelation,
    required this.groupPatch,
    this.joinRelationDocument,
    this.joinRelationPatch,
    this.applicantStats,
    this.member,
    this.membershipState,
  });

  /// pending 초대를 만들거나 만료·최종 relation을 재사용한다.
  factory GroupJoinWritePlan.invitation({
    required String groupId,
    required String requestedByPlayerId,
    required GroupRequestCharacter character,
    required String groupName,
    required int groupRevision,
    required GroupJoinRelation? existingRelation,
    required Object serverTimestamp,
    required DateTime now,
  }) {
    _requireDocumentId(groupId, 'groupId');
    _requireDocumentId(requestedByPlayerId, 'requestedByPlayerId');
    _requireDocumentId(character.ownerPlayerId, 'ownerPlayerId');
    if (character.ownerPlayerId == requestedByPlayerId) {
      throw ArgumentError.value(
        character.ownerPlayerId,
        'ownerPlayerId',
        'Cannot invite yourself.',
      );
    }
    _requireReusable(existingRelation, now);
    final targetPlayerId = character.ownerPlayerId;
    final revision = (existingRelation?.revision ?? 0) + 1;
    final expiresAt = _expiresAt(now);
    return GroupJoinWritePlan(
      joinRelationDocument: _joinRelationDocument(
        groupId: groupId,
        targetPlayerId: targetPlayerId,
        kind: GroupJoinRelationKind.invitation,
        requestedByPlayerId: requestedByPlayerId,
        character: character,
        applicationAttempt: existingRelation?.applicationAttempt ?? 0,
        revision: revision,
        expiresAt: expiresAt,
        serverTimestamp: serverTimestamp,
      ),
      playerRelation: _requestRelation(
        groupId: groupId,
        playerId: targetPlayerId,
        relation: GroupRelationKind.invited,
        requestStatus: GroupRequestStatus.pending,
        groupName: groupName,
        characterName: character.characterName,
        expiresAt: expiresAt,
        sourceRevision: revision,
        createdAt: serverTimestamp,
        serverTimestamp: serverTimestamp,
      ),
      groupPatch: _groupPatch(
        groupRevision: groupRevision,
        serverTimestamp: serverTimestamp,
      ),
    );
  }

  /// pending 신청을 만들고 누적 신청 횟수를 정확히 1 증가시킨다.
  factory GroupJoinWritePlan.application({
    required String groupId,
    required GroupRequestCharacter character,
    required String groupName,
    required int groupRevision,
    required GroupJoinRelation? existingRelation,
    required GroupApplicantStats stats,
    required Object serverTimestamp,
    required DateTime now,
    Object? statsCreatedAt,
  }) {
    _requireDocumentId(groupId, 'groupId');
    _requireDocumentId(character.ownerPlayerId, 'ownerPlayerId');
    _requireReusable(existingRelation, now);
    final playerId = character.ownerPlayerId;
    final revision = (existingRelation?.revision ?? 0) + 1;
    final attempt = stats.nextApplicationAttempt;
    final expiresAt = _expiresAt(now);
    return GroupJoinWritePlan(
      joinRelationDocument: _joinRelationDocument(
        groupId: groupId,
        targetPlayerId: playerId,
        kind: GroupJoinRelationKind.application,
        requestedByPlayerId: playerId,
        character: character,
        applicationAttempt: attempt,
        revision: revision,
        expiresAt: expiresAt,
        serverTimestamp: serverTimestamp,
      ),
      playerRelation: _requestRelation(
        groupId: groupId,
        playerId: playerId,
        relation: GroupRelationKind.applied,
        requestStatus: GroupRequestStatus.pending,
        groupName: groupName,
        characterName: character.characterName,
        expiresAt: expiresAt,
        sourceRevision: revision,
        createdAt: serverTimestamp,
        serverTimestamp: serverTimestamp,
      ),
      applicantStats: {
        'schemaVersion': 1,
        'groupId': groupId,
        'playerId': playerId,
        'applicationCount': attempt,
        'lastCharacterNameSnapshot': character.characterName,
        'lastItemLevelSnapshot': character.itemLevel,
        'lastCombatPowerSnapshot': character.combatPower,
        'createdAt': statsCreatedAt ?? serverTimestamp,
        'updatedAt': serverTimestamp,
      },
      groupPatch: _groupPatch(
        groupRevision: groupRevision,
        serverTimestamp: serverTimestamp,
      ),
    );
  }

  /// 계약 §8.4 초대 수락. membership·요약·양방향 relation과 그룹 인원을 함께 쓴다.
  factory GroupJoinWritePlan.invitationAccepted({
    required GroupJoinRelation relation,
    required String groupName,
    required int groupRevision,
    required int groupMemberCount,
    required GroupMembershipState membershipState,
    required Object serverTimestamp,
    Object? playerRelationCreatedAt,
  }) {
    if (relation.kind != GroupJoinRelationKind.invitation) {
      throw ArgumentError.value(relation.kind, 'relation.kind');
    }
    final groupId = relation.groupId;
    final playerId = relation.targetPlayerId;
    _requireDocumentId(groupId, 'groupId');
    _requireDocumentId(playerId, 'targetPlayerId');
    if (membershipState.contains(groupId)) {
      throw ArgumentError.value(groupId, 'groupId', 'Already joined.');
    }
    if (membershipState.isAtLimit) {
      throw StateError('Active group limit reached.');
    }
    if (groupMemberCount >= GroupMember.maxMemberCount) {
      throw StateError('Group member limit reached.');
    }
    final activeGroupIds = [...membershipState.activeGroupIds, groupId];
    return GroupJoinWritePlan(
      joinRelationPatch: _decisionPatch(
        status: GroupRequestStatus.accepted,
        revision: relation.revision + 1,
        serverTimestamp: serverTimestamp,
      ),
      member: {
        'schemaVersion': 1,
        'groupId': groupId,
        'playerId': playerId,
        'role': GroupMemberRole.member.name,
        'joinedAt': serverTimestamp,
        'joinSequence': groupMemberCount + 1,
        'joinedBy': GroupJoinedBy.invitation.name,
        'displayCharacterIdSnapshot': relation.characterIdSnapshot,
        'displayCharacterNameSnapshot': relation.characterNameSnapshot,
        ...GroupMemberWriteFields.fromJoinRelation(relation),
        'revision': 1,
        'createdAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
      membershipState: {
        'schemaVersion': 1,
        'playerId': playerId,
        'activeGroupIds': activeGroupIds,
        'activeGroupCount': activeGroupIds.length,
        'revision': membershipState.revision + 1,
        'updatedAt': serverTimestamp,
      },
      playerRelation: {
        'schemaVersion': 1,
        'groupId': groupId,
        'playerId': playerId,
        'relation': GroupRelationKind.member.name,
        'requestStatus': GroupRequestStatus.accepted.name,
        'groupNameSnapshot': groupName,
        'displayCharacterNameSnapshot': relation.characterNameSnapshot,
        'expiresAt': null,
        'sourceRevision': 1,
        'createdAt': playerRelationCreatedAt ?? serverTimestamp,
        'updatedAt': serverTimestamp,
      },
      groupPatch: {
        'memberCount': groupMemberCount + 1,
        'revision': groupRevision + 1,
        'lastActivityAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
    );
  }

  /// 계약 §8.4 거절·취소. membership을 만들지 않고 요청만 최종 상태로 바꾼다.
  factory GroupJoinWritePlan.decision({
    required GroupJoinRelation relation,
    required GroupRequestStatus status,
    required String groupName,
    required int groupRevision,
    required Object serverTimestamp,
    Object? playerRelationCreatedAt,
  }) {
    if (status != GroupRequestStatus.rejected &&
        status != GroupRequestStatus.cancelled) {
      throw ArgumentError.value(status, 'status');
    }
    final revision = relation.revision + 1;
    return GroupJoinWritePlan(
      joinRelationPatch: _decisionPatch(
        status: status,
        revision: revision,
        serverTimestamp: serverTimestamp,
      ),
      playerRelation: _requestRelation(
        groupId: relation.groupId,
        playerId: relation.targetPlayerId,
        relation: relation.projectedRelation,
        requestStatus: status,
        groupName: groupName,
        characterName: relation.characterNameSnapshot,
        expiresAt: relation.expiresAt,
        sourceRevision: revision,
        createdAt: playerRelationCreatedAt ?? serverTimestamp,
        serverTimestamp: serverTimestamp,
      ),
      groupPatch: _groupPatch(
        groupRevision: groupRevision,
        serverTimestamp: serverTimestamp,
      ),
    );
  }

  final Map<String, Object?>? joinRelationDocument;
  final Map<String, Object?>? joinRelationPatch;
  final Map<String, Object?> playerRelation;
  final Map<String, Object?> groupPatch;
  final Map<String, Object?>? applicantStats;
  final Map<String, Object?>? member;
  final Map<String, Object?>? membershipState;

  static DateTime _expiresAt(DateTime now) =>
      now.toUtc().add(GroupJoinRelation.requestLifetime);

  static Map<String, Object?> _joinRelationDocument({
    required String groupId,
    required String targetPlayerId,
    required GroupJoinRelationKind kind,
    required String requestedByPlayerId,
    required GroupRequestCharacter character,
    required int applicationAttempt,
    required int revision,
    required DateTime expiresAt,
    required Object serverTimestamp,
  }) => {
    'schemaVersion': 1,
    'groupId': groupId,
    'targetPlayerId': targetPlayerId,
    'kind': kind.name,
    'status': GroupRequestStatus.pending.name,
    'requestedByPlayerId': requestedByPlayerId,
    'characterIdSnapshot': character.characterId,
    'characterNameSnapshot': character.characterName,
    'serverNameSnapshot': character.serverName,
    'characterClassNameSnapshot': character.characterClassName,
    'itemLevelSnapshot': character.itemLevel,
    'combatPowerSnapshot': character.combatPower,
    'applicationAttempt': applicationAttempt,
    'revision': revision,
    'createdAt': serverTimestamp,
    'expiresAt': expiresAt,
    'decidedAt': null,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> _requestRelation({
    required String groupId,
    required String playerId,
    required GroupRelationKind relation,
    required GroupRequestStatus requestStatus,
    required String groupName,
    required String characterName,
    required DateTime expiresAt,
    required int sourceRevision,
    required Object createdAt,
    required Object serverTimestamp,
  }) => {
    'schemaVersion': 1,
    'groupId': groupId,
    'playerId': playerId,
    'relation': relation.name,
    'requestStatus': requestStatus.name,
    'groupNameSnapshot': groupName,
    'displayCharacterNameSnapshot': characterName,
    'expiresAt': expiresAt,
    'sourceRevision': sourceRevision,
    'createdAt': createdAt,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> _decisionPatch({
    required GroupRequestStatus status,
    required int revision,
    required Object serverTimestamp,
  }) => {
    'status': status.name,
    'revision': revision,
    'decidedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> _groupPatch({
    required int groupRevision,
    required Object serverTimestamp,
  }) => {
    'revision': groupRevision + 1,
    'lastActivityAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  static void _requireDocumentId(String value, String name) {
    if (value.trim().isEmpty || value.contains('/')) {
      throw ArgumentError.value(value, name);
    }
  }

  /// 유효 pending relation은 종류가 달라도 새 요청으로 덮어쓰지 않는다.
  static void _requireReusable(GroupJoinRelation? relation, DateTime now) {
    if (relation != null && relation.isPendingAt(now)) {
      throw StateError('A valid pending join relation already exists.');
    }
  }
}
