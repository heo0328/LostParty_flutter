import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_create_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/party_composition_policy.dart';
import 'party_atomic_document_mapper.dart';
import 'party_atomic_lifecycle_marker_patch.dart';
import 'party_create_write_plan.dart';
import 'party_join_write_plan.dart';

class PartyAtomicCreateWritePlan {
  PartyAtomicCreateWritePlan.fromBase({
    required PartyCreateWritePlan base,
    required PartyCreateCommand command,
    required String playerId,
    required String classKey,
    required Object serverTimestamp,
    int groupActiveRecruitmentCountAfter = 0,
    int? ownershipRevision,
  }) : recruitment = _recruitment(
         base: base,
         command: command,
         playerId: playerId,
         classKey: classKey,
         groupActiveRecruitmentCountAfter: groupActiveRecruitmentCountAfter,
         ownershipRevision: ownershipRevision,
       ),
       leaderMembership = Map.unmodifiable({
         ...base.leaderMembership,
         'ownershipRevision': ?ownershipRevision,
       }),
       raidState = _raidState(
         base: base,
         command: command,
         playerId: playerId,
         ownershipRevision: ownershipRevision,
       ),
       event = _event(
         command: command,
         playerId: playerId,
         serverTimestamp: serverTimestamp,
       );

  final Map<String, Object?> recruitment;
  final Map<String, Object?> leaderMembership;
  final Map<String, Object?> raidState;
  final Map<String, Object?> event;

  String get raidStateId => PartyRaidState.documentIdFor(
    characterId: raidState['characterId']! as String,
    raidId: raidState['raidId']! as String,
  );

  int get groupActiveRecruitmentDelta =>
      recruitment['visibility'] == RecruitmentVisibility.group ? 1 : 0;

  static Map<String, Object?> _recruitment({
    required PartyCreateWritePlan base,
    required PartyCreateCommand command,
    required String playerId,
    required String classKey,
    required int groupActiveRecruitmentCountAfter,
    required int? ownershipRevision,
  }) {
    final slot = PartyAggregateSlot(
      playerId: playerId,
      characterId: command.leaderCharacterId,
      role: command.leaderRole,
      classKey: classKey,
      partyIndex: 0,
      slotIndex: 0,
      countedAsNonGroupMember: false,
      ownershipRevision: ownershipRevision,
    );
    final raidStateId = PartyRaidState.documentIdFor(
      characterId: command.leaderCharacterId,
      raidId: command.metadata.raidId,
    );
    return Map.unmodifiable({
      ...base.recruitment,
      'schemaVersion': 2,
      'recruitmentId': command.recruitmentId,
      'partySlots': [PartyAtomicDocumentMapper.slot(slot)],
      'nonGroupMemberCount': 0,
      'pendingApplicationCount': 0,
      'pendingNonGroupApplicantCount': 0,
      'raidStateTargets': [
        {'playerId': playerId, 'stateId': raidStateId},
      ],
      'commandTargets': const <Map<String, Object?>>[],
      'groupActiveRecruitmentCountAfter': groupActiveRecruitmentCountAfter,
      'lastCommandId': null,
      'lastCommandType': null,
      'lastCommandActorPlayerId': null,
      'lastCommandAt': null,
    });
  }

  static Map<String, Object?> _raidState({
    required PartyCreateWritePlan base,
    required PartyCreateCommand command,
    required String playerId,
    required int? ownershipRevision,
  }) => Map.unmodifiable({
    ...base.assignment,
    'schemaVersion': 1,
    'playerId': playerId,
    'ownershipRevision': ?ownershipRevision,
    'characterId': command.leaderCharacterId,
    'raidId': command.metadata.raidId,
    'difficultyId': command.metadata.difficultyId,
    'cycleKey': command.cycleKey,
    'status': 'active',
    'source': 'party',
    'recruitmentId': command.recruitmentId,
    'revision': 1,
  });

  static Map<String, Object?> _event({
    required PartyCreateCommand command,
    required String playerId,
    required Object serverTimestamp,
  }) {
    final eventId = 'partyCreated_${command.recruitmentId}_1';
    return Map.unmodifiable({
      'schemaVersion': 1,
      'eventId': eventId,
      'recruitmentId': command.recruitmentId,
      'type': 'partyCreated',
      'commandId': eventId,
      'commandRevision': 1,
      'audiencePlayerIds': [playerId],
      'actorPlayerId': playerId,
      'occurredAt': serverTimestamp,
    });
  }
}

class PartyAtomicJoinWritePlan {
  PartyAtomicJoinWritePlan.fromBase({
    required PartyJoinWritePlan base,
    required PartyCommandAggregate aggregate,
    required RecruitmentPartyRules rules,
    required String classKey,
    required String raidId,
    required String difficultyId,
    required bool joiningIsGroupMember,
    required Object serverTimestamp,
    int? ownershipRevision,
  }) : _values = _build(
         base: base,
         aggregate: aggregate,
         rules: rules,
         classKey: classKey,
         raidId: raidId,
         difficultyId: difficultyId,
         joiningIsGroupMember: joiningIsGroupMember,
         serverTimestamp: serverTimestamp,
         ownershipRevision: ownershipRevision,
       );

