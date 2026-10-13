import '../../domain/entities/party_atomic_command.dart';

enum PartyRaidStateWriteAction { update, upsert, delete }

class PartyRaidStateWrite {
  const PartyRaidStateWrite({
    required this.target,
    required this.action,
    this.patch,
    this.removeCompletedAt = false,
  });

  final PartyCommandTarget target;
  final PartyRaidStateWriteAction action;
  final Map<String, Object?>? patch;
  final bool removeCompletedAt;
}

class PartyAtomicWritePlan {
  PartyAtomicWritePlan({
    required this.command,
    required this.aggregate,
    required this.serverTimestamp,
    required this.incrementOne,
  }) {
    if (aggregate.recruitmentId != command.recruitmentId ||
        aggregate.revision != command.expectedRevision ||
        aggregate.currentCycleKey != command.expectedCycleKey) {
      throw StateError('명령 기준과 모집 Aggregate가 일치하지 않습니다.');
    }
    final completedDisband =
        command.type == PartyAtomicCommandType.disband &&
        aggregate.currentCycleStatus == PartyRaidStateStatus.completed;
    final targetlessIncompleteEnd =
        command.type == PartyAtomicCommandType.incompleteEnd;
    if (((completedDisband || targetlessIncompleteEnd) &&
            command.targets.isNotEmpty) ||
        (!completedDisband &&
            !targetlessIncompleteEnd &&
            !_targetsMatchSlots())) {
      throw StateError('명령 대상이 현재 파티 구성과 일치하지 않습니다.');
    }
    if ((command.type == PartyAtomicCommandType.complete &&
            aggregate.currentCycleStatus != PartyRaidStateStatus.active) ||
        (command.type == PartyAtomicCommandType.advanceCycle &&
            !aggregate.continueTogether) ||
        (command.type == PartyAtomicCommandType.incompleteEnd &&
            (aggregate.continueTogether ||
                aggregate.currentCycleStatus != PartyRaidStateStatus.active))) {
      throw StateError('현재 회차 상태에서 실행할 수 없는 명령입니다.');
    }
    if (aggregate.status != PartyRecruitmentStatus.active &&
        !(command.type == PartyAtomicCommandType.disband &&
            aggregate.status == PartyRecruitmentStatus.completed)) {
      throw StateError('종료된 모집에는 실행할 수 없는 명령입니다.');
    }
  }

  final PartyCommandEnvelope command;
  final PartyCommandAggregate aggregate;
  final Object serverTimestamp;
  final Object incrementOne;

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

  bool get closesActiveGroupRecruitment =>
      aggregate.groupId != null &&
      aggregate.visibility == 'group' &&
      ((command.type == PartyAtomicCommandType.complete &&
              !aggregate.continueTogether) ||
          command.type == PartyAtomicCommandType.incompleteEnd ||
          (command.type == PartyAtomicCommandType.disband &&
              aggregate.status == PartyRecruitmentStatus.active));

  int get maximumWriteCount =>
      1 + command.targets.length + 1 + (closesActiveGroupRecruitment ? 1 : 0);

  bool raidStateDocumentsAllow(Map<String, Map<String, Object?>> documents) {
    if (documents.length != command.targets.length) return false;
    for (final target in command.targets) {
      final data = documents[target.pathKey];
      if (data == null ||
          data['recruitmentId'] != command.recruitmentId ||
          data['cycleKey'] != command.expectedCycleKey ||
          data['revision'] is! int) {
        return false;
      }
      final status = data['status'];
      final allowed = switch (command.type) {
        PartyAtomicCommandType.complete => status == 'active',
        PartyAtomicCommandType.advanceCycle =>
          status == 'active' || status == 'completed',
        PartyAtomicCommandType.incompleteEnd => false,
        PartyAtomicCommandType.disband => status == 'active',
        PartyAtomicCommandType.personalComplete => false,
      };
      if (!allowed) return false;
    }
    return true;
  }

