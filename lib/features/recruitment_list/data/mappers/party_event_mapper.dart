import '../../domain/entities/party_event.dart';

/// Firestore Player Event 문서를 Domain [PartyEvent]로 변환한다.
class PartyEventMapper {
  const PartyEventMapper({required DateTime Function(Object? value) toDateTime})
    : _toDateTime = toDateTime;

  final DateTime Function(Object? value) _toDateTime;

  /// 필수 공통 필드가 없거나 형식이 다르면 null.
  /// 알 수 없는 [type]은 [PartyEvent.knownType]만 null로 두고 반환한다.
  PartyEvent? map(Map<String, Object?> data, {String? documentId}) {
    final eventId = data['eventId'];
    final type = data['type'];
    final playerId = data['playerId'];
    final recruitmentId = data['recruitmentId'];
    final eventRevision = data['eventRevision'];
    final occurredAt = data['occurredAt'];
    final expiresAt = data['expiresAt'];
    if (eventId is! String ||
        eventId.isEmpty ||
        type is! String ||
        type.isEmpty ||
        playerId is! String ||
        playerId.isEmpty ||
        recruitmentId is! String ||
        recruitmentId.isEmpty ||
        eventRevision is! int ||
        occurredAt == null ||
        expiresAt == null) {
      return null;
    }
    if (documentId != null && documentId != eventId) {
      return null;
    }
    try {
      return PartyEvent(
        eventId: eventId,
        type: type,
        knownType: PartyEventType.tryParse(type),
        playerId: playerId,
        recruitmentId: recruitmentId,
        eventRevision: eventRevision,
        occurredAt: _toDateTime(occurredAt),
        expiresAt: _toDateTime(expiresAt),
        cycleKey: _string(data['cycleKey']),
        raidId: _string(data['raidId']),
        difficultyId: _string(data['difficultyId']),
        actorPlayerId: _string(data['actorPlayerId']),
        targetPlayerId: _string(data['targetPlayerId']),
        characterId: _string(data['characterId']),
        characterNameSnapshot: _string(data['characterNameSnapshot']),
        classNameSnapshot: _string(data['classNameSnapshot']),
        role: _string(data['role']),
        partyIndex: _int(data['partyIndex']),
        slotIndex: _int(data['slotIndex']),
        actorCharacterNameSnapshot: _string(data['actorCharacterNameSnapshot']),
        targetCharacterNameSnapshot: _string(
          data['targetCharacterNameSnapshot'],
        ),
        previousCharacterNameSnapshot: _string(
          data['previousCharacterNameSnapshot'],
        ),
      );
    } on FormatException {
      return null;
    }
  }

  static String? _string(Object? value) => value is String ? value : null;

  static int? _int(Object? value) => value is int ? value : null;
}
