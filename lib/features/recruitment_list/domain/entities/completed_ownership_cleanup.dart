import '../../../account/domain/game_account_ownership_snapshot.dart';

/// A single completed-party member removal; state/history are never targets.
class CompletedOwnershipCleanup {
  CompletedOwnershipCleanup({
    required this.roomId,
    required this.actorId,
    required this.targetId,
    required this.characterId,
    required this.revision,
    required this.targetIndex,
    required this.actorIndex,
    required this.observedRevision,
    required this.memberUpdatedAt,
    required this.eventId,
  });
  final String roomId, actorId, targetId, characterId, eventId;
  final int revision, targetIndex, actorIndex, observedRevision;
  final Object? memberUpdatedAt;

  static bool isStale(
    GameAccountOwnershipSnapshot authority,
    Object? generation,
  ) =>
      authority.condition != GameAccountOwnershipCondition.unknown &&
      generation is int &&
      generation >= 0 &&
      authority.revision != null &&
      authority.revision! > generation;

  Map<String, Object?> event(Map<String, dynamic> room, Object timestamp) => {
    'schemaVersion': 1,
    'eventId': eventId,
    'commandId': eventId,
    'recruitmentId': roomId,
    'type': 'ownershipParticipantRemoved',
    'commandRevision': revision + 1,
    'expectedRevision': revision,
    'actorPlayerId': actorId,
    'targetPlayerId': targetId,
    'targetCharacterId': characterId,
    'observedOwnershipRevision': observedRevision,
    'audiencePlayerIds': List<String>.from(room['memberPlayerIds'] as List),
    'occurredAt': timestamp,
  };

  bool matchesReceipt(Map<String, dynamic>? data) =>
      data != null &&
      data['eventId'] == eventId &&
      data['commandId'] == eventId &&
      data['type'] == 'ownershipParticipantRemoved' &&
      data['recruitmentId'] == roomId &&
      data['actorPlayerId'] == actorId &&
      data['targetPlayerId'] == targetId &&
      data['targetCharacterId'] == characterId &&
      data['expectedRevision'] == revision &&
      data['commandRevision'] == revision + 1 &&
      data['observedOwnershipRevision'] == observedRevision;

  Map<String, Object?> patch(Map<String, dynamic> room, Object timestamp) {
    final slots = List<Map<String, dynamic>>.from(room['partySlots'] as List);
    if (room['revision'] != revision ||
        room['recruitmentId'] != roomId ||
        room['schemaVersion'] != 2 ||
        room['status'] != 'active' ||
        room['currentCycleStatus'] != 'completed' ||
        room['continueTogether'] != true ||
        slots.length < 2 ||
        slots.length > 8 ||
        room['memberCount'] != slots.length ||
        targetIndex < 0 ||
        targetIndex >= slots.length ||
        actorIndex < 0 ||
        actorIndex >= slots.length) {
      throw StateError('정리 대상 상태가 바뀌었습니다.');
    }
    final target = slots[targetIndex];
    if (target['playerId'] != targetId ||
        target['characterId'] != characterId ||
        targetId == room['leaderPlayerId'] ||
        slots[actorIndex]['playerId'] != actorId ||
        (actorId != targetId && actorId != room['leaderPlayerId'])) {
      throw StateError('일반 참가자 정리 권한이 없습니다.');
    }
    final remaining = [...slots]..removeAt(targetIndex);
    final raidId = room['raidId'] as String;
    return {
      'partySlots': remaining,
      'memberPlayerIds': (room['memberPlayerIds'] as List)
          .where((id) => id != targetId)
          .toList(),
      'raidStateTargets': (room['raidStateTargets'] as List)
          .where(
            (value) =>
                !(value['playerId'] == targetId &&
                    value['stateId'] == '${characterId}_$raidId'),
          )
          .toList(),
      'memberCount': slots.length - 1,
      'dealerCount':
          (room['dealerCount'] as int) - (target['role'] == 'dealer' ? 1 : 0),
      'supportCount':
          (room['supportCount'] as int) - (target['role'] == 'support' ? 1 : 0),
      'nonGroupMemberCount':
          (room['nonGroupMemberCount'] as int) -
          (target['countedAsNonGroupMember'] == true ? 1 : 0),
      'hasAvailableSlot': true,
      'revision': revision + 1,
      'updatedAt': timestamp,
      'commandTargets': <Object>[],
      'lastCommandId': eventId,
      'lastCommandType': 'cleanupCompletedOwnership',
      'lastCommandActorPlayerId': actorId,
      'lastCommandAt': timestamp,
      'ownershipCleanup': {
        'expectedRevision': revision,
        'targetIndex': targetIndex,
        'actorIndex': actorIndex,
        'observedOwnershipRevision': observedRevision,
      },
    };
  }

  Map<String, Object?> listingPatch(Map<String, Object?> patch) => {
    for (final key in const [
      'partySlots',
      'memberPlayerIds',
      'raidStateTargets',
      'memberCount',
      'dealerCount',
      'supportCount',
      'nonGroupMemberCount',
      'hasAvailableSlot',
    ])
      key: patch[key],
    'sourceRevision': patch['revision'],
    'updatedAt': patch['updatedAt'],
  };
}

abstract interface class CompletedOwnershipCleanupRepository {
  Future<CompletedOwnershipCleanup> inspect(String roomId, String targetId);
  Future<void> execute(CompletedOwnershipCleanup observation);
}