  Map<String, Object?> get recruitmentPatch {
    final nextRevision = command.expectedRevision + 1;
    return {
      if (command.type == PartyAtomicCommandType.complete)
        'currentCycleStatus': 'completed',
      if (command.type == PartyAtomicCommandType.complete)
        'status': aggregate.continueTogether ? 'active' : 'completed',
      if (command.type == PartyAtomicCommandType.advanceCycle)
        'currentCycleStatus': 'active',
      if (command.type == PartyAtomicCommandType.advanceCycle)
        'status': 'active',
      if (command.type == PartyAtomicCommandType.advanceCycle)
        'currentCycleKey': command.nextCycleKey,
      if (command.type == PartyAtomicCommandType.advanceCycle)
        'targetCycleKey': command.nextCycleKey,
      if (command.type == PartyAtomicCommandType.advanceCycle)
        'cycleStartedAt': command.nextCycleStartedAt,
      if (command.type == PartyAtomicCommandType.advanceCycle)
        'cycleEndsAt': command.nextCycleEndsAt,
      if (command.type == PartyAtomicCommandType.advanceCycle) ...{
        'completedAt': null,
        'completedByPlayerId': null,
      },
      if (command.type == PartyAtomicCommandType.disband) ...{
        'status': 'disbanded',
        'manualRecruitmentEnabled': false,
        'hasAvailableSlot': false,
      },
      if (command.type == PartyAtomicCommandType.incompleteEnd) ...{
        'status': 'incompleteEnded',
        'currentCycleStatus': 'incompleteEnded',
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
      else if (command.type == PartyAtomicCommandType.advanceCycle)
        PartyRaidStateWrite(
          target: target,
          action: PartyRaidStateWriteAction.upsert,
          patch: _advanceRaidState(target),
          removeCompletedAt: true,
        )
      else
        PartyRaidStateWrite(
          target: target,
          action: PartyRaidStateWriteAction.update,
          patch: {
            'status': command.type == PartyAtomicCommandType.complete
                ? 'completed'
                : 'active',
            if (command.type == PartyAtomicCommandType.complete)
              'completedAt': serverTimestamp,
            if (command.type == PartyAtomicCommandType.complete)
              'role': aggregate.partySlots
                  .firstWhere((slot) => slot.playerId == target.playerId)
                  .role
                  .name,
            'revision': incrementOne,
            'updatedAt': serverTimestamp,
          },
        ),
  ];

  Map<String, Object?> _advanceRaidState(PartyCommandTarget target) {
    final slot = aggregate.partySlots.firstWhere(
      (candidate) => candidate.playerId == target.playerId,
    );
    return {
      'schemaVersion': 1,
      'playerId': slot.playerId,
      'characterId': slot.characterId,
      if (slot.ownershipRevision != null)
        'ownershipRevision': slot.ownershipRevision,
      'raidId': aggregate.raidId,
      'difficultyId': aggregate.difficultyId,
      'recruitmentId': aggregate.recruitmentId,
      'cycleKey': command.nextCycleKey,
      'role': slot.role.name,
      'status': 'active',
      'source': 'party',
      'revision': incrementOne,
      'updatedAt': serverTimestamp,
    };
  }

  Map<String, Object?> get eventDocument => {
    'schemaVersion':
        command.type == PartyAtomicCommandType.complete ||
            command.type == PartyAtomicCommandType.incompleteEnd
        ? 2
        : 1,
    'eventId': command.commandId,
    'recruitmentId': command.recruitmentId,
    'type': command.type == PartyAtomicCommandType.incompleteEnd
        ? 'partyIncompleteEnded'
        : command.type.name,
    'commandId': command.commandId,
    'commandRevision': command.expectedRevision + 1,
    'audiencePlayerIds': [
      for (final slot in aggregate.partySlots) slot.playerId,
    ],
    'actorPlayerId': command.actorPlayerId,
    if (command.type == PartyAtomicCommandType.complete ||
        command.type == PartyAtomicCommandType.incompleteEnd) ...{
      'raidId': aggregate.raidId,
      'difficultyId': aggregate.difficultyId,
      'cycleKey': aggregate.currentCycleKey,
      'completionTargets': [
        for (final slot in aggregate.partySlots)
          {'playerId': slot.playerId, 'characterId': slot.characterId},
      ],
    },
    'occurredAt': serverTimestamp,
  };
}
