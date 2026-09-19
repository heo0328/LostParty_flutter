import '../../domain/entities/party_atomic_command.dart';

enum PartyRaidStateWriteAction { update, delete }

enum PartyGroupListingWriteAction { none, update, delete }

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
    if ((completedDisband && command.targets.isNotEmpty) ||
        (!completedDisband && !_targetsMatchSlots())) {
      throw StateError('명령 대상이 현재 파티 구성과 일치하지 않습니다.');
    }
    if ((command.type == PartyAtomicCommandType.complete &&
            aggregate.currentCycleStatus != PartyRaidStateStatus.active) ||
        (command.type == PartyAtomicCommandType.cancelCompletion &&
            (aggregate.currentCycleStatus != PartyRaidStateStatus.completed ||
                !aggregate.continueTogether)) ||
        (command.type == PartyAtomicCommandType.advanceCycle &&
            !aggregate.continueTogether)) {
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
      ((command.type == PartyAtomicCommandType.complete &&
              !aggregate.continueTogether) ||
          (command.type == PartyAtomicCommandType.disband &&
              aggregate.status == PartyRecruitmentStatus.active));

  PartyGroupListingWriteAction get groupListingAction {
    if (aggregate.groupId == null ||
        (command.type == PartyAtomicCommandType.disband &&
            aggregate.status == PartyRecruitmentStatus.completed)) {
      return PartyGroupListingWriteAction.none;
    }
    return closesActiveGroupRecruitment
        ? PartyGroupListingWriteAction.delete
        : PartyGroupListingWriteAction.update;
  }

  int get maximumWriteCount =>
      1 +
      command.targets.length +
      1 +
      (groupListingAction == PartyGroupListingWriteAction.none ? 0 : 1) +
      (closesActiveGroupRecruitment ? 1 : 0);

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
        PartyAtomicCommandType.cancelCompletion => status == 'completed',
        PartyAtomicCommandType.advanceCycle =>
          status == 'active' || status == 'completed',
        PartyAtomicCommandType.disband => status == 'active',
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
      if (command.type == PartyAtomicCommandType.cancelCompletion ||
          command.type == PartyAtomicCommandType.advanceCycle)
        'currentCycleStatus': 'active',
      if (command.type == PartyAtomicCommandType.cancelCompletion ||
          command.type == PartyAtomicCommandType.advanceCycle)
        'status': 'active',
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
            'revision': incrementOne,
            'updatedAt': serverTimestamp,
          },
        ),
  ];

  Map<String, Object?> get eventDocument => {
    'schemaVersion':
        command.type == PartyAtomicCommandType.complete ||
            command.type == PartyAtomicCommandType.cancelCompletion
        ? 2
        : 1,
    'eventId': command.commandId,
    'recruitmentId': command.recruitmentId,
    'type': command.type.name,
    'commandId': command.commandId,
    'commandRevision': command.expectedRevision + 1,
    'audiencePlayerIds': [
      for (final slot in aggregate.partySlots) slot.playerId,
    ],
    'actorPlayerId': command.actorPlayerId,
    if (command.type == PartyAtomicCommandType.complete ||
        command.type == PartyAtomicCommandType.cancelCompletion) ...{
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

  Map<String, Object?> get listingPatch => {
    'recruitmentId': command.recruitmentId,
    'sourceRevision': command.expectedRevision + 1,
    'status': recruitmentPatch['status'] ?? aggregate.status.name,
    'updatedAt': serverTimestamp,
  };
}
