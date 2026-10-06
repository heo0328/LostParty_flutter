import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/party_composition_policy.dart';
import 'party_atomic_document_mapper.dart';
import 'party_atomic_lifecycle_marker_patch.dart';

class PartyAtomicCharacterChangeWritePlan {
  PartyAtomicCharacterChangeWritePlan({
    required PartyCommandAggregate aggregate,
    required RecruitmentPartyRules rules,
    required String playerId,
    required String newCharacterId,
    required String newClassKey,
    required PartyRole newRole,
    required String raidId,
    required String difficultyId,
    required Map<String, Object?> membershipPatch,
    required Object serverTimestamp,
    int? ownershipRevision,
  }) : _values = _build(
         aggregate: aggregate,
         rules: rules,
         playerId: playerId,
         newCharacterId: newCharacterId,
         newClassKey: newClassKey,
         newRole: newRole,
         raidId: raidId,
         difficultyId: difficultyId,
         membershipPatch: membershipPatch,
         ownershipRevision: ownershipRevision,
         serverTimestamp: serverTimestamp,
       );

  final _CharacterChangeValues _values;

  Map<String, Object?> get recruitmentPatch => _values.recruitmentPatch;
  Map<String, Object?> get membershipPatch => _values.membershipPatch;
  String get previousRaidStateId => _values.previousRaidStateId;
  String get nextRaidStateId => _values.nextRaidStateId;
  Map<String, Object?> get nextRaidState => _values.nextRaidState;
  Map<String, Object?> get event => _values.event;

  static _CharacterChangeValues _build({
    required PartyCommandAggregate aggregate,
    required RecruitmentPartyRules rules,
    required String playerId,
    required String newCharacterId,
    required String newClassKey,
    required PartyRole newRole,
    required String raidId,
    required String difficultyId,
    required Map<String, Object?> membershipPatch,
    required Object serverTimestamp,
    required int? ownershipRevision,
  }) {
    if (aggregate.status != PartyRecruitmentStatus.active ||
        aggregate.currentCycleStatus != PartyRaidStateStatus.active) {
      throw StateError('활성 회차에서만 캐릭터를 변경할 수 있습니다.');
    }
    final oldIndex = aggregate.partySlots.indexWhere(
      (slot) => slot.playerId == playerId,
    );
    if (oldIndex < 0) throw StateError('참가 Player를 찾을 수 없습니다.');
    final old = aggregate.partySlots[oldIndex];
    if (old.ownershipRevision != null && ownershipRevision == null) {
      throw StateError('새 캐릭터의 소유권 차수가 필요합니다.');
    }
    final placement = PartyCompositionPolicy(rules).planReplacement(
      replaceMemberId: playerId,
      className: newClassKey,
      role: newRole,
      existing: [
        for (final slot in aggregate.partySlots)
          OccupiedPartyMember(
            id: slot.playerId,
            className: slot.classKey,
            role: slot.role,
            partyIndex: slot.partyIndex,
            slotIndex: slot.slotIndex,
            isLeader: slot.playerId == aggregate.leaderPlayerId,
          ),
      ],
    );
    if (!placement.canChange) {
      throw StateError('파티 구성 정책 위반: ${placement.failure}');
    }
    final partyIndex = placement.destination?.partyIndex ?? old.partyIndex;
    final slotIndex = placement.destination?.slotIndex ?? old.slotIndex;
    final replacement = PartyAggregateSlot(
      playerId: playerId,
      characterId: newCharacterId,
      role: newRole,
      classKey: newClassKey,
      partyIndex: partyIndex,
      slotIndex: slotIndex,
      countedAsNonGroupMember: old.countedAsNonGroupMember,
      ownershipRevision: ownershipRevision,
    );
    final nextSlots = [...aggregate.partySlots]..[oldIndex] = replacement;
    // A proven single swap is left for the leader; never move another member
    // as a side effect of changing this character.
    if (!placement.needsRebalance) {
      _validateComposition(nextSlots, aggregate.leaderPlayerId, rules);
    }
    final nextRevision = aggregate.revision + 1;
    final previousRaidStateId = PartyRaidState.documentIdFor(
      characterId: old.characterId,
      raidId: raidId,
    );
    final nextRaidStateId = PartyRaidState.documentIdFor(
      characterId: newCharacterId,
      raidId: raidId,
    );
    if (previousRaidStateId == nextRaidStateId) {
      throw StateError('현재 캐릭터와 같은 캐릭터로 변경할 수 없습니다.');
    }
    final eventId = 'characterChanged_${aggregate.recruitmentId}_$nextRevision';
    return _CharacterChangeValues(
      recruitmentPatch: Map.unmodifiable({
        ...lifecycleMarkerConsumptionPatch(aggregate),
        'partySlots': [
          for (final slot in nextSlots) PartyAtomicDocumentMapper.slot(slot),
        ],
        'raidStateTargets': [
          for (final slot in nextSlots)
            {
              'playerId': slot.playerId,
              'stateId': PartyRaidState.documentIdFor(
                characterId: slot.characterId,
                raidId: raidId,
              ),
            },
        ],
        'dealerCount': nextSlots
            .where((slot) => slot.role == PartyRole.dealer)
            .length,
        'supportCount': nextSlots
            .where((slot) => slot.role == PartyRole.support)
            .length,
        if (playerId == aggregate.leaderPlayerId) ...{
          'leaderCharacterNameSnapshot':
              membershipPatch['characterNameSnapshot'],
          'leaderClassNameSnapshot': membershipPatch['classNameSnapshot'],
        },
        'revision': nextRevision,
        'updatedAt': serverTimestamp,
      }),
      membershipPatch: Map.unmodifiable({
        ...membershipPatch,
        'ownershipRevision': ?ownershipRevision,
        'partyIndex': partyIndex,
        'slotIndex': slotIndex,
      }),
      previousRaidStateId: previousRaidStateId,
      nextRaidStateId: nextRaidStateId,
      nextRaidState: Map.unmodifiable({
        'schemaVersion': 1,
        'playerId': playerId,
        'characterId': newCharacterId,
        'role': newRole.name,
        'ownershipRevision': ?ownershipRevision,
        'raidId': raidId,
        'difficultyId': difficultyId,
        'cycleKey': aggregate.currentCycleKey,
        'status': 'active',
        'source': 'party',
        'recruitmentId': aggregate.recruitmentId,
        'revision': 1,
        'updatedAt': serverTimestamp,
      }),
      event: _event(
        eventId: eventId,
        type: 'characterChanged',
        aggregate: aggregate,
        revision: nextRevision,
        actorPlayerId: playerId,
        serverTimestamp: serverTimestamp,
      ),
    );
  }
}