  final _PartyAtomicJoinValues _values;

  Map<String, Object?> get recruitmentPatch => _values.recruitmentPatch;
  Map<String, Object?> get membership => _values.membership;
  Map<String, Object?> get raidState => _values.raidState;
  Map<String, Object?> get event => _values.event;
  String get playerId => _values.playerId;
  String get raidStateId => _values.raidStateId;

  static _PartyAtomicJoinValues _build({
    required PartyJoinWritePlan base,
    required PartyCommandAggregate aggregate,
    required RecruitmentPartyRules rules,
    required String classKey,
    required String raidId,
    required String difficultyId,
    required bool joiningIsGroupMember,
    required Object serverTimestamp,
    required int? ownershipRevision,
  }) {
    if (aggregate.status != PartyRecruitmentStatus.active ||
        aggregate.currentCycleStatus != PartyRaidStateStatus.active ||
        aggregate.memberCount >= rules.totalMembers) {
      throw StateError('현재 모집에는 참가할 수 없습니다.');
    }
    final playerId = base.membership['playerId'];
    final characterId = base.membership['characterId'];
    final roleName = base.membership['role'];
    final joinedBy = base.membership['joinedBy'];
    final partyIndex = base.membership['partyIndex'];
    final slotIndex = base.membership['slotIndex'];
    if (playerId is! String ||
        characterId is! String ||
        roleName is! String ||
        joinedBy is! String ||
        partyIndex is! int ||
        slotIndex is! int) {
      throw const FormatException('가입 membership 필드가 올바르지 않습니다.');
    }
    final role = switch (roleName) {
      'dealer' => PartyRole.dealer,
      'support' => PartyRole.support,
      _ => throw const FormatException('가입 역할이 올바르지 않습니다.'),
    };
    final joiningSlot = PartyAggregateSlot(
      playerId: playerId,
      characterId: characterId,
      role: role,
      classKey: classKey,
      partyIndex: partyIndex,
      slotIndex: slotIndex,
      countedAsNonGroupMember:
          aggregate.groupId != null && !joiningIsGroupMember,
      ownershipRevision: ownershipRevision,
    );
    final nextSlots = [...aggregate.partySlots, joiningSlot];
    final arrangement = [
      for (final slot in nextSlots)
        OccupiedPartyMember(
          id: slot.playerId,
          className: slot.classKey,
          role: slot.role,
          partyIndex: slot.partyIndex,
          slotIndex: slot.slotIndex,
          isLeader: slot.playerId == aggregate.leaderPlayerId,
        ),
    ];
    final failure = PartyCompositionPolicy(
      rules,
    ).failureForArrangement(arrangement);
    if (failure != null) {
      throw StateError('파티 구성 정책을 만족하지 않습니다: $failure');
    }
    final raidStateId = PartyRaidState.documentIdFor(
      characterId: characterId,
      raidId: raidId,
    );
    final nextRevision = aggregate.revision + 1;
    final eventId = 'memberJoined_${aggregate.recruitmentId}_$nextRevision';
    return _PartyAtomicJoinValues(
      playerId: playerId,
      raidStateId: raidStateId,
      recruitmentPatch: Map.unmodifiable({
        ...base.recruitmentUpdate,
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
        'nonGroupMemberCount':
            aggregate.nonGroupMemberCount +
            (joiningSlot.countedAsNonGroupMember ? 1 : 0),
        'revision': nextRevision,
      }),
      membership: Map.unmodifiable({
        ...base.membership,
        'ownershipRevision': ?ownershipRevision,
      }),
      raidState: Map.unmodifiable({
        ...base.assignment,
        'ownershipRevision': ?ownershipRevision,
        'schemaVersion': 1,
        'difficultyId': difficultyId,
        'status': 'active',
        'source': 'party',
        'revision': 1,
      }),
      event: Map.unmodifiable({
        'schemaVersion': 1,
        'eventId': eventId,
        'recruitmentId': aggregate.recruitmentId,
        'type': 'memberJoined',
        'commandId': eventId,
        'commandRevision': nextRevision,
        'audiencePlayerIds': [for (final slot in nextSlots) slot.playerId],
        'actorPlayerId': joinedBy,
        'occurredAt': serverTimestamp,
      }),
    );
  }
}

class _PartyAtomicJoinValues {
  const _PartyAtomicJoinValues({
    required this.playerId,
    required this.raidStateId,
    required this.recruitmentPatch,
    required this.membership,
    required this.raidState,
    required this.event,
  });

  final String playerId;
  final String raidStateId;
  final Map<String, Object?> recruitmentPatch;
  final Map<String, Object?> membership;
  final Map<String, Object?> raidState;
  final Map<String, Object?> event;
}
