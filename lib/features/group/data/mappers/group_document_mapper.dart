import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

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
      gemValidationSnapshot: _softGemValidation(data['gemValidationSnapshot']),
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
      groupNameSnapshot: _displayText(data['groupNameSnapshot']) ?? '이름 없는 그룹',
      displayCharacterNameSnapshot:
          _displayText(data['displayCharacterNameSnapshot']) ?? '알 수 없는 캐릭터',
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
      gemValidationSnapshot: _softGemValidation(data['gemValidationSnapshot']),
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
      lastCharacterNameSnapshot: _displayText(
        data['lastCharacterNameSnapshot'],
      ),
      lastItemLevelSnapshot: _displayNumber(data['lastItemLevelSnapshot']),
      lastCombatPowerSnapshot: _displayNumber(data['lastCombatPowerSnapshot']),
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
      characterNameSnapshot:
          _displayText(data['characterNameSnapshot']) ?? '알 수 없는 캐릭터',
      applicationCountSnapshot: _integer(data, 'applicationCountSnapshot'),
      itemLevelSnapshot: _displayNumber(data['itemLevelSnapshot']),
      combatPowerSnapshot: _displayNumber(data['combatPowerSnapshot']),
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
    final groupIds = data['activeGroupIds'];
    final revision = data['revision'];
    // wipe·수동 편집으로 깨진 요약은 빈 상태로 보고 생성 Transaction이
    // revision 1부터 다시 쓰게 한다. Rules update도 list/int 기본값을 허용한다.
    if (groupIds is! List || (revision is! int && revision is! num)) {
      return GroupMembershipState.empty(playerId);
    }
    final ids = groupIds.whereType<String>().toList(growable: false);
    if (ids.length != groupIds.length) {
      return GroupMembershipState.empty(playerId);
    }
    final revisionValue = revision is int
        ? revision
        : (revision as num).toInt();
    return GroupMembershipState(
      playerId: playerId,
      activeGroupIds: ids,
      revision: revisionValue,
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

  // Informational copies are not authority or eligibility inputs. Clean them
  // locally without relaxing the strict ID/status/counter readers above.
  String? _displayText(Object? value) {
    if (value is! String) return null;
    final text = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
    if (text.isEmpty) return null;
    return String.fromCharCodes(text.runes.take(256));
  }

  double? _displayNumber(Object? value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    return value.toDouble();
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

  PartyGemValidationSnapshot? _softGemValidation(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    final data = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    return PartyGemValidationSnapshot.tryFromFields(
      data,
      parseDate: (value) {
        try {
          return toDateTime(value);
        } on FormatException {
          return null;
        } on GroupContractException {
          return null;
        }
      },
    );
  }

  DateTime _date(Map<String, Object?> data, String field) {
    try {
      return toDateTime(data[field]);
    } on FormatException {
      throw GroupContractException('$field must be a timestamp.');
    }
  }
}