class PartyAtomicRepositionWritePlan {
  PartyAtomicRepositionWritePlan({
    required PartyCommandAggregate aggregate,
    required RecruitmentPartyRules rules,
    required String sourcePlayerId,
    required int destinationPartyIndex,
    required int destinationSlotIndex,
    required String actorPlayerId,
    required Object serverTimestamp,
  }) : _values = _build(
         aggregate: aggregate,
         rules: rules,
         sourcePlayerId: sourcePlayerId,
         destinationPartyIndex: destinationPartyIndex,
         destinationSlotIndex: destinationSlotIndex,
         actorPlayerId: actorPlayerId,
         serverTimestamp: serverTimestamp,
       );

  final _RepositionValues _values;

  Map<String, Object?> get recruitmentPatch => _values.recruitmentPatch;
  Map<String, Map<String, Object?>> get membershipPatches =>
      _values.membershipPatches;
  Map<String, Object?> get event => _values.event;
  int get maximumWriteCount => 1 + membershipPatches.length + 1 + 1;

  static _RepositionValues _build({
    required PartyCommandAggregate aggregate,
    required RecruitmentPartyRules rules,
    required String sourcePlayerId,
    required int destinationPartyIndex,
    required int destinationSlotIndex,
    required String actorPlayerId,
    required Object serverTimestamp,
  }) {
    if (aggregate.status != PartyRecruitmentStatus.active ||
        aggregate.currentCycleStatus != PartyRaidStateStatus.active ||
        sourcePlayerId == aggregate.leaderPlayerId) {
      throw StateError('현재 상태에서는 자리를 변경할 수 없습니다.');
    }
    final sourceIndex = aggregate.partySlots.indexWhere(
      (slot) => slot.playerId == sourcePlayerId,
    );
    if (sourceIndex < 0) throw StateError('이동할 Player가 없습니다.');
    final destinationIndex = aggregate.partySlots.indexWhere(
      (slot) =>
          slot.partyIndex == destinationPartyIndex &&
          slot.slotIndex == destinationSlotIndex,
    );
    if (destinationIndex >= 0 &&
        aggregate.partySlots[destinationIndex].playerId ==
            aggregate.leaderPlayerId) {
      throw StateError('파티장 자리와 교환할 수 없습니다.');
    }
    final source = aggregate.partySlots[sourceIndex];
    if (source.partyIndex == destinationPartyIndex &&
        source.slotIndex == destinationSlotIndex) {
      throw StateError('현재 자리와 같은 자리로 이동할 수 없습니다.');
    }
    final destination = destinationIndex < 0
        ? null
        : aggregate.partySlots[destinationIndex];
    final moved = PartyAggregateSlot(
      playerId: source.playerId,
      characterId: source.characterId,
      role: source.role,
      classKey: source.classKey,
      partyIndex: destinationPartyIndex,
      slotIndex: destinationSlotIndex,
      countedAsNonGroupMember: source.countedAsNonGroupMember,
      ownershipRevision: source.ownershipRevision,
    );
    final nextSlots = [...aggregate.partySlots]..[sourceIndex] = moved;
    if (destination != null) {
      nextSlots[destinationIndex] = PartyAggregateSlot(
        playerId: destination.playerId,
        characterId: destination.characterId,
        role: destination.role,
        classKey: destination.classKey,
        partyIndex: source.partyIndex,
        slotIndex: source.slotIndex,
        countedAsNonGroupMember: destination.countedAsNonGroupMember,
        ownershipRevision: destination.ownershipRevision,
      );
    }
    _validateComposition(nextSlots, aggregate.leaderPlayerId, rules);
    final revision = aggregate.revision + 1;
    final eventId = 'membersRepositioned_${aggregate.recruitmentId}_$revision';
    return _RepositionValues(
      recruitmentPatch: Map.unmodifiable({
        ...lifecycleMarkerConsumptionPatch(aggregate),
        'partySlots': [
          for (final slot in nextSlots) PartyAtomicDocumentMapper.slot(slot),
        ],
        'revision': revision,
        'updatedAt': serverTimestamp,
      }),
      membershipPatches: Map.unmodifiable({
        source.playerId: {
          'partyIndex': moved.partyIndex,
          'slotIndex': moved.slotIndex,
          'updatedAt': serverTimestamp,
        },
        if (destination != null)
          destination.playerId: {
            'partyIndex': source.partyIndex,
            'slotIndex': source.slotIndex,
            'updatedAt': serverTimestamp,
          },
      }),
      event: _event(
        eventId: eventId,
        type: 'membersRepositioned',
        aggregate: aggregate,
        revision: revision,
        actorPlayerId: actorPlayerId,
        serverTimestamp: serverTimestamp,
      ),
    );
  }
}

