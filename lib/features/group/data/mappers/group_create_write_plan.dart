import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

import '../../domain/entities/group_create_command.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/services/group_name_normalizer.dart';
import 'group_member_write_fields.dart';

/// 계약 §8.1 그룹 생성 Transaction의 쓰기 계획. 네 문서를 한 Transaction에서만 만든다.
class GroupCreateWritePlan {
  const GroupCreateWritePlan({
    required this.groupId,
    required this.group,
    required this.leaderMember,
    required this.membershipState,
    required this.memberRelation,
  });

  factory GroupCreateWritePlan.fromCommand({
    required GroupCreateCommand command,
    required String groupId,
    required String playerId,
    required Object serverTimestamp,
    required String verifiedCharacterName,
    required String verifiedServerName,
    required String verifiedClassName,
    double? verifiedItemLevel,
    double? verifiedCombatPower,
    PartyGemValidationSnapshot? verifiedGemValidation,
    required GroupMembershipState membershipState,
    GroupNameNormalizer normalizer = const GroupNameNormalizer(),
  }) {
    if (groupId.trim().isEmpty || groupId.contains('/')) {
      throw ArgumentError.value(groupId, 'groupId');
    }
    if (playerId.trim().isEmpty) {
      throw ArgumentError.value(playerId, 'playerId');
    }
    if (membershipState.contains(groupId)) {
      throw ArgumentError.value(groupId, 'groupId', 'Already joined.');
    }
    if (membershipState.isAtLimit) {
      throw StateError('Active group limit reached.');
    }
    final characterName = normalizer.displayName(verifiedCharacterName);
    final rawName = command.usesDefaultName
        ? normalizer.defaultName(characterName)
        : normalizer.displayName(command.name!);
    // 기본 이름도 앱의 그룹명 입력 정책인 20자 상한에 맞춘다.
    final name = rawName.length <= GroupCreateCommand.maxNameLength
        ? rawName
        : rawName.substring(0, GroupCreateCommand.maxNameLength);
    final activeGroupIds = [...membershipState.activeGroupIds, groupId];
    return GroupCreateWritePlan(
      groupId: groupId,
      group: {
        'schemaVersion': 1,
        'status': 'active',
        'name': name,
        'normalizedName': normalizer.normalize(name),
        'representativeCharacterId': command.representativeCharacterId,
        'representativeCharacterNameSnapshot': characterName,
        'normalizedRepresentativeCharacterName': normalizer.normalize(
          characterName,
        ),
        'representativeServerNameSnapshot': normalizer.displayName(
          verifiedServerName,
        ),
        'leaderPlayerId': playerId,
        'leaderDisplayCharacterNameSnapshot': characterName,
        'memberCount': 1,
        'activeRecruitmentCount': 0,
        'revision': 1,
        'hasActiveJoinCode': false,
        'joinCodeVisibleToMembers': false,
        'lastActivityAt': serverTimestamp,
        'createdAt': serverTimestamp,
        'updatedAt': serverTimestamp,
        'deletedAt': null,
      },
      leaderMember: {
        'schemaVersion': 1,
        'groupId': groupId,
        'playerId': playerId,
        'role': GroupMemberRole.leader.name,
        'joinedAt': serverTimestamp,
        'joinSequence': 1,
        'joinedBy': GroupJoinedBy.created.name,
        'displayCharacterIdSnapshot': command.representativeCharacterId,
        'displayCharacterNameSnapshot': characterName,
        ...GroupMemberWriteFields.displaySnapshots(
          className: verifiedClassName,
          itemLevel: verifiedItemLevel,
          combatPower: verifiedCombatPower,
          gemValidation: verifiedGemValidation,
        ),
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
      memberRelation: {
        'schemaVersion': 1,
        'groupId': groupId,
        'playerId': playerId,
        'relation': 'member',
        'requestStatus': null,
        'groupNameSnapshot': name,
        'displayCharacterNameSnapshot': characterName,
        'expiresAt': null,
        'sourceRevision': 1,
        'createdAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      },
    );
  }

  static const membershipStateDocumentId = 'current';

  final String groupId;
  final Map<String, Object?> group;
  final Map<String, Object?> leaderMember;
  final Map<String, Object?> membershipState;
  final Map<String, Object?> memberRelation;
}
