import '../../domain/entities/group_join_code.dart';
import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_request_character.dart';
import 'group_member_write_fields.dart';

/// 계약 §7·§8.7 초대코드 명령의 쓰기 계획.
///
/// 생성과 폐기는 같은 Transaction에 넣지 않는다. 가입은 초대 수락과 같은
/// membership 원자 쓰기를 쓰되 `joinedBy == joinCode`이며, 기존 pending
/// relation이 있으면 accepted로만 바꾸고 applicantStats는 건드리지 않는다.
class GroupJoinCodeWritePlan {
  const GroupJoinCodeWritePlan({
    required this.groupPatch,
    this.joinCodeDocument,
    this.joinRelationPatch,
    this.playerRelation,
    this.member,
    this.membershipState,
  });

  /// 계약 §7. 코드 문서 생성과 `hasActiveJoinCode` false→true.
  factory GroupJoinCodeWritePlan.created({
    required String groupId,
    required GroupJoinCode code,
    required String createdByPlayerId,
    required int groupRevision,
    required Object serverTimestamp,
  }) {
    _requireDocumentId(groupId, 'groupId');
    _requireDocumentId(createdByPlayerId, 'createdByPlayerId');
    return GroupJoinCodeWritePlan(
      joinCodeDocument: {
        'schemaVersion': 1,
        'groupId': groupId,
        'status': 'active',
        'createdByPlayerId': createdByPlayerId,
        'createdAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
      groupPatch: {
        'hasActiveJoinCode': true,
        'activeJoinCode': code.value,
        'revision': groupRevision + 1,
        'lastActivityAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
    );
  }

  /// 계약 §7. 코드 문서 삭제와 `hasActiveJoinCode` true→false.
  ///
  /// 삭제 대상 문서 ID는 호출 측이 [code]로 넘긴다. 이 계획은 그룹 패치만 담는다.
  factory GroupJoinCodeWritePlan.revoked({
    required int groupRevision,
    required Object serverTimestamp,
  }) => GroupJoinCodeWritePlan(
    groupPatch: {
      'hasActiveJoinCode': false,
      'activeJoinCode': null,
      'revision': groupRevision + 1,
      'lastActivityAt': serverTimestamp,
      'updatedAt': serverTimestamp,
    },
  );

  /// 계약 §7. `joinCodeVisibleToMembers`와 활동 시각만 바꾼다.
  factory GroupJoinCodeWritePlan.visibility({
    required bool visibleToMembers,
    required int groupRevision,
    required Object serverTimestamp,
  }) => GroupJoinCodeWritePlan(
    groupPatch: {
      'joinCodeVisibleToMembers': visibleToMembers,
      'revision': groupRevision + 1,
      'lastActivityAt': serverTimestamp,
      'updatedAt': serverTimestamp,
    },
  );

  /// 계약 §8.7. 코드 즉시 가입. Character Snapshot은 선택한 인증 Character에서 온다.
  factory GroupJoinCodeWritePlan.joined({
    required String groupId,
    required String playerId,
    required GroupRequestCharacter character,
    required String groupName,
    required int groupRevision,
    required int groupMemberCount,
    required GroupMembershipState membershipState,
    required GroupJoinRelation? existingRelation,
    required Object serverTimestamp,
    required DateTime now,
    Object? playerRelationCreatedAt,
  }) {
    _requireDocumentId(groupId, 'groupId');
    _requireDocumentId(playerId, 'playerId');
    if (character.ownerPlayerId != playerId) {
      throw ArgumentError.value(
        character.ownerPlayerId,
        'ownerPlayerId',
        'Character must belong to the joining player.',
      );
    }
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
    final pending =
        existingRelation != null && existingRelation.isPendingAt(now);

    return GroupJoinCodeWritePlan(
      joinRelationPatch: pending
          ? {
              'status': GroupRequestStatus.accepted.name,
              'revision': existingRelation.revision + 1,
              'decidedAt': serverTimestamp,
              'updatedAt': serverTimestamp,
            }
          : null,
      member: {
        'schemaVersion': 1,
        'groupId': groupId,
        'playerId': playerId,
        'role': GroupMemberRole.member.name,
        'joinedAt': serverTimestamp,
        'joinSequence': groupMemberCount + 1,
        'joinedBy': GroupJoinedBy.joinCode.name,
        'displayCharacterIdSnapshot': character.characterId,
        'displayCharacterNameSnapshot': character.characterName,
        ...GroupMemberWriteFields.fromCharacter(character),
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
        'requestStatus': pending ? GroupRequestStatus.accepted.name : null,
        'groupNameSnapshot': groupName,
        'displayCharacterNameSnapshot': character.characterName,
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

  final Map<String, Object?> groupPatch;
  final Map<String, Object?>? joinCodeDocument;
  final Map<String, Object?>? joinRelationPatch;
  final Map<String, Object?>? playerRelation;
  final Map<String, Object?>? member;
  final Map<String, Object?>? membershipState;

  static void _requireDocumentId(String value, String name) {
    if (value.trim().isEmpty || value.contains('/')) {
      throw ArgumentError.value(value, name);
    }
  }
}
