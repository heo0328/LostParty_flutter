import '../../domain/entities/party_event.dart';

/// Firestore Player Event·공용 partyEvents 문서를 Domain [PartyEvent]로 변환한다.
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

  /// 공용 `partyEvents` 문서를 수신자 기준으로 변환한다.
  PartyEvent? mapShared(
    Map<String, Object?> data, {
    required String recipientPlayerId,
    String? documentId,
  }) {
    final eventId = data['eventId'];
    final type = data['type'];
    final recruitmentId = data['recruitmentId'];
    final commandRevision = data['commandRevision'];
    final occurredAt = data['occurredAt'];
    final audience = data['audiencePlayerIds'];
    if (eventId is! String ||
        eventId.isEmpty ||
        type is! String ||
        type.isEmpty ||
        recruitmentId is! String ||
        recruitmentId.isEmpty ||
        commandRevision is! int ||
        occurredAt == null ||
        audience is! List ||
        !audience.contains(recipientPlayerId)) {
      return null;
    }
    if (documentId != null && documentId != eventId) {
      return null;
    }
    final occurred = _toDateTime(occurredAt);
    final expiresAt = data['expiresAt'] == null
        ? occurred.add(const Duration(days: 30))
        : _toDateTime(data['expiresAt']);
    final wireType = _sharedWireType(type);
    try {
      return PartyEvent(
        eventId: eventId,
        type: wireType,
        knownType: PartyEventType.tryParse(wireType),
        playerId: recipientPlayerId,
        recruitmentId: recruitmentId,
        eventRevision: commandRevision,
        occurredAt: occurred,
        expiresAt: expiresAt,
        cycleKey: _string(data['cycleKey']),
        raidId: _string(data['raidId']),
        difficultyId: _string(data['difficultyId']),
        actorPlayerId: _string(data['actorPlayerId']),
        targetPlayerId: _string(data['targetPlayerId']),
        characterId: sharedHistoryCharacterId(
          data,
          recipientPlayerId: recipientPlayerId,
        ),
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

  /// 공용 완료 이벤트에서 현재 수신자의 Character를 선택한다.
  ///
  /// schemaVersion 2는 수신자별 [completionTargets]를 사용하고, 과거
  /// 공용 이벤트의 상단 [characterId]는 읽기 호환으로만 유지한다.
  static String? sharedHistoryCharacterId(
    Map<String, Object?> data, {
    required String recipientPlayerId,
  }) {
    final targets = data['completionTargets'];
    if (targets is List) {
      String? characterId;
      for (final raw in targets) {
        if (raw is! Map) return null;
        final target = Map<String, Object?>.from(raw);
        final playerId = target['playerId'];
        final candidateCharacterId = target['characterId'];
        if (playerId is! String ||
            playerId.isEmpty ||
            candidateCharacterId is! String ||
            candidateCharacterId.isEmpty) {
          return null;
        }
        if (playerId == recipientPlayerId) {
          if (characterId != null) return null;
          characterId = candidateCharacterId;
        }
      }
      return characterId;
    }
    return _string(data['characterId']);
  }

  static String _sharedWireType(String type) => switch (type) {
    'complete' => PartyEventType.partyCompleted.wireName,
    'cancelCompletion' => PartyEventType.partyCompletionCancelled.wireName,
    'disband' => PartyEventType.partyDisbanded.wireName,
    'characterChanged' => PartyEventType.memberCharacterChanged.wireName,
    'membersRepositioned' => PartyEventType.memberMoved.wireName,
    _ => type,
  };

  static String? _string(Object? value) => value is String ? value : null;

  static int? _int(Object? value) => value is int ? value : null;
}
