import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_recruitment.dart';

class PartyAtomicDocumentMapper {
  const PartyAtomicDocumentMapper._();

  static PartyCommandAggregate aggregate(Map<String, Object?> data) {
    final slots = _list(data['partySlots']).map(_slot).toList(growable: false);
    return PartyCommandAggregate(
      recruitmentId: _string(data, 'recruitmentId'),
      leaderPlayerId: _string(data, 'leaderPlayerId'),
      currentCycleKey: _string(data, 'currentCycleKey'),
      currentCycleStatus: _raidStatus(data['currentCycleStatus']),
      revision: _int(data, 'revision'),
      partySlots: slots,
      nonGroupMemberCount: _int(data, 'nonGroupMemberCount'),
      pendingApplicationCount: _int(data, 'pendingApplicationCount'),
      pendingNonGroupApplicantCount: _int(
        data,
        'pendingNonGroupApplicantCount',
      ),
      lastCommandId: data['lastCommandId'] as String?,
      lastCommandType: _commandTypeOrNull(data['lastCommandType']),
    );
  }

  static Map<String, Object?> slot(PartyAggregateSlot value) => {
    'playerId': value.playerId,
    'characterId': value.characterId,
    'role': value.role.name,
    'classKey': value.classKey,
    'partyIndex': value.partyIndex,
    'slotIndex': value.slotIndex,
  };

  static PartyAggregateSlot _slot(Map<String, Object?> data) =>
      PartyAggregateSlot(
        playerId: _string(data, 'playerId'),
        characterId: _string(data, 'characterId'),
        role: switch (_string(data, 'role')) {
          'dealer' => PartyRole.dealer,
          'support' => PartyRole.support,
          _ => throw const FormatException('지원하지 않는 파티 역할입니다.'),
        },
        classKey: _string(data, 'classKey'),
        partyIndex: _int(data, 'partyIndex'),
        slotIndex: _int(data, 'slotIndex'),
      );

  static PartyRaidStateStatus _raidStatus(Object? value) => switch (value) {
    'active' => PartyRaidStateStatus.active,
    'completed' => PartyRaidStateStatus.completed,
    _ => throw const FormatException('지원하지 않는 회차 상태입니다.'),
  };

  static PartyAtomicCommandType? _commandTypeOrNull(Object? value) {
    if (value == null) return null;
    for (final type in PartyAtomicCommandType.values) {
      if (type.name == value) return type;
    }
    throw const FormatException('지원하지 않는 마지막 명령 종류입니다.');
  }

  static String _string(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('$key 값이 올바르지 않습니다.');
  }

  static int _int(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is int) return value;
    throw FormatException('$key 값이 올바르지 않습니다.');
  }

  static List<Map<String, Object?>> _list(Object? value) {
    if (value is! List) throw const FormatException('partySlots가 없습니다.');
    return value
        .map((item) {
          if (item is! Map) {
            throw const FormatException('partySlots 항목이 올바르지 않습니다.');
          }
          return Map<String, Object?>.from(item);
        })
        .toList(growable: false);
  }
}