void _validateComposition(
  List<PartyAggregateSlot> slots,
  String leaderPlayerId,
  RecruitmentPartyRules rules,
) {
  if (slots.length > rules.totalMembers ||
      slots.any(
        (slot) =>
            slot.partyIndex >= rules.partyCount ||
            slot.slotIndex >= rules.membersPerParty,
      ) ||
      slots.map((slot) => slot.positionKey).toSet().length != slots.length) {
    throw StateError('파티 슬롯 위치가 올바르지 않습니다.');
  }
  final failure = PartyCompositionPolicy(rules).failureForArrangement([
    for (final slot in slots)
      OccupiedPartyMember(
        id: slot.playerId,
        className: slot.classKey,
        role: slot.role,
        partyIndex: slot.partyIndex,
        slotIndex: slot.slotIndex,
        isLeader: slot.playerId == leaderPlayerId,
      ),
  ]);
  if (failure != null) throw StateError('파티 구성 정책 위반: $failure');
}

Map<String, Object?> _event({
  required String eventId,
  required String type,
  required PartyCommandAggregate aggregate,
  required int revision,
  required String actorPlayerId,
  required Object serverTimestamp,
}) => Map.unmodifiable({
  'schemaVersion': 1,
  'eventId': eventId,
  'recruitmentId': aggregate.recruitmentId,
  'type': type,
  'commandId': eventId,
  'commandRevision': revision,
  'audiencePlayerIds': [for (final slot in aggregate.partySlots) slot.playerId],
  'actorPlayerId': actorPlayerId,
  'occurredAt': serverTimestamp,
});

class _CharacterChangeValues {
  const _CharacterChangeValues({
    required this.recruitmentPatch,
    required this.membershipPatch,
    required this.previousRaidStateId,
    required this.nextRaidStateId,
    required this.nextRaidState,
    required this.event,
  });
  final Map<String, Object?> recruitmentPatch;
  final Map<String, Object?> membershipPatch;
  final String previousRaidStateId;
  final String nextRaidStateId;
  final Map<String, Object?> nextRaidState;
  final Map<String, Object?> event;
}

class _RepositionValues {
  const _RepositionValues({
    required this.recruitmentPatch,
    required this.membershipPatches,
    required this.event,
  });
  final Map<String, Object?> recruitmentPatch;
  final Map<String, Map<String, Object?>> membershipPatches;
  final Map<String, Object?> event;
}
