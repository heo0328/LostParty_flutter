import 'party_recruitment.dart';

enum PartyRaidStateStatus { active, completed }

enum PartyRaidStateSource { party, manual }

class PartyRaidState {
  PartyRaidState({
    required this.playerId,
    required this.characterId,
    required this.raidId,
    required this.difficultyId,
    required this.cycleKey,
    required this.status,
    required this.source,
    required this.revision,
    required this.updatedAt,
    this.recruitmentId,
  }) {
    if (playerId.isEmpty || characterId.isEmpty || raidId.isEmpty) {
      throw ArgumentError('raidState 식별자는 비어 있을 수 없습니다.');
    }
    if (cycleKey.isEmpty || difficultyId.isEmpty || revision < 0) {
      throw ArgumentError('raidState 상태 값이 올바르지 않습니다.');
    }
    if (source == PartyRaidStateSource.party &&
        (recruitmentId == null || recruitmentId!.isEmpty)) {
      throw ArgumentError('파티 raidState에는 모집 ID가 필요합니다.');
    }
  }

  static String documentIdFor({
    required String characterId,
    required String raidId,
  }) => '${characterId}_$raidId';

  final String playerId;
  final String characterId;
  final String raidId;
  final String difficultyId;
  final String cycleKey;
  final PartyRaidStateStatus status;
  final PartyRaidStateSource source;
  final String? recruitmentId;
  final int revision;
  final DateTime updatedAt;

  String get documentId =>
      documentIdFor(characterId: characterId, raidId: raidId);
}

class PartyAggregateSlot {
  PartyAggregateSlot({
    required this.playerId,
    required this.characterId,
    required this.role,
    required this.classKey,
    required this.partyIndex,
    required this.slotIndex,
  }) {
    if (playerId.isEmpty || characterId.isEmpty || classKey.isEmpty) {
      throw ArgumentError('파티 슬롯 식별자는 비어 있을 수 없습니다.');
    }
    if (partyIndex < 0 || slotIndex < 0) {
      throw ArgumentError('파티 슬롯 위치는 음수일 수 없습니다.');
    }
  }

  final String playerId;
  final String characterId;
  final PartyRole role;
  final String classKey;
  final int partyIndex;
  final int slotIndex;

  String get positionKey => '${partyIndex}_$slotIndex';
}

enum PartyAtomicCommandType {
  complete,
  cancelCompletion,
  advanceCycle,
  disband,
}

class PartyCommandTarget {
  PartyCommandTarget({required this.playerId, required this.raidStateId}) {
    if (playerId.isEmpty || raidStateId.isEmpty) {
      throw ArgumentError('명령 대상 경로는 비어 있을 수 없습니다.');
    }
  }

  final String playerId;
  final String raidStateId;

  String get pathKey => '$playerId/$raidStateId';
}

class PartyCommandEnvelope {
  PartyCommandEnvelope({
    required this.commandId,
    required this.recruitmentId,
    required this.type,
    required this.actorPlayerId,
    required this.expectedRevision,
    required this.expectedCycleKey,
    required List<PartyCommandTarget> targets,
    this.nextCycleKey,
  }) : targets = List.unmodifiable(targets) {
    if (commandId.isEmpty ||
        recruitmentId.isEmpty ||
        actorPlayerId.isEmpty ||
        expectedCycleKey.isEmpty ||
        expectedRevision < 0) {
      throw ArgumentError('명령 식별자와 revision이 올바르지 않습니다.');
    }
    if (targets.length > 8 ||
        (targets.isEmpty && type != PartyAtomicCommandType.disband)) {
      throw ArgumentError('명령 대상은 최대 8개이며 해산 외에는 필수입니다.');
    }
    if (targets.map((target) => target.pathKey).toSet().length !=
        targets.length) {
      throw ArgumentError('명령 대상은 중복될 수 없습니다.');
    }
    final isAdvance = type == PartyAtomicCommandType.advanceCycle;
    if (isAdvance != (nextCycleKey != null && nextCycleKey!.isNotEmpty) ||
        (isAdvance && nextCycleKey == expectedCycleKey)) {
      throw ArgumentError('다음 회차 키는 주차 전환 명령에만 필요합니다.');
    }
  }

  final String commandId;
  final String recruitmentId;
  final PartyAtomicCommandType type;
  final String actorPlayerId;
  final int expectedRevision;
  final String expectedCycleKey;
  final String? nextCycleKey;
  final List<PartyCommandTarget> targets;
}

class PartyCommandAggregate {
  PartyCommandAggregate({
    required this.recruitmentId,
    required this.leaderPlayerId,
    required this.currentCycleKey,
    required this.currentCycleStatus,
    required this.revision,
    required List<PartyAggregateSlot> partySlots,
    required this.nonGroupMemberCount,
    required this.pendingApplicationCount,
    required this.pendingNonGroupApplicantCount,
    this.lastCommandId,
    this.lastCommandType,
  }) : partySlots = List.unmodifiable(partySlots) {
    if (recruitmentId.isEmpty ||
        leaderPlayerId.isEmpty ||
        currentCycleKey.isEmpty ||
        revision < 0) {
      throw ArgumentError('모집 Aggregate 식별자가 올바르지 않습니다.');
    }
    if (partySlots.length > 8) {
      throw ArgumentError('파티 Aggregate는 최대 8칸입니다.');
    }
    if (partySlots.map((slot) => slot.playerId).toSet().length !=
            partySlots.length ||
        partySlots.map((slot) => slot.positionKey).toSet().length !=
            partySlots.length) {
      throw ArgumentError('Player 또는 파티 위치가 중복되었습니다.');
    }
    if (nonGroupMemberCount < 0 ||
        pendingApplicationCount < 0 ||
        pendingNonGroupApplicantCount < 0 ||
        nonGroupMemberCount > partySlots.length ||
        pendingNonGroupApplicantCount > pendingApplicationCount) {
      throw ArgumentError('모집 Aggregate 집계가 올바르지 않습니다.');
    }
    if ((lastCommandId == null) != (lastCommandType == null)) {
      throw ArgumentError('마지막 명령 ID와 종류는 함께 존재해야 합니다.');
    }
    if (lastCommandId != null && lastCommandId!.isEmpty) {
      throw ArgumentError('마지막 명령 ID는 비어 있을 수 없습니다.');
    }
  }

  final String recruitmentId;
  final String leaderPlayerId;
  final String currentCycleKey;
  final PartyRaidStateStatus currentCycleStatus;
  final int revision;
  final List<PartyAggregateSlot> partySlots;
  final int nonGroupMemberCount;
  final int pendingApplicationCount;
  final int pendingNonGroupApplicantCount;
  final String? lastCommandId;
  final PartyAtomicCommandType? lastCommandType;

  int get memberCount => partySlots.length;
  int get dealerCount =>
      partySlots.where((slot) => slot.role == PartyRole.dealer).length;
  int get supporterCount => memberCount - dealerCount;
  bool get canBecomeGroupOnly =>
      nonGroupMemberCount == 0 && pendingNonGroupApplicantCount == 0;

  PartyCommandRecovery classify(String commandId, int expectedRevision) {
    if (lastCommandId == commandId && revision == expectedRevision + 1) {
      return PartyCommandRecovery.applied;
    }
    if (revision == expectedRevision) return PartyCommandRecovery.notApplied;
    return PartyCommandRecovery.conflict;
  }
}

enum PartyCommandRecovery { applied, notApplied, conflict }
