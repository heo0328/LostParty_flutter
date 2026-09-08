import '../../domain/entities/group_blocked_player.dart';
import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_relation.dart';
import '../../domain/entities/group_summary.dart';

class GroupDocumentDto {
  const GroupDocumentDto({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;
}

class GroupContractException implements Exception {
  const GroupContractException(this.message);

  final String message;

  @override
  String toString() => 'GroupContractException: $message';
}

class GroupDocumentMapper {
  const GroupDocumentMapper({required this.toDateTime});

  final DateTime Function(Object? value) toDateTime;

  GroupPublicSummary toPublicSummary(GroupDocumentDto document) {
    final data = document.data;
    _requireSchema(data);
    return GroupPublicSummary(
      groupId: document.id,
      name: _string(data, 'name'),
      status: _status(data),
      representativeCharacterNameSnapshot: _string(
        data,
        'representativeCharacterNameSnapshot',
      ),
      representativeServerNameSnapshot: _string(
        data,
        'representativeServerNameSnapshot',
      ),
      leaderDisplayCharacterNameSnapshot: _string(
        data,
        'leaderDisplayCharacterNameSnapshot',
      ),
      memberCount: _integer(data, 'memberCount'),
      revision: _integer(data, 'revision'),
      hasActiveJoinCode: _boolean(data, 'hasActiveJoinCode'),
      joinCodeVisibleToMembers: _boolean(data, 'joinCodeVisibleToMembers'),
      activeJoinCode: _optionalString(data, 'activeJoinCode'),
      createdAt: _date(data, 'createdAt'),
      lastActivityAt: _date(data, 'lastActivityAt'),
    );
  }

  GroupMember toMember(GroupDocumentDto document) {
    final data = document.data;
    _requireSchema(data);
    return GroupMember(
      groupId: _string(data, 'groupId'),
      playerId: document.id,
      role: _enumValue(GroupMemberRole.values, _string(data, 'role'), 'role'),
      joinedAt: _date(data, 'joinedAt'),
      joinSequence: _integer(data, 'joinSequence'),
      joinedBy: _enumValue(
        GroupJoinedBy.values,
        _string(data, 'joinedBy'),
        'joinedBy',
      ),
      displayCharacterIdSnapshot: _string(data, 'displayCharacterIdSnapshot'),
      displayCharacterNameSnapshot: _string(
        data,
        'displayCharacterNameSnapshot',
      ),
      displayClassNameSnapshot: _optionalString(
        data,
        'displayClassNameSnapshot',
      ),
      itemLevelSnapshot: _nullableDouble(data, 'itemLevelSnapshot'),
      combatPowerSnapshot: _nullableDouble(data, 'combatPowerSnapshot'),
      revision: _integer(data, 'revision'),
    );
  }

  GroupRelation toRelation(GroupDocumentDto document) {
    final data = document.data;
    _requireSchema(data);
    final requestStatus = data['requestStatus'];
    return GroupRelation(
      groupId: document.id,
      playerId: _string(data, 'playerId'),
      relation: _enumValue(
        GroupRelationKind.values,
        _string(data, 'relation'),
        'relation',
      ),
      requestStatus: requestStatus == null
          ? null
          : _enumValue(
              GroupRequestStatus.values,
              _string(data, 'requestStatus'),
              'requestStatus',
            ),
      groupNameSnapshot: _string(data, 'groupNameSnapshot'),
      displayCharacterNameSnapshot: _string(
        data,
        'displayCharacterNameSnapshot',
      ),
      expiresAt: data['expiresAt'] == null ? null : _date(data, 'expiresAt'),
      sourceRevision: _integer(data, 'sourceRevision'),
      createdAt: _date(data, 'createdAt'),
      updatedAt: _date(data, 'updatedAt'),
    );
  }

  /// 계약 §6. 문서 ID가 대상 Player ID이며 저장된 `targetPlayerId`와 같아야 한다.
  GroupJoinRelation toJoinRelation(GroupDocumentDto document) {
    final data = document.data;
    _requireSchema(data);
    final targetPlayerId = _string(data, 'targetPlayerId');
    if (targetPlayerId != document.id) {
      throw const GroupContractException(
        'targetPlayerId must match the document id.',
      );
    }
    return GroupJoinRelation(
      groupId: _string(data, 'groupId'),
      targetPlayerId: targetPlayerId,
      kind: _enumValue(
        GroupJoinRelationKind.values,
        _string(data, 'kind'),
        'kind',
      ),
      status: _enumValue(
        GroupRequestStatus.values,
        _string(data, 'status'),
        'status',
      ),
      requestedByPlayerId: _string(data, 'requestedByPlayerId'),
      characterIdSnapshot: _string(data, 'characterIdSnapshot'),
      characterNameSnapshot: _string(data, 'characterNameSnapshot'),
      serverNameSnapshot: _string(data, 'serverNameSnapshot'),
      characterClassNameSnapshot: _string(data, 'characterClassNameSnapshot'),
      itemLevelSnapshot: _nullableDouble(data, 'itemLevelSnapshot'),
      combatPowerSnapshot: _nullableDouble(data, 'combatPowerSnapshot'),
      applicationAttempt: _integer(data, 'applicationAttempt'),
      revision: _integer(data, 'revision'),
      createdAt: _date(data, 'createdAt'),
      expiresAt: _date(data, 'expiresAt'),
      decidedAt: data['decidedAt'] == null ? null : _date(data, 'decidedAt'),
      updatedAt: _date(data, 'updatedAt'),
    );
  }

  /// 계약 §6.1. 문서가 없으면 신청 횟수 0인 빈 상태로 취급한다.
  GroupApplicantStats toApplicantStats({
    required String groupId,
    required String playerId,
    required Map<String, Object?>? data,
  }) {
    if (data == null || data.isEmpty) {
      return GroupApplicantStats.empty(groupId: groupId, playerId: playerId);
    }
    _requireSchema(data);
    return GroupApplicantStats(
      groupId: _string(data, 'groupId'),
      playerId: _string(data, 'playerId'),
      applicationCount: _integer(data, 'applicationCount'),
      lastCharacterNameSnapshot: data['lastCharacterNameSnapshot'] as String?,
      lastItemLevelSnapshot: _nullableDouble(data, 'lastItemLevelSnapshot'),
      lastCombatPowerSnapshot: _nullableDouble(data, 'lastCombatPowerSnapshot'),
    );
  }

  /// 계약 §6.2. 문서 ID가 금지된 Player ID이며 저장된 `playerId`와 같아야 한다.
  GroupBlockedPlayer toBlockedPlayer(GroupDocumentDto document) {
    final data = document.data;
    _requireSchema(data);
    final playerId = _string(data, 'playerId');
    if (playerId != document.id) {
      throw const GroupContractException(
        'playerId must match the document id.',
      );
    }
    return GroupBlockedPlayer(
      groupId: _string(data, 'groupId'),
      playerId: playerId,
      blockedByPlayerId: _string(data, 'blockedByPlayerId'),
      reason: _enumValue(
        GroupBlockReason.values,
        _string(data, 'reason'),
        'reason',
      ),
      characterNameSnapshot: _string(data, 'characterNameSnapshot'),
      applicationCountSnapshot: _integer(data, 'applicationCountSnapshot'),
      itemLevelSnapshot: _nullableDouble(data, 'itemLevelSnapshot'),
      combatPowerSnapshot: _nullableDouble(data, 'combatPowerSnapshot'),
      createdAt: _date(data, 'createdAt'),
    );
  }

  GroupMembershipState toMembershipState({
    required String playerId,
    required Map<String, Object?>? data,
  }) {
    if (data == null || data.isEmpty) {
      return GroupMembershipState.empty(playerId);
    }
    _requireSchema(data);
    final groupIds = data['activeGroupIds'];
    if (groupIds is! List) {
      throw const GroupContractException('activeGroupIds must be a list.');
    }
    final ids = groupIds.whereType<String>().toList(growable: false);
    if (ids.length != groupIds.length) {
      throw const GroupContractException('activeGroupIds must hold strings.');
    }
    return GroupMembershipState(
      playerId: playerId,
      activeGroupIds: ids,
      revision: _integer(data, 'revision'),
    );
  }

  GroupStatus _status(Map<String, Object?> data) =>
      _enumValue(GroupStatus.values, _string(data, 'status'), 'status');

  T _enumValue<T extends Enum>(List<T> values, String raw, String field) {
    final match = values.where((value) => value.name == raw).firstOrNull;
    if (match == null) {
      throw GroupContractException('$field has unknown value "$raw".');
    }
    return match;
  }

  void _requireSchema(Map<String, Object?> data) {
    if (data['schemaVersion'] != 1) {
      throw const GroupContractException('schemaVersion must be 1.');
    }
  }

  String _string(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value is! String || value.isEmpty) {
      throw GroupContractException('$field must be a non-empty string.');
    }
    return value;
  }

  String? _optionalString(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw GroupContractException(
        '$field must be a non-empty string or null.',
      );
    }
    return value;
  }

  int _integer(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw GroupContractException('$field must be a number.');
  }

  bool _boolean(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value is bool) return value;
    throw GroupContractException('$field must be a boolean.');
  }

  double? _nullableDouble(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw GroupContractException('$field must be a number or null.');
  }

  DateTime _date(Map<String, Object?> data, String field) {
    try {
      return toDateTime(data[field]);
    } on FormatException {
      throw GroupContractException('$field must be a timestamp.');
    }
  }
}
