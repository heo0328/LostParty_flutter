import '../../domain/entities/party_atomic_command.dart';

enum PartyRaidStateWriteAction { update, delete }

class PartyRaidStateWrite {
  const PartyRaidStateWrite({
    required this.target,
    required this.action,
    this.patch,
  });

  final PartyCommandTarget target;
  final PartyRaidStateWriteAction action;
  final Map<String, Object?>? patch;
}

class PartyAtomicWritePlan {
  PartyAtomicWritePlan({
    required this.command,
    required this.aggregate,
    required this.serverTimestamp,
  }) {
    if (aggregate.recruitmentId != command.recruitmentId ||
        aggregate.revision != command.expectedRevision ||
        aggregate.currentCycleKey != command.expectedCycleKey) {
      throw StateError('명령 기준과 모집 Aggregate가 일치하지 않습니다.');
    }
    final completedDisband =
        command.type == PartyAtomicCommandType.disband &&
        aggregate.currentCycleStatus == PartyRaidStateStatus.completed;
    if ((completedDisband && command.targets.isNotEmpty) ||
        (!completedDisband && !_targetsMatchSlots())) {
      throw StateError('명령 대상이 현재 파티 구성과 일치하지 않습니다.');
    }
    if ((command.type == PartyAtomicCommandType.complete &&
            aggregate.currentCycleStatus != PartyRaidStateStatus.active) ||
        (command.type == PartyAtomicCommandType.cancelCompletion &&
            aggregate.currentCycleStatus != PartyRaidStateStatus.completed)) {
      throw StateError('현재 회차 상태에서 실행할 수 없는 명령입니다.');
    }
  }

  final PartyCommandEnvelope command;
  final PartyCommandAggregate aggregate;
  final Object serverTimestamp;

  bool _targetsMatchSlots() {
    if (command.targets.length != aggregate.partySlots.length) return false;
    final targetByPlayer = {
      for (final target in command.targets) target.playerId: target,
    };
    if (targetByPlayer.length != command.targets.length) return false;
    for (final slot in aggregate.partySlots) {
      final target = targetByPlayer[slot.playerId];
      if (target == null ||
          !target.raidStateId.startsWith('${slot.characterId}_')) {
        return false;
      }
    }
    return true;
  }

  int get maximumWriteCount => 1 + command.targets.length + 1 + 1;

  Map<String, Object?> get recruitmentPatch {
    final nextRevision = command.expectedRevision + 1;
    return {
      if (command.type == PartyAtomicCommandType.complete)
        'currentCycleStatus': 'completed',
      if (command.type == PartyAtomicCommandType.cancelCompletion ||
          command.type == PartyAtomicCommandType.advanceCycle)
        'currentCycleStatus': 'active',
      if (command.type == PartyAtomicCommandType.advanceCycle)
        'currentCycleKey': command.nextCycleKey,
      if (command.type == PartyAtomicCommandType.disband) ...{
        'status': 'disbanded',
        'manualRecruitmentEnabled': false,
        'hasAvailableSlot': false,
      },
      'commandTargets': [
        for (final target in command.targets)
          {'playerId': target.playerId, 'stateId': target.raidStateId},
      ],
      'revision': nextRevision,
      'lastCommandId': command.commandId,
      'lastCommandType': command.type.name,
      'lastCommandActorPlayerId': command.actorPlayerId,
      'lastCommandAt': serverTimestamp,
      'updatedAt': serverTimestamp,
    };
  }

  List<PartyRaidStateWrite> get raidStateWrites => [
    for (final target in command.targets)
      if (command.type == PartyAtomicCommandType.disband)
        PartyRaidStateWrite(
          target: target,
          action: PartyRaidStateWriteAction.delete,
        )
      else
        PartyRaidStateWrite(
          target: target,
          action: PartyRaidStateWriteAction.update,
          patch: {
            'status': command.type == PartyAtomicCommandType.complete
                ? 'completed'
                : 'active',
            if (command.type == PartyAtomicCommandType.advanceCycle)
              'cycleKey': command.nextCycleKey,
            'revision': command.expectedRevision + 1,
            'updatedAt': serverTimestamp,
          },
        ),
  ];

  Map<String, Object?> get eventDocument => {
    'schemaVersion': 1,
    'eventId': command.commandId,
    'recruitmentId': command.recruitmentId,
    'type': command.type.name,
    'commandId': command.commandId,
    'commandRevision': command.expectedRevision + 1,
    'audiencePlayerIds': [
      for (final slot in aggregate.partySlots) slot.playerId,
    ],
    'actorPlayerId': command.actorPlayerId,
    'occurredAt': serverTimestamp,
  };

  Map<String, Object?> get listingPatch => {
    'sourceRevision': command.expectedRevision + 1,
    'status': command.type == PartyAtomicCommandType.disband
        ? 'disbanded'
        : 'active',
    'updatedAt': serverTimestamp,
  };
}
