import '../../domain/entities/group_blocked_player.dart';
import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_relation.dart';
import 'group_member_write_fields.dart';

/// 계약 §8.6 그룹장 신청 처리(승인·거절·금지·해제)의 쓰기 계획.
///
/// 그룹장은 대상 Player의 `groupMembershipState`와 `groupRelations`를 읽을 수
/// 없다. 요약은 `activeGroupIds` 배열 합집합과 증가 연산으로 병합해 쓰고,
/// Projection은 `createdAt`을 병합으로 보존한다. 두 문서 모두 Rules가 결과
/// 문서에서 Group ID 1개 추가, 50개 한도와 원본 결합을 최종 판정한다.
class GroupApplicationWritePlan {
  const GroupApplicationWritePlan({
    required this.groupPatch,
    this.joinRelationPatch,
    this.playerRelationPatch,
    this.member,
    this.membershipStatePatch,
    this.blockDocument,
  });

  /// 승인. 초대 수락과 같은 membership 원자 쓰기를 그룹장이 실행한다.
  ///
  /// Player별 50개 한도는 대상 요약을 읽지 못해 여기서 계산하지 않는다.
  /// 병합 결과에서 Rules가 강제하고 클라이언트는 거절을 안내로 바꾼다.
  factory GroupApplicationWritePlan.approved({
    required GroupJoinRelation relation,
    required String groupName,
    required int groupRevision,
    required int groupMemberCount,
    required Object serverTimestamp,
    required Object addedGroupIdUnion,
    required Object incrementByOne,
    required DateTime now,
  }) {
    _requireApplication(relation);
    if (!relation.isPendingAt(now)) {
      throw StateError('Only a valid pending application can be approved.');
    }
    if (groupMemberCount >= GroupMember.maxMemberCount) {
      throw StateError('Group member limit reached.');
    }
    final groupId = relation.groupId;
    final playerId = relation.targetPlayerId;
    return GroupApplicationWritePlan(
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
        'joinedBy': GroupJoinedBy.application.name,
        'displayCharacterIdSnapshot': relation.characterIdSnapshot,
        'displayCharacterNameSnapshot': relation.characterNameSnapshot,
        ...GroupMemberWriteFields.fromJoinRelation(relation),
        'revision': 1,
        'createdAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
      membershipStatePatch: {
        'schemaVersion': 1,
        'playerId': playerId,
        'activeGroupIds': addedGroupIdUnion,
        'activeGroupCount': incrementByOne,
        'revision': incrementByOne,
        'updatedAt': serverTimestamp,
      },
      playerRelationPatch: {
        'schemaVersion': 1,
        'groupId': groupId,
        'playerId': playerId,
        'relation': GroupRelationKind.member.name,
        'requestStatus': GroupRequestStatus.accepted.name,
        'groupNameSnapshot': groupName,
        'displayCharacterNameSnapshot': relation.characterNameSnapshot,
        'expiresAt': null,
        'sourceRevision': 1,
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

  /// 거절. membership을 만들지 않고 누적 신청 횟수도 그대로 둔다.
  factory GroupApplicationWritePlan.rejected({
    required GroupJoinRelation relation,
    required String groupName,
    required int groupRevision,
    required Object serverTimestamp,
  }) {
    _requireApplication(relation);
    final revision = relation.revision + 1;
    return GroupApplicationWritePlan(
      joinRelationPatch: _decisionPatch(
        status: GroupRequestStatus.rejected,
        revision: revision,
        serverTimestamp: serverTimestamp,
      ),
      playerRelationPatch: _requestRelationPatch(
        relation: relation,
        status: GroupRequestStatus.rejected,
        groupName: groupName,
        sourceRevision: revision,
        serverTimestamp: serverTimestamp,
      ),
      groupPatch: _activityPatch(
        groupRevision: groupRevision,
        serverTimestamp: serverTimestamp,
      ),
    );
  }

  /// 거절과 금지를 한 번에 실행한다. pending 신청은 `blocked`로 전이하고,
  /// 이미 끝난 신청은 relation을 그대로 둔 채 block 문서만 만든다.
  factory GroupApplicationWritePlan.blocked({
    required GroupJoinRelation relation,
    required String groupName,
    required int groupRevision,
    required String blockedByPlayerId,
    required int applicationCount,
    required Object serverTimestamp,
    required DateTime now,
  }) {
    _requireApplication(relation);
    if (blockedByPlayerId == relation.targetPlayerId) {
      throw ArgumentError.value(blockedByPlayerId, 'blockedByPlayerId');
    }
    final pending = relation.isPendingAt(now);
    if (!pending && !_blockableFinalStatuses.contains(relation.status)) {
      // 만료된 pending 신청은 먼저 거절한 뒤 금지한다. 이미 수락된 신청은
      // 멤버 추방이 없는 Task-11 범위에서 금지 대상이 아니다.
      throw StateError('This application cannot be blocked in its state.');
    }
    final revision = relation.revision + 1;
    return GroupApplicationWritePlan(
      joinRelationPatch: pending
          ? _decisionPatch(
              status: GroupRequestStatus.blocked,
              revision: revision,
              serverTimestamp: serverTimestamp,
            )
          : null,
      playerRelationPatch: pending
          ? _requestRelationPatch(
              relation: relation,
              status: GroupRequestStatus.blocked,
              groupName: groupName,
              sourceRevision: revision,
              serverTimestamp: serverTimestamp,
            )
          : null,
      blockDocument: {
        'schemaVersion': 1,
        'groupId': relation.groupId,
        'playerId': relation.targetPlayerId,
        'blockedByPlayerId': blockedByPlayerId,
        'reason': (pending
                ? GroupBlockReason.applicationRejected
                : GroupBlockReason.manual)
            .name,
        'characterNameSnapshot': relation.characterNameSnapshot,
        'applicationCountSnapshot': applicationCount,
        'itemLevelSnapshot': relation.itemLevelSnapshot,
        'combatPowerSnapshot': relation.combatPowerSnapshot,
        'createdAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
      groupPatch: _activityPatch(
        groupRevision: groupRevision,
        serverTimestamp: serverTimestamp,
      ),
    );
  }

  /// 금지 해제. block 문서 삭제와 그룹 활동 시각만 남기고 relation은 그대로 둔다.
  factory GroupApplicationWritePlan.blockReleased({
    required int groupRevision,
    required Object serverTimestamp,
  }) => GroupApplicationWritePlan(
    groupPatch: _activityPatch(
      groupRevision: groupRevision,
      serverTimestamp: serverTimestamp,
    ),
  );

  final Map<String, Object?> groupPatch;
  final Map<String, Object?>? joinRelationPatch;
  final Map<String, Object?>? playerRelationPatch;
  final Map<String, Object?>? member;
  final Map<String, Object?>? membershipStatePatch;
  final Map<String, Object?>? blockDocument;

  /// 계약 §10. block 생성은 blocked 전이 또는 이미 끝난 신청에만 묶인다.
  static const _blockableFinalStatuses = {
    GroupRequestStatus.rejected,
    GroupRequestStatus.cancelled,
    GroupRequestStatus.expired,
    GroupRequestStatus.blocked,
  };

  static void _requireApplication(GroupJoinRelation relation) {
    if (relation.kind != GroupJoinRelationKind.application) {
      throw ArgumentError.value(relation.kind, 'relation.kind');
    }
  }

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

  /// 대상 Projection은 병합으로 갱신하므로 `createdAt`을 담지 않는다.
  static Map<String, Object?> _requestRelationPatch({
    required GroupJoinRelation relation,
    required GroupRequestStatus status,
    required String groupName,
    required int sourceRevision,
    required Object serverTimestamp,
  }) => {
    'schemaVersion': 1,
    'groupId': relation.groupId,
    'playerId': relation.targetPlayerId,
    'relation': GroupRelationKind.applied.name,
    'requestStatus': status.name,
    'groupNameSnapshot': groupName,
    'displayCharacterNameSnapshot': relation.characterNameSnapshot,
    'expiresAt': relation.expiresAt,
    'sourceRevision': sourceRevision,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> _activityPatch({
    required int groupRevision,
    required Object serverTimestamp,
  }) => {
    'revision': groupRevision + 1,
    'lastActivityAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };
}
