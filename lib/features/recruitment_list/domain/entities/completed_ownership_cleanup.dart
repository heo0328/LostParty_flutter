import '../../../account/domain/game_account_ownership_snapshot.dart';

enum CompletedCleanupKind { participant, peer, leader, disband }

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
    this.kind = CompletedCleanupKind.participant,
    this.leaderIndex,
    this.observedLeaderRevision,
    this.successorIndex,
    this.successorId,
    this.successorName,
    this.successorClass,
    this.successorUpdatedAt,
    this.targetName,
  });
  final String roomId, actorId, targetId, characterId, eventId;
  final int revision, targetIndex, actorIndex, observedRevision;
  final Object? memberUpdatedAt;
  final CompletedCleanupKind kind;
  final int? leaderIndex, observedLeaderRevision, successorIndex;
  final String? successorId, successorName, successorClass;
  final Object? successorUpdatedAt;
  final String? targetName;
  String get commandType => switch (kind) {
    CompletedCleanupKind.participant => 'cleanupCompletedOwnership',
    CompletedCleanupKind.peer => 'cleanupCompletedPeerOwnership',
    CompletedCleanupKind.leader => 'cleanupCompletedLeaderOwnership',
    CompletedCleanupKind.disband => 'disband',
  };
  String get eventType => switch (kind) {
    CompletedCleanupKind.participant => 'ownershipParticipantRemoved',
    CompletedCleanupKind.peer => 'ownershipPeerRemoved',
    CompletedCleanupKind.leader => 'ownershipLeaderRemoved',
    CompletedCleanupKind.disband => 'disband',
  };

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
    'type': eventType,
    'commandRevision': revision + 1,
    if (kind != CompletedCleanupKind.disband) 'expectedRevision': revision,
    'actorPlayerId': actorId,
    if (kind != CompletedCleanupKind.disband) ...{
      'targetPlayerId': targetId,
      'targetCharacterId': characterId,
      'observedOwnershipRevision': observedRevision,
    },
    'audiencePlayerIds': List<String>.from(room['memberPlayerIds'] as List),
    'occurredAt': timestamp,
    if (kind == CompletedCleanupKind.peer) ...{
      'leaderPlayerId': room['leaderPlayerId'],
      'observedLeaderRevision': observedLeaderRevision,
    },
    if (kind == CompletedCleanupKind.leader) ...{
      'successorPlayerId': successorId,
      'priorGenerations': List<int>.filled(
        (room['partySlots'] as List).length,
        0,
      ),
    },
  };

  bool matchesReceipt(Map<String, dynamic>? data) =>
      data != null &&
      data['eventId'] == eventId &&
      data['commandId'] == eventId &&
      data['type'] == eventType &&
      data['recruitmentId'] == roomId &&
      data['actorPlayerId'] == actorId &&
      data['commandRevision'] == revision + 1 &&
      (kind == CompletedCleanupKind.disband ||
          (data['targetPlayerId'] == targetId &&
              data['targetCharacterId'] == characterId &&
              data['expectedRevision'] == revision &&
              data['observedOwnershipRevision'] == observedRevision)) &&
      (kind != CompletedCleanupKind.peer ||
          data['observedLeaderRevision'] == observedLeaderRevision) &&
      (kind != CompletedCleanupKind.leader ||
          data['successorPlayerId'] == successorId);

  Map<String, Object?> patch(Map<String, dynamic> room, Object timestamp) {
    final slots = List<Map<String, dynamic>>.from(room['partySlots'] as List);
    if (room['revision'] != revision ||
        room['recruitmentId'] != roomId ||
        room['schemaVersion'] != 2 ||
        room['status'] != 'active' ||
        room['currentCycleStatus'] != 'completed' ||
        room['continueTogether'] != true ||
        slots.length < (kind == CompletedCleanupKind.disband ? 1 : 2) ||
        slots.length > 8 ||
        room['memberCount'] != slots.length ||
        targetIndex < 0 ||
        targetIndex >= slots.length ||
        actorIndex < 0 ||
        actorIndex >= slots.length) {
      throw StateError('정리 대상 상태가 바뀌었습니다.');
    }
    final target = slots[targetIndex];
    if (kind == CompletedCleanupKind.disband) {
      if (slots.length != 1 ||
          actorId != targetId ||
          room['leaderPlayerId'] != actorId ||
          target['playerId'] != targetId ||
          target['characterId'] != characterId) {
        throw StateError('마지막 기존 공대장만 해산할 수 있습니다.');
      }
      return {
        'status': 'disbanded',
        'manualRecruitmentEnabled': false,
        'hasAvailableSlot': false,
        'commandTargets': <Object>[],
        'revision': revision + 1,
        'lastCommandId': eventId,
        'lastCommandType': commandType,
        'lastCommandActorPlayerId': actorId,
        'lastCommandAt': timestamp,
        'updatedAt': timestamp,
      };
    }
    if (target['playerId'] != targetId ||
        target['characterId'] != characterId ||
        slots[actorIndex]['playerId'] != actorId ||
        (kind == CompletedCleanupKind.participant &&
            (targetId == room['leaderPlayerId'] ||
                (actorId != targetId && actorId != room['leaderPlayerId'])))) {
      throw StateError('일반 참가자 정리 권한이 없습니다.');
    }
    if (kind == CompletedCleanupKind.peer &&
        (targetId == room['leaderPlayerId'] ||
            leaderIndex == null ||
            leaderIndex! < 0 ||
            leaderIndex! >= slots.length ||
            slots[leaderIndex!]['playerId'] != room['leaderPlayerId'] ||
            observedLeaderRevision == null)) {
      throw StateError('공대장 소유권 확인이 필요합니다.');
    }
    if (kind == CompletedCleanupKind.leader &&
        (targetId != room['leaderPlayerId'] ||
            successorIndex != (targetIndex == 0 ? 1 : 0) ||
            slots[successorIndex!]['playerId'] != successorId ||
            successorName == null ||
            successorClass == null)) {
      throw StateError('첫 잔여 참가자만 후임이 될 수 있습니다.');
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
      'lastCommandType': commandType,
      'lastCommandActorPlayerId': actorId,
      'lastCommandAt': timestamp,
      'ownershipCleanup': {
        'expectedRevision': revision,
        'targetIndex': targetIndex,
        'actorIndex': actorIndex,
        'observedOwnershipRevision': observedRevision,
        if (kind == CompletedCleanupKind.peer) ...{
          'leaderIndex': leaderIndex,
          'observedLeaderRevision': observedLeaderRevision,
        },
        if (kind == CompletedCleanupKind.leader) ...{
          'successorIndex': successorIndex,
          'priorGenerations': List<int>.filled(slots.length, 0),
        },
      },
      if (kind == CompletedCleanupKind.leader) ...{
        'leaderPlayerId': successorId,
        'leaderCharacterNameSnapshot': successorName,
        'leaderClassNameSnapshot': successorClass,
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
    if (kind == CompletedCleanupKind.leader)
      for (final key in const [
        'leaderPlayerId',
        'leaderCharacterNameSnapshot',
        'leaderClassNameSnapshot',
      ])
        key: patch[key],
  };
}

abstract interface class CompletedOwnershipCleanupRepository {
  Future<CompletedOwnershipCleanup> inspect(String roomId, String targetId);
  Future<void> execute(CompletedOwnershipCleanup observation);
  Future<List<CompletedOwnershipCleanup>> pending(String actorId);
  Future<void> retry(CompletedOwnershipCleanup observation);
  Future<void> forget(CompletedOwnershipCleanup observation);
}
